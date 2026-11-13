-- Kiln Linux, mlrig: ~/.config/hypr/hyprland.lua
-- The look, animations, window rules, input feel and key bindings are adapted from
-- Omarchy 4.0 alpha (commit ae64a4b), by David Heinemeier Hansson. MIT licence, in
-- OMARCHY-LICENSE beside this file. Omarchy's colours are its Tokyo Night theme.
-- Left out for now: anything needing Omarchy's shell or its omarchy-* scripts.
-- Kiln's own: the screen, the keyboard layout, the sidekick, the mouse buttons, no
-- gaps, the window layout and the shortcuts shown on the empty desktop.

local terminal = "foot"
local browser  = "firefox"

hl.monitor({
    output   = "",
    mode     = "5120x1440@120",
    position = "auto",
    scale    = 1,
})

-- Start-up: lets services started by systemd and D-Bus see this session, and shows
-- the shortcuts on the desktop. No windows open by themselves.
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("swaybg --image ~/.local/share/kiln/shortcuts.png --mode center --color '#000000'")
    hl.exec_cmd("waybar")
    hl.exec_cmd("kiln-idle")
end)

-- Window layout. On a wide screen, every window gets an equal column: 2 halves, 3
-- thirds, 4 quarters. On a standard screen, two columns with their windows stacked:
-- 2 halves, then the right half splits, then 2 by 2.
hl.layout.register("kiln", {
    recalculate = function (ctx)
        local area, count = ctx.area, #ctx.targets
        local function piece(start, size, index, parts)
            local from = start + math.floor(size * (index - 1) / parts)
            return from, start + math.floor(size * index / parts) - from
        end
        for i, target in ipairs(ctx.targets) do
            local x, y, w, h
            if area.w / area.h >= 2 then
                x, w = piece(area.x, area.w, i, count)
                y, h = area.y, area.h
            else
                local left = count // 2
                local on_left = i <= left
                x, w = piece(area.x, area.w, (on_left or count == 1) and 1 or 2,
                             count > 1 and 2 or 1)
                y, h = piece(area.y, area.h, on_left and i or i - left,
                             on_left and left or count - left)
            end
            target:place({ x = x, y = y, w = w, h = h })
        end
    end,
})

-- Environment
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- Keeps `uv pip` from replacing the PyTorch built for this machine.
hl.env("UV_EXCLUDE", "/etc/kiln/uv-exclude.txt")

-- Look and feel
local active_border_color   = "rgb(7aa2f7)"
local inactive_border_color = "rgba(595959aa)"

hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 2,
        col = {
            active_border   = active_border_color,
            inactive_border = inactive_border_color,
        },
        resize_on_border        = true,
        extend_border_grab_area = 8,
        hover_icon_on_border    = true,
        allow_tearing           = false,
        layout                  = "lua:kiln",
    },
    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = false },
    },
    group = {
        col = {
            border_active   = active_border_color,
            border_inactive = inactive_border_color,
        },
        groupbar = {
            font_size            = 12,
            font_family          = "monospace",
            font_weight_active   = "ultraheavy",
            font_weight_inactive = "normal",
            indicator_height     = 1,
            indicator_gap        = 5,
            height               = 22,
            gaps_in              = 5,
            gaps_out             = 0,
            text_color           = "rgb(ffffff)",
            text_color_inactive  = "rgba(ffffff90)",
            col = {
                active   = "rgba(00000040)",
                inactive = "rgba(00000020)",
            },
            gradients                 = true,
            gradient_rounding         = 0,
            gradient_round_only_edges = false,
        },
    },
    animations = { enabled = true },
    dwindle = {
        preserve_split = true,
        force_split    = 2,
    },
    scrolling = { column_width = 0.49 },
    master    = { new_status = "master" },
    misc = {
        force_default_wallpaper    = 0,
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        background_color           = "rgb(000000)",
        disable_scale_notification = true,
        focus_on_activate          = true,
        anr_missed_pings           = 3,
        on_focus_under_fullscreen  = 1,
        initial_workspace_tracking = 0,
        bell_sound                 = "none",
        key_press_enables_dpms     = true,
        mouse_move_enables_dpms    = true,
        -- Kiln has no recipe for hyprland-guiutils yet, so Hyprland warned at each start.
        -- Without it, the "not responding" box cannot show. See lessons/desktop.md.
        disable_hyprland_guiutils_check = true,
    },
    cursor = {
        hide_on_key_press        = true,
        -- Without this the pointer did not show after a full restart. See lessons/desktop.md.
        no_hardware_cursors      = 1,
        warp_on_change_workspace = 1,
    },
    render = { cm_auto_hdr = 0 },
    binds  = { hide_special_on_workspace_change = true },
    xwayland  = { force_zero_scaling = true },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
    input = {
        kb_layout          = "us",
        follow_mouse       = 1,
        sensitivity        = 0,
        repeat_rate        = 40,
        repeat_delay       = 250,
        numlock_by_default = true,
    },
})

