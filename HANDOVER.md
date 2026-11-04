# HANDOVER — Kiln Linux

The coordination log between the owner, Cowork and Claude Code. Newest entry at the top.

## Current state

- Stage: Stage 1. Steps 3 to 7 are complete. Step 8 is built. The mlrig kernel boots, with 3 checks failed. The rescue kernel has not been checked, and can wait, by owner's decision. Step 9 is done: Kiln boots to the desktop, with network and sound working. Claude Code runs on Kiln, signed in. Step 10: parts 1 and 2 of 4 are done. Part 3 is built, and has not yet been booted.
- Priority, by owner's decision: Kiln boots to the desktop, then work moves to Claude Code on Kiln, to end the restarts into the live image.
- Target: mlrig, Crucial P2 1 TB drive only. Omarchy has been wiped. Two kernels, the boot loader, the guard and the desktop are on it, with snapshot 5 taken (3 Nov 2026). Kiln now runs from this drive.
- Owner decisions: all ten decided. See the Answer column in docs/STAGE1_SPEC.md.
- Owner wants Chromium compiled for mlrig, after step 9 and once the step 11 settings are on. Not started.
- Owner wants the Claude desktop app at some point. Not part of step 10. Not started.
- Baseline: Ubuntu 26.10 on mlrig only. Omarchy is skipped.
- Screen: mini DisplayPort from the WX 3200, live images included. HDMI into the RTX 4090 is the fallback if a live image shows a black screen.

## Next step

Part 4 of step 10 is postponed by the owner, who wanted the Omarchy look first. It includes the first boot of a past snapshot, which also proves part 3. `undo` takes back the newest change, so do not run it without checking what it names first.

Now: the cause of Rust's slowness is found, see the log of 4 Nov. The overfire options and a real-program test run in memory first, with `scripts/rust-llvm-lab.sh`. Then the owner approves the winning recipe and a real `emerge` tests it. Then write the first story and report. After that, in order, unless the owner changes it: Part 4's safety tests, then the new login screen, as `tuigreet` is plain text and the owner finds it appalling. Claude Code suggests trying `gtkgreet` first. Then the rest of Part 4, with repeat wake-up runs and the ThinLTO benchmark. Step 11, compiler first. Step 12. Then the live image, as Stage 2. Later: 7.4-rc1 with Clang, for testing only, never as the default, and the overfired 7.3.1. To test a kernel, the owner chooses it from the 3-second menu, then starts Claude Code with `claude --continue` in ~/Projects/kiln, to check it and run `scripts/bench-kernel.sh`. Still missing from the desktop: notifications, a lock screen and screenshots.

Step 10, in four parts, reporting back after each:

1. Sidekick key and rules file. Done.
2. Hooks for rules 1 and 2, with the change log and `undo`. Hooks go in the protected folder, installed by the owner's hand. `undo` restores only `~/.config` in the home folder, by owner's decision. Done.
3. Past snapshots in the boot menu, with milestones and `restore`. Installed, not booted.
4. Tests: break the desktop and recover with `undo`, boot the rescue kernel and a past snapshot, and run a real `restore` and `restore --back`. A fix for the guard's false alarms, installed by the owner's hand.

To reach Kiln, the owner presses F8, chooses the Crucial, logs in as `indy`, and presses Super+Space.

Open, and not holding this up:

- The rescue kernel: boot it from the 3-second menu and run `kiln-first-boot-check`, as in docs/FIRST_BOOT.md. It writes to its own folder in /var/log/kiln-first-boot/ on the Crucial. Then copy the results as for the mlrig kernel, with IDs removed.
- The first-boot guard test always shows 1 failure on Kiln, because it counts the Crucial's own writes. Fixing the test goes through the owner's hand.
- Omarchy's Hyprland settings are ported, but not its shell or scripts. See the log.

The Crucial shows in F8 as `UEFI OS`, because the `Kiln` entry has gone. If Kiln does not start, Ubuntu is untouched and first, and it can be fixed from the live image.

To re-test the guard after any change, the owner runs `sudo tests/guard/fake_disks.sh --installed-rule` in a terminal, because the hook blocks Claude from running it.

After any restart of the live system, the guard is gone. Clone the repo and run `sudo guard/install.sh` again before any disk work, and restart Claude Code so it loads the hook. Work is merged to main before each restart.

Baseline still open: 4 more Ubuntu boots. The owner runs `scripts/measure.sh boot` whenever he next boots Ubuntu, over time. This does not hold up Kiln.

## Log

### 4 Nov 2026 — Claude Code, why Rust was slower

- The restart after Mesa's LLVM change went fine: no failed services, on the Full LTO kernel.
- Found on the one-core test: the whole gap to `rust-bin` is in `libLLVM`. Our driver with the official `libLLVM` matches `rust-bin`, at 17.2 s. Results: results/rust-gap/runs.csv. Tool: scripts/rust-llvm-lab.sh. Predictions: docs/HYPOTHESES.md.
- With `rust-bin` at about 17.16 s: installed 21.24 s, `-DNDEBUG` restored 18.6 s, adding ThinLTO 17.98 s, adding BOLT 17.34 s, 1% behind. The last 1% is not explained.
- Biggest cause: Gentoo's recipe replaces CMake's release flags with ours, which drops `-DNDEBUG`, so LLVM's C `assert` stays on despite `assertions = false`. With that section the lab got 21.33 s, and without it 18.61 s. The installed library calls `__assert_fail`.
- Correction: the log's "own LLVM with Full LTO" and "the same with PGO" were wrong for LLVM. `rust.lto` covers only the Rust half, and the recipe removes LTO from LLVM. The 28.03 s came out as 26.76 s in the lab, and the 1.27 s left over is not explained.
- Also tested, on ThinLTO: Full LTO 18.13 s against 17.98 s, with no BOLT. Gentoo's safety settings off 17.83 s. Generic CPU 18.25 s. Static libstdc++ 17.99 s.
- Limits: one made-up test, with similar code in the training. Proved in the lab only, and not through a real `emerge`. Nothing is installed, and `rust-bin` stays active. Whether this is known to Gentoo has not been checked.
- Owner's decisions: two new folders, not yet created. `kiln-stories/`: overfiring that went badly, and how it was troubleshot, for people to read, first story this one. `ai-bug-reports/`: one report per proved bug in another project, named project first, starting with short mlrig specs, with a status line. It is only for developers who come to the repo to read it. Claude Code files nothing with any project. Cowork: both are new for the spec.

### 3 Nov 2026 — Claude Code, Rust attempts

