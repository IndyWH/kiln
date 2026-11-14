# Installing Kiln v2

CachyOS goes on the Crucial P2 and replaces Kiln v1. One part at a time; report back after each.

## Part 1: Claude gets and checks CachyOS (on the current system)

Claude Code downloads the newest CachyOS desktop ISO with its `.sha256` and `.sig` files, and checks both: the checksum, and the signature against CachyOS's key (fingerprint ending 8DB35A47, as on wiki.cachyos.org). Claude then gives the owner the ISO's name and its SHA-256.

## Part 2: The USB stick (owner, on another computer)

The disk guard locks every disk except the P2, a USB stick included, so the stick cannot be made on mlrig. That is the guard working.

On another computer, with a USB stick of 8 GB or more, whose contents will be lost:

1. Download the same ISO from cachyos.org.
2. Check it matches the SHA-256 Claude gave:
   - Windows, in PowerShell: `certUtil -hashfile` followed by the ISO's name, then `SHA256`.
   - Mac, in Terminal: `shasum -a 256` followed by the ISO's name.
3. Write it to the stick with balenaEtcher, or with Rufus in DD image mode.

## Part 3: Before installing (owner, at mlrig)

- Make sure everything wanted from the P2 is on GitHub. Claude checks this in Part 1.
- Optional but safest: unplug the two SATA disks, the WD 2 TB and the Samsung 870 QVO. The installer then cannot show them.
- Plug in the stick and a network cable.

## Part 4: Install (owner)

1. Start mlrig and press **F8** for the ASUS boot menu. Choose the USB stick's UEFI entry. If it will not start, check that Secure Boot is off in the BIOS. If the screen stays black, move the screen's cable to HDMI on the RTX 4090.
2. The live desktop opens with CachyOS Hello. Choose **Launch Installer**.
3. Choose these:

| Setting | Choose | Why |
|---|---|---|
| Location | Europe/London, English (UK) | |
| Keyboard | as used now, US | Matches the v1 settings |
| Boot loader | **Limine**, the default | Shows snapshots in the boot menu, so a bad change can be undone at start-up |
| Disk | **Erase disk** on **CT1000P2SSD8** | Choose by this model name, never by size: the Samsung 870 QVO is also 931.5 GB |
| File system | **btrfs**, the default | Needed for snapshots |
| Swap | the default | |
| Encryption | owner's choice; Claude suggests off | Off: starts without a password and is simpler to rescue. On: protects the data if the machine is stolen |
| Desktop | **Hyprland** | Claude adds the Omarchy look later |
| Packages | the defaults | |
| User | `indy`, with a password; tick using the same password for the administrator | Claude Code expects `indy` |

4. Check the summary page shows **CT1000P2SSD8** and no other disk. Then install.
5. When it finishes, remove the stick and restart.

## Part 5: First start (owner, then Claude)

1. Log in. Open a terminal; the key combination is on CachyOS's welcome screen.
2. Install Claude Code, fetch Kiln and start Claude Code:

```
curl -fsSL https://claude.ai/install.sh | bash
git clone -b v2 https://github.com/IndyWH/kiln.git ~/Projects/kiln
cd ~/Projects/kiln && ~/.local/bin/claude
```

3. Sign in when asked, then type:

```
First start of Kiln v2. Read HANDOVER.md and take over.
```

From here Claude Code takes over, in this order: its memory notes from claude-memory/, the disk guard, then automatic snapshots and `undo`, the rescue entry, the new machine rules in policy/CLAUDE.md, then NVIDIA, the Hyprland look, and a measured baseline. Plug the SATA disks back in only after the guard is installed.

### Blocking bad sites (DNS)

Claude asks the owner at first start: does this network already block malware and phishing sites, with a router such as OPNsense or a Pi-hole?

- **Yes:** the machine uses the network's DNS. `config/kiln/dns-filtering` says `network`. Do not also set a public service on the machine: it would skip the router's blocking.
- **No, or not sure, or a laptop that moves:** `filter-here`. Install `config/systemd/resolved-kiln-quad9.conf` as `/etc/systemd/resolved.conf.d/kiln-quad9.conf` (Quad9, encrypted) and restart systemd-resolved.

Either way: `config/kiln/dns-filtering` to `/etc/kiln/dns-filtering`, and `config/firefox/policies.json` to `/etc/firefox/policies/policies.json`, so Firefox uses the system's DNS instead of its own. The sentry reports if the DNS stops matching the choice.

mlrig: `network` (OPNsense), 14 Nov 2026.

