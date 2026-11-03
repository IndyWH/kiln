# mlrig hardware report

Read on 2 Nov 2026 from the Gentoo LiveGUI image, read-only, with the disk guard on. Raw readings, with serials and addresses removed, are in [results/hardware-2026-11-02](../results/hardware-2026-11-02/). Device names such as `nvme1n1` are for that boot only.

## What this means for the build

| Step | Finding | What to do |
|---|---|---|
| 6, build settings | `-march=raptorlake` turns on `kl`, `widekl` and `sgx`, which this chip does not report, and leaves out `abm` and `shstk`, which it does. `-march=native` matches the chip | Prefer `-march=native`, or the settings it resolves to. Do not use `-march=raptorlake` |
| 6, build settings | No AVX-512. The chip has AVX2 and AVX-VNNI | x86-64-v3 is the right level for ready-built packages |
| 7 and 8, microcode | The kernel warns `Running old microcode`, at revision 0x12f. It comes from the BIOS, and this live image has no microcode file for the chip | Install Gentoo's microcode package, then check the warning has gone |
| 8, kernel | The fast and efficient cores differ a lot, and the chip reports `hfi`, its hints for placing work | Keep the Intel hybrid scheduling support on |
| 9, desktop | The card numbers changed: Ubuntu called the screen `card2-DP-7`, and here it is `card0-DP-4`, on the same WX 3200 | Choose the card by its PCI address, 02:00.0, never by number |
| 12, measuring | Ubuntu's audio test used the WX 3200's output. The live system defaults to USB audio | Measure through `alsa_output.pci-0000_02_00.1.hdmi-stereo-extra1`, or the numbers will not compare |
| 12, measuring | Ubuntu ran in performance power mode. The live system runs `powersave` with `balance_performance` | Set the same power mode before measuring |

## CPU and memory

- **CPU:** Intel i9-13900K. 24 cores and 32 threads, with 36 MB of shared cache.
- **Fast cores:** 8, as threads 0 to 15. They reach 5.5 GHz, and two of them (threads 8 to 11) reach 5.8 GHz.
- **Efficient cores:** 16, as threads 16 to 31. They reach 4.3 GHz.
- **Memory:** 96 GB, two 48 GB Corsair DDR5 sticks, running at 6400 MT/s. That is 3 GB for each thread when building.
- **Board:** ASUS ROG MAXIMUS Z790 APEX, BIOS 3107 (1 Dec 2025). The system starts in UEFI mode.
- **Compiler here:** GCC 15.3.0. It reports this chip as `alderlake`.

## Graphics

| Card | PCI address | Driver here | Link now | Link at most |
|---|---|---|---|---|
| Radeon Pro WX 3200 | 02:00.0 | `amdgpu` | 8 GT/s x8 | 8 GT/s x8 |
| RTX 4090 | 01:00.0 | `nouveau` | 2.5 GT/s x8, idle | 16 GT/s x16 |

- The firmware starts on the WX 3200, as decision 4 wants. The screen is on its fourth DisplayPort.
- **Screen:** Philips 49M2C8900L at 5120x1440. It offers 120, 75 and 60 Hz through this card, and runs at 120 Hz. Variable refresh and HDR are off.
- **The RTX 4090 is using 8 lanes, not 16.** The two cards share the CPU's lanes, which probably explains it, because each sits on its own branch of the same port. The owner decided this does not matter, as the card is mainly for ML work (3 Nov 2026). The low 2.5 GT/s is normal when idle.
- The live system uses `nouveau`, so compute details cannot be read until the NVIDIA driver goes in. The owner wants that driver installed.

## Audio

- **Outputs:** the onboard ASUS USB audio (speakers, headphones and digital), and sound over DisplayPort from the WX 3200 to the screen. The RTX 4090 also has outputs, but no screen is on them.
- **Inputs:** the onboard USB audio and a Logitech C615 webcam.
- **Software here:** PipeWire 1.6.8 at 48 kHz.

## Network

- **Wired:** Intel I226-V, driver `igc`, connected at 1 Gb/s. This is what the install uses.
- **Wi-Fi:** Intel AX211 built into the chipset, driver `iwlwifi`, not in use.
- **Bluetooth:** Intel AX211, driver `btusb`.

## Storage

| Disk | Size | Connection | Holds | Stage 1 |
|---|---|---|---|---|
| Crucial P2 | 1 TB | PCIe 3.0 x4, through the chipset | Omarchy, to be wiped | **Install target** |
| Samsung 990 PRO | 2 TB | PCIe 4.0 x4, on the CPU's lanes | Probably Ubuntu, from its partitions | Locked |
| Samsung 990 PRO | 2 TB | PCIe 4.0 x4, through the chipset | `fastdata` | Locked |
| Samsung 870 QVO | 1 TB | SATA | `4Ubuntu` | Locked |
| WD 2 TB | 2 TB | SATA, spinning disk | `DataHDD` | Locked |
| Seagate 500 GB | 500 GB | USB, through a SATA bridge | Ventoy, running this system | Locked |

**The Crucial's health is good.** Health check passed, 2% of its rated life used, 13.4 TB written, 8,977 hours on, 37°C, and no media errors.

- It logged 4,114 error entries. The two shown are both `Invalid Field in Command`, which is usually software asking for something the drive does not support, not damage. The other entries were not read.
- It has had 149 unsafe shutdowns. Its last self-test was at 5,096 hours, and that one was aborted. The owner chose to wipe it without another self-test (3 Nov 2026).
- It has no memory cache of its own and uses a slower link than the Ubuntu drive. So its disk speed will not compare fairly, which the spec already allows for.

Health data was read from the Crucial only, as the owner decided. The other disks have no health report.

## Kernel needs

| Hardware | Driver |
|---|---|
| Crucial and other NVMe disks | `nvme` |
| SATA disks | `ahci` |
| USB, and USB disks | `xhci_hcd`, `usb_storage`, `uas` |
| WX 3200 | `amdgpu`, with `amdgpu/polaris12_*` firmware |
| RTX 4090 | NVIDIA's own driver |
| Silicon Labs CP210x USB serial adapter | `cp210x`. The owner uses it on Ubuntu to run GermOS on the HP. Wanted, but not a priority |
| Sound | `snd_hda_intel`, `snd_usb_audio` |
| Wired, Wi-Fi, Bluetooth | `igc`, `iwlmvm` with `iwlwifi-so-a0-gf-a0-89` firmware, `btusb` with `intel/ibt-1040-0041` firmware |
| Board | `i2c_i801`, `intel_lpss_pci`, `mei_me`, `spi_intel_pci`, `intel_vsec`, `coretemp`, `spd5118`, `asus_wmi`, `asus_armoury` |
| Input | `hid_logitech_dj`, `hid_logitech_hidpp`. The NuPhy keyboard uses the standard USB drivers |

The list of every module loaded here is in `modules.txt`. It is a starting point for step 8, because some will not be needed.

## Not looked into

- Kernel errors, once each at start-up: an ACPI timeout on a PCIe graphics port (`PEG1`), and a device that failed to register (`ITE8853`). Nothing seems broken so far.
- `sensors` shows no motherboard fans or voltages, so that driver is probably not loaded.
- Whether the screen can go above 120 Hz on this card or another.
- The Corsair H150i cooler and ASUS AURA lights are connected, but nothing here controls them.
