---
name: kiln-cachyos-superuser
description: "Owner's 13 Nov 2026 decision - Kiln moves to a CachyOS base, Claude Code as superuser that informs rather than asks"
metadata:
  node_type: memory
  type: project
  modified: 2026-11-13T14:39:12.889Z
---

On 13 Nov 2026 the owner decided Kiln will be rebuilt on CachyOS (Arch-based), not Gentoo, after the CPU setting test showed `native` gives nothing over ready-built `x86-64-v3` on mlrig. New philosophy: Claude Code is the superuser with sudo, acts without asking for approval, and keeps the owner informed. The owner says they hardly read the approval prompts, so they protected nothing.

**Why:** approval prompts the owner does not read are theatre; safety should come from snapshots, hard limits in code and a readable log.

**How to apply:** Until the owner installs the new policy, the current Gentoo machine's /etc/claude-code/CLAUDE.md rules (ask before changes) still bind. Proposed safety model for the new Kiln: automatic snapshot before every change; hard code limits (other disks via the disk guard, owner's personal files, snapshots/rescue path); still ask for irreversible outward actions (push, email, posting, spending); AUR build scripts read and logged before install. Done 13 Nov: fresh orphan branch `v2` pushed (worktree ~/Projects/kiln-v2) with docs/DECISION-cachyos.md, docs/PHILOSOPHY.md, policy/CLAUDE.md and HANDOVER.md listing the install steps. The owner agreed the Crucial P2 may be wiped for a fresh CachyOS install. See [[kiln-project]].