- `rust-bin` is the active compiler, by owner's decision, until a source build beats it. `rust-1.98.1`, the latest attempt, stays installed beside it.
- Test: one made-up program, on one core, in results/compilers/rust.csv. `rust-bin` stayed at about 17.2 s throughout, as the control. Gentoo's LLVM with Full LTO: 23.60 s. Own LLVM, jemalloc and Full LTO: 28.03 s. The same with PGO for LLVM and rustc: 21.31 s. So PGO gained 24%, but it is still 24% slower than `rust-bin`.
- The PGO stages are hooks in config/portage/env/dev-lang/rust. Training compiles `cargo`, in debug and release, plus made-up code. The whole build took 56 minutes, and worked first time.
- Not known: why `rust-bin` stays faster. Ideas, none tested: BOLT, which I recall the official build using. Richer training. LLVM's own build settings. Whether programs built by each compiler differ in speed has not been measured.
- A caution on the test: it is one program, heavy on LLVM's optimiser, on one core, so it may not represent all Rust builds.
- Not committed yet, as the owner stopped for the day.

### 3 Nov 2026 — Claude Code, compilers maxed out

- Owner's decision: build the compilers at maximum now, and postpone part 4's tests. Those tests, including a real `restore`, remain unproved.
- Results, compiling the same kernel, median of 3, with the other compiler as a control: GCC 76.1 s to 66.6 s, 12.5% faster. Clang 89.5 s to 84.7 s, 5.4% faster. Results: results/compilers/. scripts/bench-compilers.sh and scripts/bench-rust.sh repeat them.
- GCC and binutils: PGO, LTO for GCC, `-O3`. GCC's recipe refuses `-march=native` on this hybrid chip, as the core types report different L1 caches. Their recipes also strip all but `-march=alderlake`. LLVM, Clang and lld: Full LTO, `-O3`, `-march=native`, built by Clang. Their recipes have no PGO option. Rust: built from source with Full LTO, using a hook in env/dev-lang/rust.
- Rust got slower: 17.20 s to 23.60 s, 37%, on a one-core test. Prediction wrong. Cause not proved. It uses Gentoo's system LLVM, and the ready-built compiler brings its own, larger, compiler library. From memory, not checked here, Rust's official builds use PGO and BOLT. `rust-1.98.1` is the active compiler now. `rust-bin` stays installed. Owner to decide.
- Audit: 76 of 451 packages with compiled code, 16.9%. `mesa`, `greetd`, `tuigreet` and `dynolog` still lack Rust's setting. Python and glibc are still ready-built, and programs built earlier have not changed.
- Checks after: build settings 39 passed, PyTorch still sees the GPU, no failed services, guard OK. Mesa's `libLLVM` was replaced while the desktop ran, so a restart is the real test.

### 3 Nov 2026 — Claude Code, flags audit, the before figure

- Added tests/audit/flags_audit.py, written before step 11 by owner's agreement. It reads Portage's records, looks inside each package for compiled code, and checks Rust and Go settings. 14 tests plant wrongly built packages in a fake system, and each one is caught. Exceptions: tests/audit/exceptions.txt.
- Before figure: 802 packages, 447 with compiled code. Built for this CPU, as asked: 67 of 447, 15.0%. 371 ready-built: 319 at v3, and 52 with no level recorded, most likely the generic starter build. 5 exceptions, 355 with no compiled code. Result: results/flags-audit/2026-11-03-1600.txt.
- It found 4 packages compiled here without Rust's CPU setting, as they came before `RUSTFLAGS` was set: `dynolog`, `tuigreet`, `greetd` and `mesa`. Step 11 rebuilds them.
- GCC, Python, glibc and binutils are ready-built v3. Clang and `rust-bin` have no level recorded. So the compilers are not yet built for this CPU.
- Limits: "as asked" is Portage's record. 4 recipes may change their flags. Proof from built files covers a sample only: 4 kernels, PyTorch and torchvision, all passing. It does not check PGO or LTO yet. Kernels are outside Portage, so they are in the sample, not the count.

### 3 Nov 2026 — Claude Code, Cowork's prompt: spec, Rust and Go

- docs/STAGE1_SPEC.md now matches the Claude Doc on steps 6 and 11, the CPU speed row and the benchmark sentence. The owner said to skip plan approval. Still different: both say pushes are by the owner's own hand, and rule 7 has changed.
- Rust: `RUSTFLAGS` in make.conf targets this exact chip, with `opt-level=3` and `codegen-units=1`. Gentoo's cargo tooling passes it on. rebuild.conf adds Full LTO for step 11. Existing Rust programs change only when rebuilt.
- Go: `GOAMD64=v3`, as Go has only broad levels and this chip has no AVX-512. So Go cannot be built for this exact chip, and the audit must say so. Go is not installed, so the check tests the setting, not a real build. No Go program is on Kiln yet.
- tests/build-settings/check.py has new Rust and Go checks: 39 passed, none failed, one skipped for Go. Result: results/build-settings-check.txt.
- Cowork: the prompt writes the audit at step 11. Claude Code recommends writing it before step 11, for a before figure and to guard the rebuild, and running it after every update, not only compiler updates, as Kiln fetches ready-built packages. The owner has not objected. Please update the spec if agreed.

### 3 Nov 2026 — Claude Code, ML benchmark

- Added scripts/bench-ml.py, about 5 minutes, on made-up data. First full result, on Full LTO with driver 615: ResNet-50 training 1388 images per second, and inference 4351. Transformer training 36,580 tokens per second, on a 217 million parameter model, using 17,374 MiB. CPU inference 92.9 images per second, and JPEG decoding 245.7 per second on one thread. Results: results/ml-bench/.
- 3 minutes of sustained training: no speed drop, no throttling, peak 67 °C and 356 W, no GPU driver errors.
- Two predictions right. The third, overfired against ordinary PyTorch, needs the same script run on Ubuntu with ordinary PyTorch. The owner would run that there. Made-up data, so no disk or real data-loading work is measured.

### 3 Nov 2026 — Claude Code, driver 615 proved

- After a restart, 615.78.08 loads by itself on the Full LTO kernel. The same default-built test that failed on 595.104.02 now passes. scripts/test-pytorch.py passes, torchvision included, with timings about the same as before. No GPU driver errors. Results: results/nvidia-615-2026-11-03/.
- `mlrig` has the 615 modules too, but has not been booted with them. 595.112.07's and 615's Gentoo recipes both say kernels up to 7.3, so 7.4-rc1 may still need work.

### 3 Nov 2026 — Claude Code, driver 615 installed, not yet loaded

- Owner's decision: update the driver, to match CUDA 13.4. NVIDIA pairs 13.4 with its R615 driver branch, and 13.x programs run from R580 up.
- Test first: `tests/nvidia/ptx_check.cu`, built with default settings, fails on 595.104.02 with "unsupported toolchain". Result: results/nvidia-615-2026-11-03/ptx-check.txt. The prediction is in docs/HYPOTHESES.md.
- Installed `nvidia-drivers` 615.78.08 from Gentoo's testing branch, and rebuilt the modules for `mlrig` with the recipe and for Full LTO with scripts/build-nvidia.sh. Both report 615.78.08.
- Not yet run: the old modules stay loaded until a restart, so `nvidia-smi` may fail until then. After it: `ptx_check` again, and scripts/test-pytorch.py.