-- Animations. Speed is in tenths of a second.
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 8,    bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 4.31, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 3.03, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3.28, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.19, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.38, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.17, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 2.42, bezier = "quick" })
hl.animation({ leaf = "fadeSwitch",    enabled = false })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.05, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3.2,  bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.2,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.43, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.11, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = false })

-- Window rules
local function window(match, rules)
    rules.match = type(match) == "string" and { class = match } or match
    hl.window_rule(rules)
end

window(".*", { suppress_event = "maximize" })
-- Fix some dragging issues with XWayland.
window({ class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
       { no_focus = true })
-- The tag lets the clipboard keys below treat a terminal differently.
window("(foot|org\\.codeberg\\.dnkl\\.foot|kiln-sidekick)", { tag = "+terminal" })
window({ tag = "terminal" }, { opacity = "0.985 0.96" })
-- Picture-in-picture overlays.
window({ title = "(Picture.?in.?[Pp]icture)" }, { tag = "+pip" })
window({ tag = "pip" }, {
    float = true,
    pin   = true,
    size  = { 600, 338 },
    keep_aspect_ratio = true,
    border_size = 0,
    move  = { "(monitor_w-window_w-40)", "(monitor_h*0.04)" },
})
-- Hide screen sharing notification windows.
window({ title = ".*is sharing.*" }, { workspace = "special silent" })

-- The sidekick: Claude Code on one key. See /usr/local/bin/kiln-sidekick.
hl.window_rule({
    name      = "kiln-sidekick",
    match     = { class = "kiln-sidekick" },
    workspace = "special:sidekick",
    float     = true,
    size      = "monitor_w*0.5 monitor_h*0.9",
    center    = true,
})
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("kiln-sidekick"))
hl.bind("mouse:274",     hl.dsp.exec_cmd("kiln-sidekick"))

-- Programs
hl.bind("SUPER + RETURN",         hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + B",              hl.dsp.exec_cmd(browser))
hl.bind("SUPER + SHIFT + B",      hl.dsp.exec_cmd(browser))
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd(browser))
hl.bind("SUPER + SHIFT + ALT + B", hl.dsp.exec_cmd(browser .. " --private-window"))
hl.bind("SUPER + R",              hl.dsp.exec_cmd("kiln-apps"))
hl.bind("SUPER + SHIFT + SPACE",  hl.dsp.exec_cmd("pkill -SIGUSR1 -x waybar"))

-- Clipboard. Key down and up are sent separately, because send_shortcut can leave a
-- key stuck. A terminal gets Ctrl+Shift, because Ctrl+C there stops what is running.
local function press(mods, key)
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function ()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
end

local function in_terminal()
    local active = hl.get_active_window()
    for _, tag in ipairs(active and active.tags or {}) do
        if tag:gsub("%*$", "") == "terminal" then
            return true
        end
    end
    return false
end

local function clipboard(key)
    return function ()
        press(in_terminal() and "CTRL SHIFT" or "CTRL", key)
    end
end

hl.bind("SUPER + A", function () press("CTRL", "A") end)
hl.bind("SUPER + C", clipboard("C"))
hl.bind("SUPER + V", clipboard("V"))
hl.bind("SUPER + X", function () press("CTRL", "X") end)
-- Mouse: forward copies, back pastes.
hl.bind("mouse:276", clipboard("C"))
hl.bind("mouse:275", clipboard("V"))

