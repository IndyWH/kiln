---
name: login-screen-to-improve
description: "The owner finds Kiln's tuigreet login appalling; decided 6 Nov 2026 to do it Omarchy style (autologin into hyprlock) in the next session"
metadata:
  node_type: memory
  type: project
  modified: 2026-11-06T07:42:27.991Z
---

On 3 Nov 2026 the owner called the login screen "appalling" and laughed. It is `tuigreet`, a plain text login, set in /etc/greetd/config.toml.

Decision, 6 Nov 2026: do it in the next session, Omarchy style. Omarchy logs in automatically after a disk password on a styled Plymouth splash, with `hyprlock` as the lock screen. Kiln's disk is not encrypted, so the plan is automatic login straight into a locked `hyprlock` screen. `hyprlock` is not in ::gentoo, so it needs a Kiln overlay package. Recorded in HANDOVER.md, Current state.

**Why:** a new greeter cannot be tested without logging the owner out (restarting greetd ends the session), so not on a day the owner has to leave.
**How to apply:** start it when the owner has time to log out and test. greetd's `initial_session` can do the autologin, with tuigreet kept as `default_session` after logout as a fallback.

**Update, 13 Nov 2026:** Kiln moved to CachyOS. The decision stands, Omarchy style, but `hyprlock` is an ordinary package there, so no recipe is needed, and Claude no longer asks before changing it. Still do it when the owner can log out to test.