### 3 Nov 2026 — Claude Code, torchvision and the uv exclude list

- `UV_EXCLUDE=/etc/kiln/uv-exclude.txt` is set in login shells and in Hyprland, and names `torch` and `torchvision`. A dry run keeps both out, in a login shell, and a new terminal window has the setting. It covers `uv pip` only, not `uv sync`.
- Built `sci-ml/torchvision` 0.29.2 from source with CUDA. `scripts/test-pytorch.py` passes, including torchvision on the GPU.
- Its default GPU code failed on this driver with "unsupported toolchain". So the CUDA 13.4 toolkit against a driver reporting 13.2 does matter for code built for an older generation. `NVCCFLAGS="-O3 --gpu-architecture=sm_89"` fixes it. `NVCC_FLAGS` has no effect, as the recipe overwrites it. Any other program compiled with default CUDA settings may hit the same fault. A newer driver may fix that in general: 595.112.07 and 615.78.08 are in Gentoo's testing branch, and any change needs the modules rebuilt.

### 3 Nov 2026 — Claude Code, uv and PyTorch on the RTX 4090

- NVIDIA loads by itself at boot on the Full LTO kernel, all four modules.
- Installed from source for this CPU, with Gentoo's recipes: uv 0.13.4 and PyTorch 2.15.0, with 59 other packages, in about 40 minutes of build time. Results: results/pytorch-2026-11-03/. PyTorch, its maths libraries and others use `-O3 -march=native`. uv was given Full LTO and this CPU, but that is what it was asked for, not proved.
- Not from source, as NVIDIA supplies them ready-built: the CUDA toolkit, cuDNN and cuSPARSELt. The owner accepted their licences.
- Two fixes. A one-line patch, as PyTorch names an event that Gentoo's Kineto lacks: config/portage/patches/. And `TORCH_CUDA_ARCH_LIST=8.9`, because the recipe's default of 7.5 cannot run on a 4090. `nccl` is left out, as the recipe allows it only for AMD GPUs. No LTO yet, as the recipe removes it.
- scripts/test-pytorch.py passed on the GPU: maths, gradients, cuDNN and training. CUDA 13.4 works on the driver that reports 13.2. Its CPU timings are not fair, as the test uses bfloat16 there, which this chip probably has to emulate. Do not quote the GPU against CPU ratio.
- Correction: Claude Code told the owner that a uv environment using the system's packages would stop `uv pip install torch` replacing PyTorch. A dry run shows it does not. It would fetch generic PyTorch and CUDA, about 29 packages. `uv pip install --excludes FILE`, or `UV_EXCLUDE`, keeps them out in dry runs. `uv sync --no-install-package torch` is not enough, as it still fetches torch's other packages. A PyPI torchvision built for generic PyTorch may not match, and Gentoo has `sci-ml/torchvision`.

### 3 Nov 2026 — Claude Code, ArtCraft apps idea

- Owner's idea: offer ArtCraft's open-source apps on Kiln, such as PhotoCraft, LightCraft, FilmCraft and PdfCraft. Not started. Claude Code suggests own recipes, built for this CPU, installed when the user asks, not by default, as the vision wants only the bare minimum of apps. Reports call them early alpha, and they are Rust. To check first: their licences, the DAW and office apps, and how much they rely on the maker's AI service. Cowork: for the spec.

### 3 Nov 2026 — Claude Code, hypotheses

- Owner's decision: write down what we expect before each big step, in docs/HYPOTHESES.md, and never edit a prediction once its test has run. First six predictions added, all Claude Code's. The owner can add their own.

### 3 Nov 2026 — Claude Code, sharing plans

- Owner's plan: share through the public repo, and later a post on r/ClaudeAI, once there is a live image that users can download and install. Not before.
- Gentoo's Council bans contributions made with AI tools, so Kiln should not send Gentoo its patches or text. The owner could report the PyTorch and Kineto mismatch in their own words.
- Cowork: the spec puts the installer and a public release out of scope for Stage 1. The live image needs a place in the plan, Claude Doc first. Before posting: repeat benchmark runs, an honest README, and a full privacy pass over the repo and its history.

### 3 Nov 2026 — Claude Code, Full LTO is the default

- Owner's decision: `7.3.1-gentoo-kiln-clang-fulllto` is the boot menu's default. Ubuntu stays first in the firmware order. `mlrig` and the rescue kernel stay in the menu, and past snapshots still boot with `mlrig`.
- `restore` now switches the default back to `mlrig` if the snapshot lacks the default kernel's drivers. Otherwise an older snapshot would boot into a kernel with no modules. 43 tests pass, with a stand-in for the real disk steps. A real `restore` still has not run. The fix needs `sudo sidekick/install.sh`.
- The pointer setting `no_hardware_cursors = 1` is now in the repo's hyprland.lua, for every kernel. Still to find out: whether `mlrig` needs it.

### 3 Nov 2026 — Claude Code, NVIDIA on the Full LTO kernel

- Owner's decision: use the Full LTO kernel for a while, with NVIDIA's open driver.
- Added scripts/build-nvidia.sh. It builds NVIDIA's open modules 595.104.02 with Clang for one extra kernel, in that kernel's own folder, unknown to Portage. It took 40 seconds. Its build log is 6 MB, so it stays out of git. Run it again after `nvidia-drivers` updates, and raise the version in it.
- `nvidia-smi` reports the RTX 4090, 24564 MiB, driver 595.104.02. The script loaded nothing, but a check Claude Code ran, `nvidia-smi --version`, seems to have loaded `nvidia` and `nvidia_uvm`, before the owner had been asked. No harm seen: no kernel faults, and the desktop stayed on the WX 3200. The kernel is marked tainted, 4096, the normal mark for a module from outside its tree.
- Not tested: real compute work, such as CUDA, and whether it all loads after a restart. `nvidia_drm` is not loaded yet.
- `undo` and `restore` do not manage these modules directly. A restore to a snapshot older than them loses them, along with this kernel's other drivers.

### 3 Nov 2026 — Claude Code, Full LTO booted and measured

- `7.3.1-gentoo-kiln-clang-fulllto` boots and passes the same checks. The Crucial was `nvme2n1` this boot, not `nvme1n1`. The guard found it by serial and shows OK.
- Against Clang without LTO: pipes 19% slower, 2.428 against 2.039 s, and their ranges do not overlap, so this looks real. Sockets 1% faster, kernel compile the same, sysbench and 7-Zip within 0.5%.
- Wake-up delay is better: 99.9% 1197 against 1726 microseconds, and worst 3361 against 4698. It is one run each, so this needs repeating. 99% 62 against 59.
- Why pipes got slower is not known. Full LTO was used without a profile to guide it.

