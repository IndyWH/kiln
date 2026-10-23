# Vision: a Gentoo-based distro with Claude as sidekick

23 Oct 2026 · Herath Herath

Copied from the Claude Doc, which is the source of truth: https://claude.ai/artifact/LKdCA8eLpUT27X5B6A9Ds1

## The problem

Most Linux distributions are built to run on almost any computer. That makes them safe, but it means they are not tuned for the computer they are actually running on.

CPU support is a clear example. Distributions build for broad levels such as x86-64-v2, v3 or v4. Each level covers many processors, so the software cannot use everything a particular CPU offers.

The same is true of the kernel, the audio stack and the start-up services. They are set up for the average machine, not yours.

Gentoo Linux already solves this. It builds every program from source, with settings for the machine it runs on. But Gentoo is hard to install and hard to maintain. Most people who would benefit from it never try.

## The idea

The heart of the project is the sidekick: Claude, built into a Gentoo-based system, doing work that normally takes years of Linux experience. The installer studies the hardware, then installs and tunes a system made for that one machine. After install, the user looks after the system by chatting with Claude Code in the terminal. There is no software store and no settings maze. The result is still an ordinary Gentoo system underneath.

The name is Kiln Linux, Kiln for short. A kiln is where things are fired, and each machine's programs are fired for that machine.

## The sidekick

The sidekick is what makes this distribution different. To the user it feels like magic. Underneath, every step is ordinary Gentoo work done well.

A real example. On Omarchy, a Hyprland desktop, the author asked Claude: make the mouse cursor a little bit bigger, and make its outline amber instead of white. Claude found the right settings, edited the file and reloaded it. No manual, no forum search, no knowledge of where Hyprland keeps its cursor settings. That is the experience this distribution aims to give for the whole system.

What the sidekick does:

- Studies the hardware and works out the best build for it.
- Builds and tunes the whole system for that one machine.
- Installs, updates and removes software when the user asks in plain words.
- Finds and fixes problems, such as no sound, a slow boot or a driver that will not load.
- Measures the machine before and after each change, and shows the numbers.
- Explains what it did and why, so the user learns as they go.

The magic is never a mystery. Every change is explained first and can be undone in one step.

## Who it is for

People who like Linux, are frustrated with generic distributions, and want their machine to run as well as it can. They do not need deep Linux knowledge. They want an AI sidekick to do the tuning and explain it in plain words.

It is a public, open-source project.

## What the user experiences

1. The ISO boots into a simple graphical screen.
2. The user signs in to their Claude account.
3. Claude analyses the hardware: CPU, graphics, audio, storage, network.
4. Claude explains what it plans to install and why, in plain words. The user agrees.
5. Claude installs ready-built packages first, so the machine is usable within about an hour.
6. The machine boots into a Wayland-only Hyprland desktop, inspired by Omarchy. Only the bare minimum of apps and libraries are installed.
7. In the background, Claude rebuilds every program for this exact CPU, starting with the parts that gain most: kernel, graphics and audio. The user is told this can take a long time and the computer should stay on.
8. From then on, the user installs and updates software by chatting with Claude Code in the terminal. One key switches between Claude Code and the normal shell. That key cannot be Tab, which the shell already uses.

## Four rules from day one

The user cannot judge what Claude is doing, so these safety rules are the core of the product.

1. **Nothing leaves the machine unbootable.** A snapshot is taken before every change. A known-good kernel always stays in the boot menu. The last change can be undone in one step.
2. **Claude explains before it acts.** Every change comes with a short plain-English line, and the user says yes first.
3. **Usable in an hour, optimised later.** Ready-built packages go in first. Rebuilds run in the background while the machine is in use.
4. **Show the gain.** Boot time, input lag and audio latency are measured before and after tuning, and the numbers are shown to the user.

One more principle sits under all four. Claude only changes Gentoo's own settings files. If Claude is offline or gone, the system is still a normal, working Gentoo machine.

## Where the speed really comes from

Two things make the machine fast: building every program for its exact CPU, and setting the system up for desktop use. Both are core to the project.

Every new Intel or AMD processor brings new instructions and features. We use them wherever the compiler can, even when the gain is only a few per cent. A machine should run code built for the processor it has, not for an average processor from years ago.

| Goal | Main lever |
|---|---|
| Fast boot | A kernel with only this machine's drivers, a small boot image, few start-up services |
| Responsive desktop | Kernel scheduler and preemption settings for desktop use |
| Low audio latency | PipeWire buffer sizes and a low-latency kernel |
| CPU-specific speed | Every program built for this exact CPU and its newest features, with the best compiler and techniques each package supports, such as link-time and profile-guided optimisation |

Claude does both. It tunes the configuration, and it rebuilds the whole system so every program uses the CPU's full feature set.

On choosing sources: there is rarely a Rust and a C version of the same program. The real choice is between different programs that do the same job. Claude makes that choice one program at a time, by what works best on the machine, not by language.

## What it builds on, and the licences

| Part | Licence or rule | What it means for us |
|---|---|---|
| Gentoo package recipes and Portage | GPL | We can reuse and extend them in our own overlay |
| Gentoo name | Trademark of the Gentoo Foundation | We may say "based on Gentoo" without implying endorsement; the name cannot be in our product name |
| Claude name | Anthropic trademark | Not in our name without Anthropic's permission |
| Claude Code | Not open source | Not bundled in the ISO; downloaded through the official route at install; each user needs their own Claude plan |
| Hyprland | BSD licence | Free to use |
| Omarchy configs | MIT licence | Free to borrow, with credit |

The ISO holds only the installer. Programs are built on the user's own machine, so we are not distributing those binaries. That keeps licence compliance simple.

Source: [Gentoo name and logo usage guidelines](https://www.gentoo.org/main/en/name-logo.xml)

## Risks and open questions

- **Cost.** Every user needs a paid Claude plan. That is a real barrier for a public project.
- **Dependence on one company.** If Anthropic's terms change, the distribution stalls. The sidekick should be a slot that other models can fill, including a local model.
- **Anthropic's terms.** A public product built around Claude Code and consumer subscriptions needs checking against Anthropic's current terms before heavy investment.
- **Claude can be wrong.** The user may not spot a bad change. The four rules are the answer to this, so they must be tested hardest.
- **Newest CPU features can break builds.** Aggressive settings sometimes expose compiler bugs or make a program crash. Claude keeps a safer fallback setting for any package that fails, and records why.
- **Built for one CPU means tied to one CPU.** A disk moved to a different machine may not run. The user is told this, and a generic rescue kernel stays available.
- **Comparison with CachyOS.** CachyOS already ships CPU-tuned packages and kernels. We must show our per-machine approach measurably beats it, or say honestly where it does not.
- **Name.** Kiln Linux is free as a distribution name, but the command name kiln is already used by a static site generator.

## First step, and what success looks like

The first step is a personal prototype on one spare machine, with the four rules built in from the start. Once that works, it becomes the public version.

Success means three things:

- Someone with no deep Linux knowledge installs it and uses it daily without help beyond Claude.
- The measured boot time, input lag and audio latency beat a stock install of a mainstream distribution on the same machine.
- No user ever ends up with a machine that will not boot.
