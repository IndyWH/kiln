# Desktop

Hyprland, graphics and the screen.

- The screen is on mini DisplayPort from the WX 3200, which has only mini DisplayPort sockets. HDMI into the RTX 4090 is the fallback if a live image shows a black screen.
- Kiln needs a login screen that reaches graphical.target, for a fair boot comparison with Ubuntu.
- Card numbers and connector names change. Ubuntu called the screen `card2-DP-7`, and the live system `card0-DP-4`, on the same WX 3200. Choose the card by PCI address 02:00.0.
- The firmware starts on the WX 3200. The screen runs 5120x1440 at 120 Hz through it.
- The RTX 4090 runs at x8, not x16, with both cards fitted. The owner decided this does not matter, as the card is mainly for ML work.
- Hyprland 0.57 reads only Lua config, in `~/.config/hypr/hyprland.lua`, and needs Lua 5.5. Gentoo stops at 5.4. Check a config with `Hyprland --verify-config --config <file>`. It works in a chroot.
- Gentoo still masks the Hyprland names after moving them out of its main repo, so a separate repo needs `package.unmask` lines ending in `::kiln`.
- In Hyprland 0.57, `hyprctl dispatch` takes Lua, such as `hyprctl dispatch 'hl.dsp.workspace.toggle_special("sidekick")'`. A window with the rule `workspace = "special:sidekick"` opens with that workspace showing.
- Mouse copy and paste: `hl.bind` takes a Lua function, and `hl.dsp.send_shortcut({ mods, key })` works with `hl.dispatch`. Check `hl.get_active_window().class`, and send Ctrl+Shift in a terminal, because Ctrl+C there stops what is running. Forward is `mouse:276`, back is `mouse:275`, middle is `mouse:274`. Hyprland's Lua definitions are in `/usr/share/hypr/stubs/hl.meta.lua`.
- Omarchy 4.0 writes its Hyprland settings in Lua, in `default/hypr/`, so they run on Hyprland 0.57 here. Most of its bindings call `omarchy-*` scripts or its Quickshell shell, so those cannot be copied alone. `send_shortcut` can leave a key stuck, so Omarchy sends `send_key_state` down, then up 50 ms later.
- Custom window layout: write it with `hl.layout.register("kiln", { recalculate = ... })`, and set `general.layout = "lua:kiln"`. The `lua:` prefix is needed. Without it Hyprland falls back to dwindle with no error, and `getoption` still shows the name. Test by opening windows on an empty workspace, as `hl.dsp.exec_cmd("foot", { workspace = "9 silent" })`, and reading `hyprctl -j clients`.
- The shortcuts on the desktop are one image, shown by `swaybg`. After changing a key, edit and run `config/desktop/make-shortcuts.py`, then copy the image to `~/.local/share/kiln/`.
- `AQ_DRM_DEVICES` is split by colons, so it cannot take a by-path card name, which has colons in it. `kiln-session` resolves the name to `/dev/dri/cardN` first.