### 3 Nov 2026 — Claude Code, Full LTO built, not booted

- Owner's correction: ThinLTO broke the vision. Kiln takes the strongest setting, and build time and small gains are not reasons to choose less. Claude Code had picked ThinLTO for the usual practical reasons, with no measurement. Correctness is still the limit.
- Built `7.3.1-gentoo-kiln-clang-fulllto` in 591 seconds, under 10 minutes, on this machine, against 354 for ThinLTO and 234 without LTO. So the fear of a very long build did not apply here.
- Proved: `init/main.o` is LLVM bitcode, and its build record shows `-flto` and `-march=native`. That is one file checked. Kernel image 23.4 MB, against 20.2 MB for ThinLTO and 19.9 MB without LTO. 223 modules, and the main drivers are present.
- Not booted. The default and firmware order did not change, and the guard shows OK. `/boot` has 1.7 GB free.

### 3 Nov 2026 — Claude Code, Clang chosen, ThinLTO built, not booted

- Owner's decision: Clang for kernels, replacing the earlier rule of a GCC and a Clang version of each. The reason is the projects' policies on AI-written code. GCC declines legally significant LLM-generated contributions, for now, with a review by the start of 2027. LLVM accepts them with a human in the loop. Both ban agents acting alone. Sources: gcc.gnu.org/ai-policy.html and llvm.org/docs/AIToolPolicy.html. The rest of Kiln still builds with GCC.
- Removed `7.3.1-gentoo-kiln-gcc`: its boot entry, /boot files, modules and build folder. Its config and results stay in the repo.
- Built `7.3.1-gentoo-kiln-clang-thinlto` in 354 seconds, against 234 without LTO. ThinLTO rather than Full was Claude Code's choice, as CachyOS uses it and it builds faster. Full can be added later.
- Proved: `init/main.o` is LLVM bitcode, and its build record shows `-flto=thin` and `-march=native`. That is one file checked. Its kernel image is 20.2 MB, against 19.9 MB without LTO. 223 modules, and the main drivers are present.
- Not booted. The default and firmware order did not change, and the guard shows OK.
- Cowork: the kernel plan and this choice are new for the spec, Claude Doc first.

### 3 Nov 2026 — Claude Code, 7.3.1 Clang booted and measured

- `7.3.1-gentoo-kiln-clang` boots and passes the same checks as GCC. Its pointer works with the same live setting. The owner thinks the Omarchy config caused the missing pointer, which fits, as it first showed at the first full restart after that change. Not proved until `mlrig` is booted without the setting.
- Clang against GCC on 7.3.1, both without LTO: a tie. Sockets 2.488 against 2.498 s, pipes 2.039 against 2.030 s, kernel compile 76.5 against 76.6 s. sysbench and 7-Zip within 0.5%.
- Wake-up 99.9% is 1726 microseconds on Clang and 1705 on GCC, against 842 on 6.18. Two 7.3.1 runs agreeing makes this more likely a real change than chance, but 6.18 has only one run, and it had the NVIDIA driver loaded. Wake-up 99% moved around: 59 on Clang, 77 on GCC, 61 on 6.18, so that figure is noisy at one run each.

### 3 Nov 2026 — Claude Code, 7.3.1 GCC booted and measured

- `7.3.1-gentoo-kiln-gcc` boots. No failed services, the guard shows OK, and network, sound setup and desktop programs are running. The bar, shortcuts and screen-off start at login, and the owner opened the terminals seen, so no windows open by themselves. `nvidia-smi` fails here, as expected, because this kernel has no NVIDIA modules. The owner reported no pointer. The mouse itself worked. Setting `no_hardware_cursors = 1` brought the pointer back.
- That setting is in ~/.config/hypr/hyprland.lua only, not in the repo. Not known yet: whether the cause is 7.3.1, or the first full restart with the Omarchy settings. To find out, boot `mlrig` without the setting. Until then, do not copy the repo's hyprland.lua over the live one.
- Compared with 6.18 `mlrig`: pipes 40% faster, sockets 9% faster. sysbench and 7-Zip 2% or less better, and kernel compile about the same. Wake-up delay under load is worse: 99% 77 against 61 microseconds, 99.9% 1705 against 842, and worst 5702 against 4850.
- Caution: the wake-up test is one 30-second run, so it needs repeating before anyone trusts it. Also not equal between the runs: 6.18 had the NVIDIA driver loaded and started from a higher load, and the pointer setting differs.
- No problem was seen by the kernel during the test beyond the two minor errors at start-up.

### 3 Nov 2026 — Claude Code, kernel benchmark

- Added scripts/bench-kernel.sh, about 10 minutes, for comparing kernels: hackbench, sysbench, 7-Zip, compiling a kernel, and wake-up delay under load. Results: results/kernel-bench/table.csv. Tools installed: sysbench, 7zip, and rt-tests, from Gentoo's testing branch. scripts/measure.sh stays the full comparison with Ubuntu. It also needs `pw-cat`, which is not on Kiln, so step 12 needs pipewire's `extra` flag.
- First result, 6.18.60 `mlrig`: sockets 2.750 s, pipes 3.382 s, kernel compile 76.8 s. Wake-up 99% 61, 99.9% 842, worst 4850 microseconds. sysbench 1734 and 40094. 7-Zip 8602 and 168915. Repeats were close together.
- Found: 7-Zip scores about 18% to 20% below Ubuntu's baseline. sysbench is about 2% above. Kiln's 7-Zip is a ready-built v3 package, without its `uasm` or `jwasm` flag, which is likely why, but this is not proved. Run settings also differ: 2 passes here and 10 on Ubuntu, a different 7-Zip version, a different kernel, and the performance governor here against Ubuntu's powersave governor with performance profile.
- Cowork: the benchmark is new. Step 12 is unchanged.

### 3 Nov 2026 — Claude Code, 7.3.1 with Clang, not booted

- Built `7.3.1-gentoo-kiln-clang` with Clang 22.1.8 and LLD, in 234 seconds. Config: config/kernel/kiln-7.3.1-gentoo-clang.config. 61 config lines differ from the GCC version, mostly compiler-specific ones, not yet reviewed line by line.
- Proved, not only asked for: the version string in each kernel names its compiler, and each build's record of compiling `init/main.c` shows `-march=native`. That is one file checked in each, not every file. Neither uses LTO, so the pair compares fairly.
- Both have 223 modules. The default and firmware order did not change, and the guard shows OK.
- NVIDIA: the owner asked why it is missing. It was left out to keep the first test simple. Gentoo's recipe builds for one kernel at a time, so a small script could build the modules from the source already on this machine, for each extra kernel. Every Gentoo recipe, even 615, says it supports up to 7.3. Not started.