-- Windows
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

hl.bind("SUPER + LEFT",  hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + UP",    hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + DOWN",  hl.dsp.focus({ direction = "d" }))

hl.bind("SUPER + SHIFT + LEFT",  hl.dsp.window.swap({ direction = "l" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.swap({ direction = "r" }))
hl.bind("SUPER + SHIFT + UP",    hl.dsp.window.swap({ direction = "u" }))
hl.bind("SUPER + SHIFT + DOWN",  hl.dsp.window.swap({ direction = "d" }))

hl.bind("ALT + SHIFT + TAB", hl.dsp.window.alter_zorder({ mode = "bottom" }))
hl.bind("ALT + TAB",         hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
hl.bind("ALT + TAB",         hl.dsp.window.bring_to_top())

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize with the minus and equals keys: Shift for height, Alt for a little, Ctrl for a lot.
for _, step in ipairs({ { "", 100 }, { "ALT + ", 25 }, { "CTRL + ", 300 } }) do
    local mods, size = step[1], step[2]
    hl.bind("SUPER + " .. mods .. "code:20",         hl.dsp.window.resize({ x = -size, y = 0, relative = true }))
    hl.bind("SUPER + " .. mods .. "code:21",         hl.dsp.window.resize({ x = size,  y = 0, relative = true }))
    hl.bind("SUPER + SHIFT + " .. mods .. "code:20", hl.dsp.window.resize({ x = 0, y = -size, relative = true }))
    hl.bind("SUPER + SHIFT + " .. mods .. "code:21", hl.dsp.window.resize({ x = 0, y = size,  relative = true }))
end

-- Workspaces, on the number keys
for i = 1, 10 do
    local key = "code:" .. tostring(i + 9)
    hl.bind("SUPER + " .. key,               hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. key,       hl.dsp.window.move({ workspace = i }))
    hl.bind("SUPER + SHIFT + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind("SUPER + TAB",          hl.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + SHIFT + TAB",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind("SUPER + CTRL + TAB",   hl.dsp.focus({ workspace = "previous_per_monitor" }))
hl.bind("SUPER + mouse_down",   hl.dsp.focus({ workspace = "m+1" }))
hl.bind("SUPER + mouse_up",     hl.dsp.focus({ workspace = "m-1" }))
hl.bind("SUPER + S",            hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind("SUPER + ALT + S",      hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Window groups
hl.bind("SUPER + G",             hl.dsp.group.toggle())
hl.bind("SUPER + ALT + G",       hl.dsp.window.move({ out_of_group = true }))
hl.bind("SUPER + ALT + LEFT",    hl.dsp.window.move({ into_group = "l" }))
hl.bind("SUPER + ALT + RIGHT",   hl.dsp.window.move({ into_group = "r" }))
hl.bind("SUPER + ALT + UP",      hl.dsp.window.move({ into_group = "u" }))
hl.bind("SUPER + ALT + DOWN",    hl.dsp.window.move({ into_group = "d" }))
hl.bind("SUPER + ALT + TAB",     hl.dsp.group.next())
hl.bind("SUPER + ALT + SHIFT + TAB", hl.dsp.group.prev())
hl.bind("SUPER + CTRL + LEFT",   hl.dsp.group.prev())
hl.bind("SUPER + CTRL + RIGHT",  hl.dsp.group.next())
hl.bind("SUPER + ALT + mouse_down", hl.dsp.group.next())
hl.bind("SUPER + ALT + mouse_up",   hl.dsp.group.prev())
for i = 1, 5 do
    hl.bind("SUPER + ALT + code:" .. tostring(i + 9), hl.dsp.group.active({ index = i }))
end

-- Leave the desktop, back to the login screen. Omarchy does this from its menu.
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())

-- Sound keys. Alt makes smaller steps.
hl.bind("XF86AudioRaiseVolume",       hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",       hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",              hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",           hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
