# First boot

Spec step 8, part 4. Restarting wipes the live system and its Claude Code chat, so use this page from your phone or another device.

There is no desktop yet. A text login screen is what success looks like.

## 1. Boot the mlrig kernel

1. Leave the Silicon Labs USB serial adapter plugged in. The check looks for it.
2. Restart from the live desktop.
3. Keep pressing F8 as the machine starts, and choose `Kiln`. If it is not listed, choose the `UEFI OS` entry that names the Crucial (`CT1000P2SSD8`).
4. A menu shows for 3 seconds. Leave it, and it starts the mlrig kernel. The kernel's name ends in `mlrig`.
5. At the login prompt, log in as `root`, with the password you set.
6. Run this. It takes a few minutes at most, and prints PASS or FAIL for each check:

```bash
kiln-first-boot-check
```

7. Note any FAIL. It is not an emergency, because the results are saved on the Crucial.
8. Restart with this:

```bash
systemctl reboot
```

## 2. Boot the rescue kernel

1. Press F8 again and choose Kiln the same way.
2. In the 3-second menu, press the down arrow to stop the countdown, and choose the entry ending in `gentoo-dist-bin`. Press Enter.
3. Log in as `root`, and run `kiln-first-boot-check` again. This kernel has no NVIDIA driver, so it skips that check.
4. Run `systemctl reboot`.

## 3. Back to the live system

1. Press F8 and choose the Ventoy drive. It shows as `UEFI OS`, and it is the USB drive.
2. Start Gentoo's LiveGUI image, then follow sections 1 and 2 of [LIVE_START.md](LIVE_START.md) to install Claude Code and sign in.
3. New session, on Opus 5.5 at high effort. Paste this:

```text
You are running on the Gentoo LiveGUI image on mlrig, for Kiln Linux Stage 1.
1. Clone https://github.com/IndyWH/kiln.git into ~/Projects/kiln, branch stage1-guards. Install git first if it is missing. Set the repo's git identity to Herath M W I Herath, wajirah@hotmail.com.
2. Read CLAUDE.md, HANDOVER.md and docs/STAGE1_SPEC.md. Follow the standing rules.
3. Install the guard with sudo guard/install.sh. Tell me when to restart Claude Code, then stop.
4. After the restart, do step 8 part 4. Mount the Crucial by serial, serial 2128E5B7DBBC. Read /var/log/kiln-first-boot/ for both kernels, remove any IDs, and copy the results to results/kernels-2026-11-03/. Check that Ubuntu is still first in the boot order. Write only to the Crucial, and touch no other disk.
5. Record in HANDOVER.md that the owner wants Chromium compiled for mlrig, after step 9 and once the step 11 settings are on. Do not start it.
6. Report what passed and failed, in plain words. Commit, then stop so I can push.
```

## If something goes wrong

| What you see | What to do |
|---|---|
| `Kiln` and `UEFI OS` for the Crucial are both missing from F8 | Start the live system, and tell Claude what F8 listed |
| Black screen or a freeze on the mlrig kernel | Hold the power button, press F8, choose Kiln, then try the rescue kernel |
| Both kernels fail | Start the live system, and tell Claude where each one stopped. A photo of the screen helps |
| You want your normal system | Restart without pressing F8. Ubuntu starts, and is untouched |