### 3 Nov 2026 — Claude Code, 7.3.1 with GCC, not booted

- `restore` now only needs a snapshot to hold the default and rescue kernels' drivers, and warns about newer kernels that would not work from it. The owner installed the fix. 40 tests pass, but a real `restore` still has not run.
- Built `7.3.1-gentoo-kiln-gcc` with scripts/build-kernel.sh, in 205 seconds, from mlrig's settings. Config: config/kernel/kiln-7.3.1-gentoo-gcc.config. Log: results/kernels-7.3.1-gentoo-2026-11-03/. It has not been booted.
- Read back: 6.18.60 `mlrig` is still the default and the rescue kernel is still listed. `eselect kernel` still points at 6.18, and Ubuntu is still first in the firmware order. The guard shows OK. `/boot` has 1.8 GB free.
- Drivers compared with 6.18: no NVIDIA, as planned, so no RTX 4090 on this kernel. `nfnetlink` is now built in, and `iTCO_vendor_support` has gone. Two config warnings, both harmless.
- `gentoo-sources:6.18.60` and `:7.3.1` are now both in the world file, so a clean-up cannot remove the 6.18 source that NVIDIA builds against.
- Correction: `mlrig` already runs at 1000 Hz, so the overfired kernel gains nothing there.

### 3 Nov 2026 — Claude Code, vision updated

- Owner's decision: Kiln exploits every hardware feature it can, whatever the size of the gain. The compiling itself must not run generic either. The word for this is overfiring. Added as a new first section, The obsession, in the Claude Doc and then docs/VISION.md.
- Owner's decision: keep today's kernels and add more to choose from at boot, each new one in a GCC and a Clang version. In order: 7.3.1 plain, 7.4-rc1 plain, then 7.3.1 overfired, with BORE and a profile of this machine's own use. Cowork: this is new for the spec, Claude Doc first.
- Cowork: the spec's step 11 starts with the kernel, graphics and audio. This decision suggests rebuilding the compiler and build tools first. For the spec, Claude Doc first.
- Cowork: a pasted prompt on Rust, Go and the flags audit is on hold until the owner has finished discussing it. It says to audit after every compiler update. Claude Code suggests after every update, as Kiln fetches ready-built packages.

### 3 Nov 2026 — Claude Code, bar, launcher and screen-off

- Owner's decisions: separate small programs rather than Omarchy's shell, and the screen turns off after 10 minutes idle.
- Installed from Gentoo: `gui-apps/waybar` with the `network` flag, `gui-apps/wofi` and `gui-apps/swayidle`. Fuzzel and Omarchy's launcher have no Gentoo recipe. Settings: config/waybar/, config/wofi/, and kiln-apps and kiln-idle in config/usr/local/bin/.
- Super+R opens the launcher, and Super+Shift+Space hides the bar. Both are new. The shortcuts image now lists Super+R.
- Seen running: the bar sits at the top, 36 pixels tall, and windows moved below it. The idle timer is running.
- The owner tried the bar and launcher, and reports all works. The bar, swaybg and the idle timer start at login, which is proved at the next restart.

### 3 Nov 2026 — Claude Code, gaps, layout and desktop shortcuts

- Owner's requests: no gaps between windows, no windows at login, shortcuts on the empty desktop in a large font, and equal columns on this screen. On a standard screen, 2 halves, then the right half splits, then 2 by 2.
- The layout is a custom one in config/hypr/hyprland.lua. Measured on this screen: 1 window fills it, and 2, 3, 4 and 5 windows each get equal columns. Window borders stay, so a 4-pixel line shows between windows.
- Not tested: the standard-screen branch, as there is only this screen. Also not tested with this layout: swapping windows, and resizing, which may not hold, because the layout sets equal widths.
- The shortcuts are an image, config/desktop/make-shortcuts.py makes it, and `swaybg` shows it. Installed `gui-apps/swaybg` from Gentoo. It was started by hand this session, so showing at login is proved at the next restart.
- Nothing is set to open at login. Proved at the next restart.
- The screen is OLED, and nothing turns it off when idle, so a still image on an empty desktop could wear it over time. The image is on black, in muted colours. An idle screen-off is for the owner to decide.

### 3 Nov 2026 — Claude Code, Omarchy's Hyprland settings

- Owner's decision: adopt the Omarchy config now, and do the part 4 tests later.
- Omarchy 4.0 alpha (commit ae64a4b) already writes its Hyprland settings in Lua, so nothing needed converting. Kiln's Lua 5.5.1 recipe from step 9 runs them. Whether 5.5.1 is the newest Lua was not checked.
- config/hypr/hyprland.lua now has Omarchy's look, animations, window rules, input feel and key bindings, credited, with its MIT licence beside it. The colours are its Tokyo Night theme, assumed to be its default, as its installer did not show one in a quick search. Hyprland reports the config OK, with no errors live.
- Kept as Kiln's: the screen mode, US layout, Super+Space and mouse buttons. Mouse copy and paste now use Omarchy's method, which sends key down and up separately. Not yet retried by the owner.
- Left out, because they need other parts of Omarchy: its shell, which is its bar, launcher, menus, notifications and lock screen, on Quickshell. Also 87 omarchy-* scripts, themes, wallpapers, screenshots, the Quake console and media keys. Omarchy expects over 300 packages, and is Arch-based.
- Cowork: this closes the spec's "configs borrowed from Omarchy and credited" for Hyprland only. The vision wants only the bare minimum of apps, which weighs against taking Omarchy's whole shell.

### 3 Nov 2026 — Claude Code, milestones and restore

- Owner's decisions on the two open points below: milestones stay in the boot menu, and there is a restore command.
- The menu keeps the 3 newest milestones beside the 5 newest snapshots. A milestone is a snapshot with `milestone=yes`, and has no automatic cleanup. Snapshot 6, the first working desktop, is the first.
- `restore` makes a past snapshot the system from the next restart. It sets the current system aside as `@.old-<date>`, and `restore --back` reverses it. It runs only in a terminal, by hand. Set-aside systems stay until removed, which uses space.
- Program: sidekick/kiln_snapshots.py, moved from config/usr/local/bin. 36 tests pass, with a stand-in for the real disk steps. A real `restore` has not been run.
- Restoring a snapshot older than the hooks removes them until `sudo sidekick/install.sh` is run again. `restore` warns about this. Snapshot 6 is one of these.
- After a restore, `undo` will not touch earlier changes, as they no longer match the system.
- Read back: the mlrig kernel is the default, the rescue kernel is listed, Ubuntu is first in the firmware order, and the guard shows OK.
- Seen in use: the hook still asks about some commands that only touch the repo, such as `python3` tests and `git mv`. Each takes snapshots, so the menu's 5 newest are often tiny steps. Milestones cover this for now.
- Cowork: `restore` goes beyond the spec, by owner's decision. The spec needs a line for it.

