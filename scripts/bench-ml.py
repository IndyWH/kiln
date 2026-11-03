#!/usr/bin/env python3
"""Kiln Linux: a machine-learning benchmark on made-up data, about 8 minutes.

The same script can run on Ubuntu with ordinary PyTorch, for a fair comparison. It needs
no downloads and writes only to results/ml-bench/. Add --short for a 1 minute check.
Run it with the machine otherwise idle.
"""
import json
import os
import platform
import subprocess
import sys
import threading
import time

import torch
import torchvision

SHORT = "--short" in sys.argv
REPEATS = 1 if SHORT else 3
RESNET_STEPS = 5 if SHORT else 40
TRANSFORMER_STEPS = 3 if SHORT else 30
SUSTAINED_SECONDS = 15 if SHORT else 180
WARMUP_STEPS = 3 if SHORT else 10
ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))


def median(values):
    return sorted(values)[len(values) // 2]


def resnet_setup(batch):
    torch.manual_seed(0)
    model = torchvision.models.resnet50(weights=None).to("cuda").train()
    optimiser = torch.optim.SGD(model.parameters(), lr=0.01, momentum=0.9)
    scaler = torch.amp.GradScaler("cuda")
    images = torch.rand(batch, 3, 224, 224, device="cuda")
    labels = torch.randint(0, 1000, (batch,), device="cuda")

    def step():
        optimiser.zero_grad(set_to_none=True)
        with torch.autocast("cuda", dtype=torch.float16):
            loss = torch.nn.functional.cross_entropy(model(images), labels)
        scaler.scale(loss).backward()
        scaler.step(optimiser)
        scaler.update()
    return step


def timed_rate(step, steps, items_per_step):
    for _ in range(WARMUP_STEPS):
        step()
    torch.cuda.synchronize()
    begin = time.perf_counter()
    for _ in range(steps):
        step()
    torch.cuda.synchronize()
    return steps * items_per_step / (time.perf_counter() - begin)


def resnet_training():
    batch = 256
    return median([timed_rate(resnet_setup(batch), RESNET_STEPS, batch) for _ in range(REPEATS)])


def resnet_inference():
    batch = 512
    torch.manual_seed(0)
    model = torchvision.models.resnet50(weights=None).to("cuda").eval()
    images = torch.rand(batch, 3, 224, 224, device="cuda")

    def step():
        with torch.inference_mode(), torch.autocast("cuda", dtype=torch.float16):
            model(images)
    return median([timed_rate(step, RESNET_STEPS, batch) for _ in range(REPEATS)])


def transformer_training():
    """A language-style model, large enough to use a good part of the card's memory."""
    batch, length, vocabulary = 16, 512, 32000
    torch.manual_seed(0)
    layer = torch.nn.TransformerEncoderLayer(d_model=1024, nhead=16, dim_feedforward=4096,
                                             batch_first=True, norm_first=True)
    embed = torch.nn.Embedding(vocabulary, 1024).to("cuda")
    encoder = torch.nn.TransformerEncoder(layer, num_layers=12, enable_nested_tensor=False).to("cuda")
    head = torch.nn.Linear(1024, vocabulary).to("cuda")
    parts = list(embed.parameters()) + list(encoder.parameters()) + list(head.parameters())
    optimiser = torch.optim.AdamW(parts, lr=1e-4)
    scaler = torch.amp.GradScaler("cuda")
    tokens = torch.randint(0, vocabulary, (batch, length), device="cuda")
    mask = torch.nn.Transformer.generate_square_subsequent_mask(length, device="cuda")

    def step():
        optimiser.zero_grad(set_to_none=True)
        with torch.autocast("cuda", dtype=torch.float16):
            output = head(encoder(embed(tokens), mask=mask, is_causal=True))
            loss = torch.nn.functional.cross_entropy(output.reshape(-1, vocabulary), tokens.reshape(-1))
        scaler.scale(loss).backward()
        scaler.step(optimiser)
        scaler.update()
    rate = median([timed_rate(step, TRANSFORMER_STEPS, batch * length) for _ in range(REPEATS)])
    sizes = sum(p.numel() for p in parts)
    return rate, sizes


def cpu_inference():
    """On the CPU, where -march=native and oneDNN can make a difference. All threads."""
    torch.manual_seed(0)
    model = torchvision.models.resnet50(weights=None).eval()
    images = torch.rand(32, 3, 224, 224)
    runs = []
    for _ in range(REPEATS):
        begin = time.perf_counter()
        with torch.inference_mode():
            for _ in range(2 if SHORT else 10):
                model(images)
        runs.append((2 if SHORT else 10) * 32 / (time.perf_counter() - begin))
    return median(runs)


def jpeg_decode():
    """One thread, decoding the same made-up photo, the kind of work a data loader does."""
    torch.manual_seed(0)
    small = torch.rand(3, 128, 128)
    photo = (torch.nn.functional.interpolate(small[None], size=(1080, 1920), mode="bicubic")[0]
             .clamp(0, 1) * 255).to(torch.uint8)
    data = torchvision.io.encode_jpeg(photo, quality=90)
    previous = torch.get_num_threads()
    torch.set_num_threads(1)
    runs = []
    count = 20 if SHORT else 200
    for _ in range(REPEATS):
        begin = time.perf_counter()
        for _ in range(count):
            torchvision.io.decode_jpeg(data)
        runs.append(count / (time.perf_counter() - begin))
    torch.set_num_threads(previous)
    return median(runs)


class GpuWatch(threading.Thread):
    """Reads temperature, power, clock speed and throttling every 5 seconds."""
    FIELDS = "temperature.gpu,power.draw,clocks.gr,utilization.gpu,clocks_throttle_reasons.hw_thermal_slowdown,clocks_throttle_reasons.sw_thermal_slowdown,clocks_throttle_reasons.hw_power_brake_slowdown"

    def __init__(self):
        super().__init__(daemon=True)
        self.samples = []
        self.stop_now = threading.Event()

    def run(self):
        while not self.stop_now.wait(5):
            out = subprocess.run(["nvidia-smi", "--query-gpu=" + self.FIELDS,
                                  "--format=csv,noheader,nounits"],
                                 capture_output=True, text=True, check=False).stdout.strip()
            self.samples.append([part.strip() for part in out.split(",")])


def sustained():
    batch = 256
    step = resnet_setup(batch)
    watch = GpuWatch()
    watch.start()
    for _ in range(WARMUP_STEPS):
        step()
    torch.cuda.synchronize()
    slices, start = [], time.perf_counter()
    while time.perf_counter() - start < SUSTAINED_SECONDS:
        begin, count = time.perf_counter(), 0
        while time.perf_counter() - begin < SUSTAINED_SECONDS / 6:
            step()
            count += 1
        torch.cuda.synchronize()
        slices.append(count * batch / (time.perf_counter() - begin))
    watch.stop_now.set()
    watch.join(timeout=10)
    return slices, watch.samples


def main():
    print("PyTorch", torch.__version__, "CUDA", torch.version.cuda, flush=True)
    print("GPU", torch.cuda.get_device_name(0), "kernel", platform.release(), flush=True)
    torch.backends.cudnn.benchmark = True
    results = {"date": time.strftime("%Y-%m-%d %H:%M"), "kernel": platform.release(),
               "torch": torch.__version__, "cuda": torch.version.cuda,
               "torchvision": torchvision.__version__, "short": SHORT}

    print("ResNet-50 training", flush=True)
    results["resnet_train_images_s"] = round(resnet_training(), 1)
    print("ResNet-50 inference", flush=True)
    results["resnet_infer_images_s"] = round(resnet_inference(), 1)
    torch.cuda.empty_cache()
    torch.cuda.reset_peak_memory_stats()
    print("Transformer training", flush=True)
    rate, sizes = transformer_training()
    results["transformer_tokens_s"] = round(rate)
    results["transformer_parameters_millions"] = round(sizes / 1e6)
    results["transformer_peak_memory_mib"] = torch.cuda.max_memory_allocated() // 2**20
    torch.cuda.empty_cache()
    print("CPU inference", flush=True)
    results["cpu_infer_images_s"] = round(cpu_inference(), 1)
    print("JPEG decoding", flush=True)
    results["jpeg_decode_per_s"] = round(jpeg_decode(), 1)

    print("Sustained training, %d seconds" % SUSTAINED_SECONDS, flush=True)
    slices, samples = sustained()
    results["sustained_images_s"] = [round(s, 1) for s in slices]
    results["sustained_drop_percent"] = round((slices[0] - slices[-1]) / slices[0] * 100, 2)
    good = [s for s in samples if len(s) == 7]
    if good:
        results["peak_temperature_c"] = max(int(s[0]) for s in good)
        results["peak_power_w"] = max(float(s[1]) for s in good)
        results["clock_mhz_first_last"] = [int(good[0][2]), int(good[-1][2])]
        results["thermal_or_power_throttle_samples"] = sum(
            any(flag.lower() == "active" for flag in s[4:]) for s in good)
        results["gpu_samples"] = len(good)

    folder = os.path.join(ROOT, "results", "ml-bench")
    os.makedirs(folder, exist_ok=True)
    name = "%s-%s%s.json" % (platform.release(), time.strftime("%Y%m%d-%H%M"), "-short" if SHORT else "")
    with open(os.path.join(folder, name), "w") as f:
        json.dump(results, f, indent=2)
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
