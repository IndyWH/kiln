#!/usr/bin/env python3
"""Kiln Linux: proves PyTorch really works on the GPU, and gives first timings.

Run inside a uv environment that can see the system's PyTorch. It only uses memory.
"""
import time
import warnings

import torch


def timed(work, device):
    """Median of 5 runs, in milliseconds."""
    times = []
    for _ in range(5):
        if device == "cuda":
            torch.cuda.synchronize()
        begin = time.perf_counter()
        work()
        if device == "cuda":
            torch.cuda.synchronize()
        times.append((time.perf_counter() - begin) * 1000)
    return sorted(times)[2]


def matmul_ms(device, size):
    a = torch.rand(size, size, device=device)
    b = torch.rand(size, size, device=device)
    return timed(lambda: a @ b, device)


def train(device):
    """A small network must learn a simple pattern, which needs gradients to work."""
    torch.manual_seed(0)
    x = torch.rand(4096, 16, device=device)
    y = (x.sum(dim=1, keepdim=True) > 8).float()
    model = torch.nn.Sequential(torch.nn.Linear(16, 256), torch.nn.ReLU(),
                                torch.nn.Linear(256, 256), torch.nn.ReLU(),
                                torch.nn.Linear(256, 1)).to(device)
    optimiser = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = torch.nn.BCEWithLogitsLoss()
    first = last = None
    begin = time.perf_counter()
    for _ in range(500):
        optimiser.zero_grad()
        with torch.autocast(device, dtype=torch.float16 if device == "cuda" else torch.bfloat16):
            loss = loss_fn(model(x), y)
        loss.backward()
        optimiser.step()
        first = first if first is not None else loss.item()
        last = loss.item()
    seconds = time.perf_counter() - begin
    with torch.no_grad():
        accuracy = ((model(x) > 0).float() == y).float().mean().item()
    return first, last, accuracy, seconds


def main():
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        available = torch.cuda.is_available()
    for warning in caught:
        print("Warning at start:", str(warning.message)[:300])

    print("PyTorch", torch.__version__, "built for CUDA", torch.version.cuda)
    print("Python", __import__("sys").version.split()[0], "from", torch.__file__)
    print("CPU maths:", torch.backends.cpu.get_cpu_capability(), "threads", torch.get_num_threads())
    print("oneDNN:", torch.backends.mkldnn.is_available(), "OpenMP:", torch.backends.openmp.is_available())
    assert available, "CUDA is not available"
    print("GPU:", torch.cuda.get_device_name(0), "cuDNN", torch.backends.cudnn.version(),
          "memory", torch.cuda.get_device_properties(0).total_memory // 2**20, "MiB")

    gpu = matmul_ms("cuda", 8192)
    cpu = matmul_ms("cpu", 8192)
    print("Multiply two 8192 x 8192 matrices: GPU %.1f ms, CPU %.1f ms" % (gpu, cpu))

    x = torch.rand(1024, 1024, device="cuda", requires_grad=True)
    (x @ x).sum().backward()
    assert x.grad is not None and x.grad.device.type == "cuda"
    print("Gradients on the GPU: OK")

    images = torch.rand(8, 3, 224, 224, device="cuda")
    conv = torch.nn.Conv2d(3, 16, 3).to("cuda")
    torch.backends.cudnn.benchmark = True
    assert conv(images).shape[1] == 16
    print("Convolution through cuDNN: OK")

    for device in ("cuda", "cpu"):
        first, last, accuracy, seconds = train(device)
        print("Training on %s, 500 steps: loss %.3f to %.3f, accuracy %.1f%%, %.2f s"
              % (device, first, last, accuracy * 100, seconds))
        assert last < first and accuracy > 0.9, "The network did not learn"

    print("Peak GPU memory: %d MiB" % (torch.cuda.max_memory_allocated() // 2**20))
    print("All passed.")


if __name__ == "__main__":
    main()