### 3 Nov 2026 — Claude Code, step 10 part 3, not booted

- The boot menu now lists the 5 newest usable snapshots, newest first, after the two kernels. Program: config/usr/local/bin/kiln-snapshot-menu. It updates itself when snapshots change. 9 tests pass.
- Read back: the mlrig kernel is still the default and the rescue kernel is still listed. Firmware boot order is unchanged, with Ubuntu first. The guard shows OK.
- A snapshot is left out unless it holds the disk guard and the kernel's drivers, because a boot without the guard would leave every disk unlocked.
- Not proved: nothing has booted from a snapshot yet. Snapshots boot read-only, so some services may complain. `/home` and logs stay live and current.
- Open for the owner: the 5 newest can all be small changes, which pushes out milestones. Snapshot 6, the first working desktop, has already left the menu. It is still on disk.
- Open for the owner: making a past snapshot permanent has no command yet. A snapshot boot is for looking and rescuing, and `undo` cannot write to a read-only system from there.
- Cowork: the spec asks only to boot a past snapshot. Whether Stage 1 also needs a restore command is for the spec.

### 3 Nov 2026 — Claude Code, step 10 part 2, undo proved

- The owner ran the real `undo`, on change #9. It removed only the test file. The earlier changes, the mouse buttons and the log stayed as they were, and the guard still shows OK.
- This proves `undo` on one new file. Putting back a changed file, and recovering a broken desktop, are tested in part 4.
- The two fixes below are now installed.

### 3 Nov 2026 — Claude Code, step 10 part 2, not yet proven

- Added sidekick/: the rules hook, `undo`, its settings and an install script. The owner installed it by hand. The hook and rules file sit in protected places. Log: /var/log/kiln/changes.log. Home snapshots are on, and old snapshots are now cleaned up, as that timer was off.
- Proved live: a change with no explanation is refused. The owner sees the explanation in the approval question. Saying No stops the change, and the log shows it asked but not done. Each change gets before and after snapshots, which show exactly the files changed.
- Not proved: `undo` on real snapshots. Its tests use a stand-in for `snapper`. 18 tests pass.
- Two fixes are in the repo but not yet installed: `undo` skips a false alarm that changed nothing, and the guard's status check no longer asks.
- Known limits: the hook reads command text, so it asks about some commands that only read, such as ones using `$(( ))`. Refused changes leave an unused snapshot and a small file in /var/log/kiln/pending. Claude could still edit the log, as it is not a protected file. Home snapshots hold copies of the saved GitHub token, on this machine only.
- Two old test files are in ~/.config until the `undo` test clears them.
- Owner's request: the mouse's forward button copies, back pastes, and middle opens or hides the sidekick. Those buttons lose their usual jobs everywhere, including in Firefox. The owner tried them in a terminal and in Firefox, and they work.
- Cowork: the spec says "a snapshot before every change". Commits and edits inside the repo do not get one, as the repo is not the system, and `git push` is asked about but has no snapshot.

### 3 Nov 2026 — Claude Code, step 10 part 1

- Owner's decision on decision 5: the sidekick key is Super+Space. It opens Claude Code in ~/Projects/kiln, then hides and shows it, and the chat keeps running while hidden. Script: config/usr/local/bin/kiln-sidekick.
- Tested by running the script three times: the window opened, hid and came back, with Claude Code still running. The owner then pressed the real key and it works.
- Rules file: config/claude/CLAUDE.md, copied to ~/.claude/CLAUDE.md for now. A fresh session named all four rules from it. It moves to the protected folder in part 2.
- Snapshot 6 is the working desktop, taken before this part. It does not cover the home folder.
- Cowork: the spec and its Claude Doc still say pushes are by the owner's own hand. Please update them to the new rule 7.
- Cowork: decision 6 says a pop-up on first boot offers the Claude desktop app. There is no record of it being built, or of Anthropic's terms being checked. The owner wants the app at some point, so the spec needs a new place for it.

### 3 Nov 2026 — Claude Code, first desktop boot

- Kiln boots to the desktop on the mlrig kernel. Hyprland runs on the WX 3200, with the Philips at 5120x1440, 120 Hz. No failed services.
- Wired network works, so matching `en*` fixed it.
- Sound works through the Philips, and the owner heard the test tone. It defaulted to USB S/PDIF because nothing had been chosen. The owner chose the Philips, the same output as the Ubuntu baseline. See lessons/audio.md.
- Keyboard: the owner's FIELD75 uses US, so Hyprland is now `us`. The login screen and text consoles were already US.
- The hook blocked two harmless commands on Kiln, as it read text in them as paths. For the review in step 10.
- Not tested: the RTX 4090. Its driver is loaded.
- Owner decision: rule 7 changed. Claude Code now pushes to GitHub only when the owner asks, each time. The owner saved a token limited to the kiln repo on Kiln, in ~/.git-credentials. Cowork: note the new rule.

### 3 Nov 2026 — Claude Code, step 9 installed, not booted

- Owner's decisions: Hyprland stays, built from Kiln's own recipes rather than hyproverlay. Account `indy`, with sudo and no password. The rescue kernel check can wait.
- Installed from the live system: 124 packages, 102 ready-built, about 10 minutes. Results: results/desktop-2026-11-03/summary.txt. Recipes: overlay/.
- Wrote 10 recipes, for Hyprland 0.57.0, 8 libraries and Lua 5.5. hyproverlay is GPL-3 and Kiln is GPL-2, so none of its code was copied. Gentoo still masks the Hyprland names, so config/portage/package.unmask/ allows Kiln's copies only.
- Wired network: the log showed `systemd-networkd` never took the port. It now matches `en*`, not `Driver=igc`. The cause is likely but not proved. Test at boot.
- Hyprland 0.57 reads only Lua, so Omarchy's .conf files do not carry over. The first config is short, adapted from Hyprland's example. Cowork: the spec says configs borrowed from Omarchy and credited. Omarchy's files could not be fetched this session, so nothing is borrowed yet.
- Left out for now: `xdg-desktop-portal-hyprland`, needed for screen sharing, and a status bar and app launcher. Super+Return opens a terminal, Super+B opens Firefox.
- The hook blocks writes to /etc/udev/rules.d, so the WX 3200 is chosen in `kiln-session`, which looks up its current card number at login.
- The repo is copied to ~/Projects/kiln for `indy` on the Crucial. Claude Code 2.1.317 is copied from the live system. No sign-in details were copied.

### 3 Nov 2026 — Claude Code, first boot results

