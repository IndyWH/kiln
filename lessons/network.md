# Network

The network on the live and installed systems.

- Wired network comes up by itself on the Gentoo LiveGUI image.
- The wired card is an Intel I226-V, driver `igc`, at 1 Gb/s. It was `eno2` on the live system. Wi-Fi and Bluetooth are an Intel AX211, not in use.
- First boot, 3 Nov 2026: on Kiln, `systemd-networkd` ran, but the log never shows `eno2` coming up, on the same port that works on the live system. `config/etc/systemd/network/20-wired.network` is in place. Cause not found yet. The live image has no `journalctl`, so check from Kiln itself.
