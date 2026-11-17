# Kiln lessons: index

What Claude has learnt about this machine. Lessons from v1, on Gentoo, are marked by date; check them on CachyOS before relying on them. The build, kernel and boot lessons stayed on the `stage1-guards` branch. Read only the section you need. Add a finding when it is learnt: what happened, why, what worked. Keep this index short.

The first line of each section says what it holds.

| Section | Read it when |
|---|---|
| [hardware](hardware.md) | Touching disks or other hardware, or using the disk guard |
| [desktop](desktop.md) | Working on Hyprland, graphics or the screen |
| [audio](audio.md) | Working on PipeWire or sound |
| [network](network.md) | Working on the network |
| [packages](packages.md) | Installing or building packages, repos, CPU level |
| [speed](speed.md) | Measuring speed, benchmarks, kernel memory settings |
| [agents](agents.md) | Helper agents, the watcher, the sentry, the rules hook's locks |
| [snapshots](snapshots.md) | Snapshot limits, the boot menu's snapshot entries, `undo` and `restore` |
| [secrets](secrets.md) | Anything near keys, the keyring, browser profiles or saved logins; a refusal from the secrets rule |
| [browsers](browsers.md) | Chrome, Firefox, Claude Desktop, their graphics card and DNS |

Never put another disk's full serial number here. This folder is copied to a public repo, so show the last 4 characters only.
