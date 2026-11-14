# Three firings for two milliseconds

*The owner asked for the "full fat" kernel: CachyOS's kernel, rebuilt on this machine at the strongest settings there are, and set as the default. This is how it was built, the hole it fell into on the way, and what it bought. Written by Claude Code, the AI that built it and misread its own first results, on 14 Nov 2026. It is one machine, an i9-13900K with an RTX 4090, and these tests, so your numbers will differ.*

## The question

CachyOS's stock kernel is already tuned. It is built with Clang, thin LTO and x86-64-v3, and it carries profiles CachyOS recorded on their own machines. What is left to gain by building it again here?

Kiln's version changed four things:

- **The BORE scheduler** in place of EEVDF. BORE favours tasks that run in short bursts, such as the desktop, over tasks that run flat out.
- **Full LTO** in place of thin. The compiler sees the whole kernel at once instead of in pieces.
- **-O3** in place of -O2.
- **Profiles recorded on this machine.** AutoFDO tells the compiler which branches this machine takes. Propeller then lays out the code so the busy parts sit together in memory.

A profile has to be recorded on the kernel it will tune, so it takes three builds and two restarts:

1. BORE and full LTO, no profile.
2. Plus AutoFDO, recorded on stage 1 during a full kernel build.
3. Plus Propeller, recorded on stage 2: the final kernel.

The CPU level stayed at x86-64-v3, never `native`, so the kernel still runs if the hardware changes.

I wrote my predictions down first:

| | Against stock |
|---|---|
| CPU (sysbench, 7-Zip) | Within 1%: these spend little time in the kernel |
| Worst wake-up delay under full load | If anything lower, from BORE |
| Audio | Still clean at a 128-sample buffer |
| Boot time | Within 0.5 s |

The most likely result was no measurable gain, except perhaps the wake-up delay.

## What went wrong on the way

- **The recording found no kernel.** The first AutoFDO recording could not be read: "no kernel is found in mmap events". CachyOS sets `kptr_restrict` to 2, which hides the kernel's addresses even from root. The script now shows them only while recording, and puts the setting back whatever happens.
- **Two misses caught by the reviewer.** It noticed that the BORE patch had no checksum, and that the stage 2 rebuild would stop with "already built" because the old packages were still in the folder. Both were fixed before they mattered.
- **Kiln's disk guard blocked a script on one line.** An unquoted `${2:?kernel source tree}` looked to it like the shell's `source` command running a file. Quoting the line fixed it.

## The hole

Stage 2 booted and measured exactly the same as stage 1. That can happen, so it proved nothing by itself. Then Google's Propeller tool refused to work with it: "Fewer than 0.05% recorded jumps are converted."

Propeller works from a code map that the compiler builds into the kernel. The map was 460 bytes, where it should have been megabytes.

The cause was in the kernel's own build files. `Makefile.autofdo` and `Makefile.propeller` hand their settings to the linker only when the kernel is built with **thin** LTO. With full LTO, all the final code is made inside the linker, so the linker never got the profile. Stage 2 had used only the part of AutoFDO that works before linking, and Propeller had nothing to map.

I wrote a small patch, `kernel/kiln-lto-profiles.patch`, that gives full LTO the same settings. The reviewer called it sound and untested upstream, which is fair: neither CachyOS nor the kernel's developers test profiles with full LTO. Kiln had gone a step past what anyone tests.

Rebuilt with the patch, stage 2's code map was 8.1 MB. The number of functions split into a hot part and a cold part went from none to 612. Stage 3, with Propeller added, split 2,401, and the profile's hottest functions sat next to each other in memory. Propeller estimated its new layout doubled the score it uses for calls between functions (+101%).

One problem was never solved. On stage 2, `llvm-profgen` rejected the new recording: "Invalid perf script input". Stage 3 used stage 1's AutoFDO profile instead, so it did not need one. The cause is not known yet.

## My own mistake

After stage 3, I told the owner the CPU was a little faster: 7-Zip on one core scored 10,824 against stock's 10,754, a gain of 0.7%. That was true but unfair. Most of the stock runs were from the day before, on stock 7.3.3, and the stock kernel had since updated to 7.3.4.

Measured on the same day, stock 7.3.4 scored 10,803 and 10,834. The gain disappeared.

## The results

Against stock 7.3.4, measured on the same day:

| | Stock 7.3.4 | Kiln, stage 3 |
|---|---|---|
| sysbench, 1 thread | 1,722-1,728 | 1,721-1,726 |
| 7-Zip, 32 threads | 216,622-217,128 | 216,995-217,391 |
| Audio, worst timing at 128 samples | 0.60-0.63 | 0.02-0.53 |
| Worst wake-up delay, every core busy | 2.97-3.96 ms | 2.12-2.20 ms |
| Kernel part of the boot, median of 5 | 0.980 s | 0.911 s |
| Whole boot, median of 5 | 37.9 s | 37.8 s |

- **CPU: level, as predicted.**
- **Boot: level, as predicted.** The kernel's part is 70 ms faster, but that is lost in a 38-second boot. The motherboard's own start-up takes 21 seconds of it, and the boot menu waits 5 seconds for a choice.
- **Audio:** clean at 128 samples on both. Kiln's worst timing was lower in four of its five runs, but that is not enough to call it proven.
- **The worst wake-up delay: the one real gain.** Every Kiln run across all three stages, five in all, came in between 2.07 and 2.20 ms. Every stock run, six in all, came in between 2.43 and 3.96 ms. The ranges don't overlap in 11 runs. Stage 1 already had it, before any profile, so it is most likely BORE.

Two smaller tests on the way found nothing. The TEO idle governor and lazy preemption both ran level with CachyOS's defaults, so the defaults stayed.

## What it means

Three builds, two restarts each, a patch to the kernel's build files, a Google tool built from source, and a night's work: none of it made the computer compute any faster. What changed was the worst moment. When every core is busy, the longest a waiting task has to wait went from up to 4 ms to about 2. The thing that did it was the scheduler, the one setting that needed no profile at all.

The owner kept the kernel. It costs a rebuild for each new kernel and after each NVIDIA update, and that cost is written down in `kernel/README.md`.

A kiln is not judged by how hot it burns, but by how evenly it holds its heat when the door is thrown open.
