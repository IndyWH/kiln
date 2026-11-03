# Hypotheses

What we expect before each big step, so results can prove us wrong. Write a prediction before the test, never after. Do not edit a prediction once the test has run. Add the result beside it, right or wrong.

| Date | Who | Prediction | Test | Result |
|---|---|---|---|---|
| 3 Nov 2026 | Claude Code | ThinLTO's pipes time falls between plain Clang's 2.04 s and Full LTO's 2.43 s | `scripts/bench-kernel.sh` on the ThinLTO kernel | |
| 3 Nov 2026 | Claude Code | A kernel rebuilt with a profile of this machine's use removes most of Full LTO's pipes slowdown | The overfired kernel, against Full LTO | |
| 3 Nov 2026 | Claude Code | BORE improves wake-up delay at 99.9%, and costs under 5% on pipes | The overfired kernel, with repeat runs | |
| 3 Nov 2026 | Claude Code | Rebuilding 7-Zip with its assembly option closes most of the 18% to 20% gap to Ubuntu | Rebuild 7-Zip, then the same test | |
| 3 Nov 2026 | Claude Code | In step 11, `sysbench` gains under 2%, and 7-Zip gains more than `sysbench` | `scripts/measure.sh`, before and after | |
| 3 Nov 2026 | Claude Code | A compiler rebuilt for this CPU with LTO and profiles compiles a kernel over 5% faster | `scripts/bench-kernel.sh`, kernel compile time | Right, measured with `scripts/bench-compilers.sh`: 76.1 s to 66.6 s, 12.5% faster, with Clang unchanged as the control, on 3 Nov 2026 |
| 3 Nov 2026 | Claude Code | Driver 615.78.08 lets a CUDA 13.4 program built with default settings run, where driver 595.104.02 fails with "unsupported toolchain" | `tests/nvidia/ptx_check.cu`, before and after | Right. Failed on 595.104.02 and passed on 615.78.08, on 3 Nov 2026 |
| 3 Nov 2026 | Claude Code | Clang rebuilt with Full LTO and `-O3` for this CPU, but no PGO, compiles a kernel 3% to 10% faster. GCC, with PGO as well, gains more than Clang | `scripts/bench-compilers.sh`, before and after | Right. Clang 89.5 s to 84.7 s, 5.4% faster, with GCC unchanged as the control. GCC gained 12.5%, on 3 Nov 2026 |
| 3 Nov 2026 | Claude Code | Rust rebuilt with Full LTO for this CPU compiles a test program 3% to 15% faster than the ready-built compiler | `scripts/bench-rust.sh`, before and after | Wrong, in the other direction. 17.20 s to 23.60 s, 37% slower, on 3 Nov 2026. Cause not proved |
| 3 Nov 2026 | Claude Code | ResNet-50 training on the RTX 4090 reaches between 1000 and 2000 images per second, at batch size 256 with mixed precision | `scripts/bench-ml.py` | Right. 1388 images per second, on 3 Nov 2026 |
| 3 Nov 2026 | Claude Code | Over 3 minutes of training, the speed drops under 3%, with no thermal throttling | `scripts/bench-ml.py`, sustained test | Right. No drop, no throttling in 36 samples, peak 67 °C, on 3 Nov 2026 |
| 3 Nov 2026 | Claude Code | Against ordinary PyTorch on Ubuntu, overfired PyTorch is within 3% on GPU training, and over 5% faster on CPU work: CPU inference and JPEG decoding | `scripts/bench-ml.py` on both systems | |
| 3 Nov 2026 | Owner | The maxed setup benefits things like video editing and ComfyUI | The same video export and the same ComfyUI workflow, timed on Kiln and on Ubuntu 26.10. Details to be set before testing | |
| 3 Nov 2026 | Claude Code | Video export gains more than ComfyUI. ComfyUI gains under 3%, as most of its work runs on the GPU, in code from NVIDIA that Kiln cannot rebuild | The same test as the row above | |
