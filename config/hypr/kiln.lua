-- Kiln's own settings, loaded last by hyprland.lua.

-- Mouse: forward copies (Ctrl+C), back pastes (Ctrl+V).
-- Key down and up are sent separately, because send_shortcut can leave a key stuck.
-- A terminal gets Ctrl+Shift, because Ctrl+C there stops what is running.
local function press(mods, key)
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function ()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
end

local terminals = { "kitty", "ghostty", "konsole", "alacritty", "foot", "terminal", "kiln-sidekick" }

local function in_terminal()
    local active = hl.get_active_window()
    local class = string.lower(active and active.class or "")
    for _, name in ipairs(terminals) do
        if class:find(name, 1, true) then
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

hl.bind("mouse:276", clipboard("C"))
hl.bind("mouse:275", clipboard("V"))

-- No gaps between windows or at the screen's edges, and square corners.
-- The thin border stays, to show which window is active.
hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,
        layout   = "lua:kiln",
    },
    decoration = {
        rounding = 0,
    },
})

-- Window layout, as the owner asked: 1 window fills the screen, 2 make halves,
-- 3 thirds, 4 quarters. From 5 on there stay 4 columns, and the extra windows
-- stack top and bottom in the columns from the right: 5 gives 1,1,1,2 windows per
-- column, 8 gives a 4 by 2 grid. The oldest windows, on the left, stay biggest.
hl.layout.register("kiln", {
    recalculate = function (ctx)
        local area, count = ctx.area, #ctx.targets
        if count == 0 then return end
        local cols = math.min(count, 4)
        -- How many windows each column holds; the extra ones go to the right.
        local per_col, base, extra = {}, count // cols, count % cols
        for c = 1, cols do
            per_col[c] = base + ((c > cols - extra) and 1 or 0)
        end
        local function piece(start, size, index, parts)
            local from = start + math.floor(size * (index - 1) / parts)
            return from, start + math.floor(size * index / parts) - from
        end
        local c, row = 1, 0
        for _, target in ipairs(ctx.targets) do
            row = row + 1
            if row > per_col[c] then c, row = c + 1, 1 end
            local x, w = piece(area.x, area.w, c, cols)
            local y, h = piece(area.y, area.h, row, per_col[c])
            target:place({ x = x, y = y, w = w, h = h })
        end
    end,
})

-- Plain black behind the windows: no wallpaper (switched off in Noctalia's
-- ~/.config/noctalia/config.toml), no Hyprland logo or splash text.
hl.config({
    misc = {
        background_color         = "rgb(000000)",
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
})

-- The Omarchy look, from Omarchy 4.0 by David Heinemeier Hansson (MIT licence, copy in
-- ~/Projects/kiln/config/hypr/OMARCHY-LICENSE): Tokyo Night blue borders, solid windows
-- with no blur or shadow, and Omarchy's animations. Only the look; CachyOS's keys stay.
local active_border   = "rgb(7aa2f7)"
local inactive_border = "rgba(595959aa)"
hl.config({
    general = {
        border_size = 2,
        col = { active_border = active_border, inactive_border = inactive_border },
    },
    group = {
        col = { border_active = active_border, border_inactive = inactive_border },
    },
    decoration = {
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        blur   = { enabled = false },
    },
})
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear",       { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick",        { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
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
-- The pull-down keeps its slide, which Omarchy has no setting for.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2, bezier = "quick", style = "slide top" })

-- The sidekick: Claude Code in a pull-down window on the middle mouse button.
-- /usr/local/bin/kiln-sidekick opens it the first time, then hides and shows it.
hl.window_rule({
    name      = "kiln-sidekick",
    match     = { class = "kiln-sidekick" },
    workspace = "special:sidekick",
    float     = true,
    size      = "monitor_w*0.5 monitor_h*0.9",
    move      = { "(monitor_w*0.25)", "(monitor_h*0.05)" },
})
hl.bind("mouse:274", hl.dsp.exec_cmd("kiln-sidekick"))
-- It slides down to open and back up to hide.
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "quick", style = "slide top" })

-- Mouse speed (owner, 14 Nov 2026): a little faster than the default 0, on a scale of -1 to 1.
-- Acceleration stays off (flat, in inputs.lua), so the pointer moves in step with the hand.
hl.config({ input = { sensitivity = 0.2 } })
