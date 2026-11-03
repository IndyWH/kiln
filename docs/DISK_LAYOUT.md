# Disk layout

Spec step 5, done on 3 Nov 2026 with the owner's approval. The Crucial is named by serial in every command. Results are in [results/disk-layout-2026-11-03](../results/disk-layout-2026-11-03/).

These commands destroy everything on the Crucial. Run the guard first, with `sudo guard/install.sh`. Check each result by reading it back, because `sgdisk` can report success when nothing happened.

| Partition | Size | Format | Label | Use |
|---|---|---|---|---|
| 1 | 2 GB | FAT32 | `KILNBOOT` | Boot partition |
| 2 | 929.5 GB | btrfs | `KILN-ROOT` | Everything else |

| Section | Mounted at | In system snapshots? |
|---|---|---|
| `@` | `/` | Yes |
| `@home` | `/home` | No |
| `@snapshots` | `/.snapshots` | No |
| `@log` | `/var/log` | No |
| `@cache` | `/var/cache` | No |

No swap partition, by the owner's decision. There is no disk encryption (decision 3). Mount options for btrfs: `noatime,compress=zstd:1`. Btrfs adds `ssd` and `discard=async` by itself on this drive.

## Wipe and partition

```bash
sudo wipefs -a /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part1 /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2
sudo sgdisk --zap-all /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC
sudo blkdiscard -f /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC
sudo sgdisk --new=1:0:+2G --typecode=1:ef00 --change-name=1:KILN-BOOT --new=2:0:0 --typecode=2:8304 --change-name=2:KILN-ROOT /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC
sudo sgdisk --print /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC
```

## Format and create the sections

```bash
sudo mkfs.vfat -F 32 -n KILNBOOT /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part1
sudo mkfs.btrfs -L KILN-ROOT /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2
sudo mount -o noatime,compress=zstd:1 /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2 /mnt/gentoo
sudo btrfs subvolume create /mnt/gentoo/@
sudo btrfs subvolume create /mnt/gentoo/@home
sudo btrfs subvolume create /mnt/gentoo/@snapshots
sudo btrfs subvolume create /mnt/gentoo/@log
sudo btrfs subvolume create /mnt/gentoo/@cache
sudo umount /mnt/gentoo
```

## Mount for the install

```bash
sudo mount -o noatime,compress=zstd:1,subvol=@ /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2 /mnt/gentoo
sudo mkdir -p /mnt/gentoo/home /mnt/gentoo/.snapshots /mnt/gentoo/var/log /mnt/gentoo/var/cache /mnt/gentoo/boot
sudo mount -o noatime,compress=zstd:1,subvol=@home /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2 /mnt/gentoo/home
sudo mount -o noatime,compress=zstd:1,subvol=@snapshots /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2 /mnt/gentoo/.snapshots
sudo mount -o noatime,compress=zstd:1,subvol=@log /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2 /mnt/gentoo/var/log
sudo mount -o noatime,compress=zstd:1,subvol=@cache /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2 /mnt/gentoo/var/cache
sudo mount /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part1 /mnt/gentoo/boot
```

The Crucial is left unmounted after step 5. Later steps mount it with this block.

The snapshot tool goes in with the base system. The `@snapshots` section is ready for it.