- mlrig kernel: 18 checks passed, 3 failed. Failed: wired link, internet, and the guard test on fake disks. Results: results/kernels-2026-11-03/summary.txt, and first-boot-6.18.60-gentoo-mlrig/ beside it, with IDs removed.
- The guard test failure is the test counting the Crucial's own writes. 31 of 32 passed, and the other disks stayed at 0 writes.
- Wired network: `systemd-networkd` ran, and its settings file is in place, but the log never shows `eno2` coming up. The same port works on the live system. Cause not found.
- Rescue kernel: not checked. There are no results for it. The login records show two boots, both the mlrig kernel, with root logged in only on the first.
- Boot order is 0000,0001,0002, with Ubuntu first. The `Kiln` entry has gone, and 0001 is `UEFI OS` on the Crucial. No session removed it. Cowork: docs/FIRST_BOOT.md tells the owner to choose Kiln.
- This session mounted the Crucial read-only and has unmounted it. All disks show 0 writes.
- Owner decision: Chromium is to be compiled for mlrig, after step 9 and once the step 11 settings are on. Not started.

### 3 Nov 2026 — Claude Code, step 8 built, not booted

- Two kernels, both 6.18.60: `6.18.60-gentoo-mlrig`, the default, and Gentoo's ready-built `6.18.60-gentoo-dist-bin`, the rescue. Boot loader `systemd-boot`. Results: results/kernels-2026-11-03/summary.txt. Kernel config: config/kernel/.
- NVIDIA 595.104.02 and `cp210x` are in, not yet tested. NVIDIA is on the mlrig kernel only, by owner's decision. Cowork: the spec's step 8 lists neither these nor the boot loader.
- The owner copied the guard to Kiln by hand, and set the root password. Checksums match the repo. The hook does nothing on Kiln until Claude Code is there in step 10.
- Firmware: added `Kiln`, not in the boot order. Removed the stale `Limine` and `UEFI OS` with the owner's approval, after proving their partitions are gone. Order is now 0000,0005.
- Other disks: all still at 0 writes and locked.
- Kernel 6.18 is Gentoo stable, by owner's decision. Ubuntu runs 7.3.0, so step 12 must record the difference. Cowork: the comparison is not purely about building for the CPU.
- Cowork: rule 1 wants a past snapshot in the boot menu. `systemd-boot` needs a menu entry written for each, and kernels on `/boot` are not in snapshots. For step 10.

### 3 Nov 2026 — Claude Code, ready-built base installed

- Installed on the Crucial by serial: 425 packages, 399 ready-built, in 28 minutes of machine time. Replaced the starter system with v3 packages, by owner's decision. Results: results/base-install-2026-11-03/summary.txt.
- Snapshot 1, base installed, is in place. `snapper` config: config/snapper/root. Hourly snapshots are off.
- Other disks: all still at 0 writes and locked. Boot order unchanged.
- 143 build tools stay on the generic starter build until step 11. Step 11 needs `--with-bdeps=y`.
- The fstab uses labels, so the public repo holds no unique IDs. config/etc/fstab.

### 3 Nov 2026 — Claude Code, step 7 trial

- Trial in memory, with `emerge --pretend`, and then deleted. No disk was touched. Results: results/base-trial-2026-11-03/summary.txt.
- Everything except Hyprland: 500 packages, 464 ready-built, 36 not, 2.6 GB to download. Of the 36, only `mesa` and `nvidia-drivers` look large. Compile times were not measured.
- The real install needs two settings not yet in config/portage/: `sys-kernel/installkernel dracut` and `media-libs/libvpx postproc`.
- The one-hour test cannot pass on this run, as planning and approvals took more than an hour. It needs a timed repeat run. Cowork and the owner to decide when.

### 3 Nov 2026 — Claude Code, build settings

- Wrote config/portage/ and config/etc/, in the repo only. No disk was written to. They go onto the Crucial in step 7.
- `-march=native`, the 21 CPU flags from `cpuid2cpuflags`, Gentoo's v3 ready-built packages, and `en_GB.UTF-8`.
- LTO and PGO are in config/portage/rebuild.conf, and turn on at step 11, by owner's decision. The Claude Doc says LTO by default. Cowork: this is a change of timing, not of the goal.
- tests/build-settings/check.py passes, including on fast and efficient cores. It read the files with Portage's parser, but the live image has no package tree, so the full Portage run comes in step 7.
- Cowork: Hyprland is not in Gentoo's main repo or GURU. The Gentoo wiki recommends the third-party `hyproverlay`. For the owner to decide at step 9.

### 3 Nov 2026 — Claude Code, disk layout

- With the owner's confirmation, wiped the Crucial by serial and laid it out: 2 GB boot partition, the rest btrfs, with sections `@`, `@home`, `@snapshots`, `@log` and `@cache`. No swap partition, by owner's decision. Exact commands: docs/DISK_LAYOUT.md.
- Read back after each change. A mount test and both filesystem checks passed.
- Other disks: write counts and lock flags did not change, and all still show 0 writes. Results: results/disk-layout-2026-11-03/.
- Boot order unchanged, with Ubuntu first. The firmware entries `Limine` and one `UEFI OS` now point at nothing. Left for the boot loader stage, with the owner's approval.
- Ubuntu may expect the Crucial at start-up. This could not be checked without opening a locked disk, and is unlikely as Omarchy was encrypted. If Ubuntu is slow to start, check this first.

### 2 Nov 2026 — Claude Code, hardware analysis

- Wrote docs/HARDWARE.md, with raw readings in results/hardware-2026-11-02/. Read-only. Drive health queries went to the Crucial only, by owner's decision.
- For step 6: `-march=raptorlake` does not match this chip. Prefer `-march=native`.
- For steps 7 and 8: the kernel warns of old microcode.
- For step 12: set the same audio output and power mode as the Ubuntu run, or the numbers will not compare.
- The RTX 4090 runs at x8, not x16, with the WX 3200 fitted. Probably the shared CPU lanes. The owner decided this does not matter, as the card is mainly for ML work.
- Owner answers, 3 Nov 2026: install the NVIDIA driver at some point. Install the `cp210x` driver, low priority, because the owner uses that adapter on Ubuntu to run GermOS on the HP. No self-test on the Crucial before the wipe.
- Owner decision, 3 Nov 2026: Ubuntu stays first in the boot order, and the owner presses F8 and chooses the Crucial to start Kiln. Kiln's boot loader must not stay first. Cowork: for the spec, Claude Doc first.
- Cowork: the spec's machine table says NVIDIA driver for compute, but no build step includes it. It needs a place, Claude Doc first. Claude Code suggests step 8, with the kernels.

### 2 Nov 2026 — Claude Code, step 3 complete

- The owner ran the installed-rule test: 32 passed, 0 failed. A new fake disk locked itself, using the rule as installed. Log: results/guard-proof-2026-11-02/installed-rule.log.
- Known gap: the hook crashing on start has not been tested live. It relies on `onFailure: block`.
- The hook sometimes blocks harmless commands, such as `which nvme`, because it reads command text. See lessons/hardware.md. Review this when the hooks are built in step 10.

### 2 Nov 2026 — Claude Code, disk guard installed

- Ran guard/install.sh with the owner's approval, and restarted Claude Code. The kernel shows every disk locked except the Crucial. No write reached any disk.
- The hook is live: it blocked zero-byte dd commands aimed at real disks, and the guard's own folder. Results are in results/guard-proof-2026-11-02/summary.txt.
- The hook also blocks Claude from running tests/guard/fake_disks.sh, so the owner runs it. Changes to the guard or its tests after this point go through the owner's hand.
- Step 5 needs care: use the /dev/disk/by-id/ path in full on every disk command, with no variables, and read the partition table back after any change. See lessons/hardware.md.

### 2 Nov 2026 — Claude Code, disk guard built and lessons file started

- Live start done: Claude Code runs on the LiveGUI image on mlrig. The repo copy of step 3 matches the Claude Doc.
- Added guard/: a kernel read-only lock, a udev rule for new disks, and a Claude Code hook. Finds the Crucial by serial. Any doubt means locked or blocked.
- Proved on fake disks in memory: results/guard-proof-2026-11-02/, with summary.txt as the short result. Real disks' write counts and lock flags did not change.
- Not yet done: install on the real system, and the real-disk checks. That is the rest of step 3.
- Limits: root can undo the lock. Raw drive commands skip the lock, so only the hook stops them, and the hook reads command text. This protects against mistakes, not deliberate attempts to get around it. The guard must be installed and proved again on the installed system, which uses systemd, not OpenRC.
- Added lessons/, the layout from decision 10.
- Other disks' serials are masked to the last 4 in the repo, by owner's decision.
- Cowork: the spec's step 10 adds hooks for the four rules. The disk guard hook already exists, so those need to sit alongside it.

### 2 Nov 2026 — Claude Code, baseline run and kickoff checks

- Ubuntu main run done, in results/ubuntu-26.10-2026-11-02/: smallest clean audio buffer 256 samples, wake-up delay 99.9% at 0.99 ms, sysbench 39,181 and 7-Zip 210,923 on 32 threads.
- Boot: 1 of 5 saved. The owner decided the rest can wait, because Kiln is the priority.
- For the comparison: use the 99.9% wake-up figure, in responsiveness.csv. The median is mostly the kernel's fixed 0.05 ms timer slack.
- Kickoff check: Gentoo offers ready-built packages at x86-64-v3 (23.0/x86-64-v3, updated 2 Nov 2026). The i9-13900K supports v3 but not v4, so v3 is the right level.
- Live image: livegui-amd64-20260913T163055Z.iso, the newest offered. Downloaded to the Ventoy drive with the owner's approval. Checksum matches, and the checksum file is signed by Gentoo's weekly release key.
- Added docs/LIVE_START.md, so the owner can copy the steps in Firefox on the live desktop.

### 2 Nov 2026 — Claude Code, measurement script

- Added scripts/measure.sh. Modes: `run`, `boot`, `new`. `--short` is a quick test, kept out of git.
- Results go to results/<os>-<date>/, with summary.txt as the short result.
- run-bench.sh was not found on any mounted drive. The owner chose fresh settings: sysbench CPU test, 30 seconds, and 7-Zip benchmark at 32 MB, each on 1 and on all threads, median of 3. Cowork: the spec still calls it the existing script and warns about its test files, so it needs updating, Claude Doc first.
- Short test passed. Audio dropouts appeared at buffer 64 under compile load, but not at any size down to 32 with no load. Freezing the test playback for 1 second was counted as dropouts. These were short runs, not results.
- Kiln needs a login screen that reaches graphical.target and the same audio output, for a fair comparison.

### 2 Nov 2026 — Cowork, owner answers

- Baseline: skip Omarchy. Compare Kiln with Ubuntu 26.10 on mlrig only.
- Decision 10, the lessons file layout, accepted.
- Repo docs stay concise. Added as a standing rule in CLAUDE.md.

### 2 Nov 2026 — Cowork, spec fixes

- Owner: Omarchy's contents are copied, so the Crucial drive is free to wipe. The cooling-off period is over.
- Owner decided: the screen uses mini DisplayPort from the WX 3200, not HDMI. The WX 3200 has only mini DisplayPort sockets. HDMI into the RTX 4090 is the fallback for a black screen on a live image.
- Fixed the WX 3200 date: fitted on 24 Oct 2026, not 26 Oct.
- Added the lessons file to the spec, as a new section and as decision 10, waiting for the owner.
- Changed in the Claude Doc first, then in docs/STAGE1_SPEC.md.

### 23 Oct 2026 — Cowork, owner idea: lessons file

- Owner's idea: the first time Claude is active during the install, it creates a lessons-learnt file that stays in the installed system. It records findings and pitfalls with the hardware and software, in logical sections, so Claude can later read only the section it needs when building or troubleshooting.
- Cowork's suggestion, for the owner to confirm: a short index file (the system's CLAUDE.md) that points to one file per section, such as hardware, build settings and failed packages, kernel, boot, desktop, audio and network. Claude Code reads CLAUDE.md in full every session, so it must stay short. A copy goes into the repo, so the install can be repeated.
- To do next Cowork session: add it to the Stage 1 spec, Claude Doc first, then the repo copy.

### 23 Oct 2026 — Cowork, baseline plan

- The owner chose: results on a USB stick, 5 boots per system with the median, and Ubuntu measured as a second reference.
- First step is a look-only survey of Omarchy. The fair way to remove the passphrase wait depends on whether Omarchy unlocks the drive inside systemd, so it is decided after the survey.
- In this session the mlrig file tools worked, and Cowork wrote to the repo directly.

### 23 Oct 2026 — Cowork, owner decisions

- The owner decided all nine Stage 1 decisions. Recorded in the Claude Doc and in docs/STAGE1_SPEC.md.
- Decision 1 gained one point: Stage 1 boots Gentoo's LiveGUI image, so the Claude sign-in happens in Firefox on mlrig itself. Live start step 2 updated to match.
- Decision 6 was changed by the owner: on the first boot after install, a pop-up offers to install the Claude desktop app, so Cowork can run on Kiln. Kiln needs its own recipe for it. Check at kickoff that it works and that Anthropic's terms allow it.
- In this Cowork session the folder was connected, but the file tools for mlrig never loaded. Files went across as one archive instead. Try a fresh Cowork session next time.

### 23 Oct 2026 — Cowork, repo set-up

- Created README.md, LICENSE (GPL-2), CLAUDE.md, HANDOVER.md.
- Copied the two Claude Docs into docs/VISION.md and docs/STAGE1_SPEC.md.
- Added an Answer column to the owner decisions table in docs/STAGE1_SPEC.md.
- The owner created the public GitHub repo IndyWH/kiln and pushed the first commit (2707f87).
