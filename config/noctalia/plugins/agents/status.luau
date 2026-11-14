--!nonstrict
-- Kiln agents: one boxed icon per agent, and one for the sentry. Blue inactive or clear,
-- green working, amber an update or setting due (the sentry), red needs you (a question,
-- a request, a failure or a possible threat). Each agent's state is a small file in
-- $XDG_RUNTIME_DIR/kiln-agents/, written by kiln-agent-status: the state on the first
-- line, a note on the second. Read once a second. Click: open or hide the Claude pull-down.

local AGENTS = {
  { id = "operator",   name = "Operator",   glyph = "terminal-2" },
  { id = "reviewer",   name = "Reviewer",   glyph = "shield-check" },
  { id = "researcher", name = "Researcher", glyph = "search" },
  { id = "watcher",    name = "Watcher",    glyph = "activity-heartbeat" },
  { id = "sentry",     name = "Sentry",     glyph = "shield-lock" },
}
local COLOURS = { idle = "#4A8FE7", working = "#3FB950", warn = "#E3B341", alert = "#F85149" }
local WORDS = { idle = "inactive", working = "working", warn = "something due", alert = "needs you" }
local dir = (noctalia.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/kiln-agents/"
local shown = nil

local function read(id)
  local text = noctalia.readFile(dir .. id)
  if not text then
    return "idle", ""
  end
  local state, note = string.match(text, "^(%a+)\n?([^\n]*)")
  if state == nil or COLOURS[state] == nil then
    return "idle", ""
  end
  return state, note or ""
end

local function render()
  local boxes, key = {}, ""
  for _, agent in ipairs(AGENTS) do
    local state, note = read(agent.id)
    key = key .. agent.id .. state .. note
    local colour = COLOURS[state]
    local tip = agent.name .. ": " .. WORDS[state]
    if note ~= "" then
      tip = tip .. " (" .. note .. ")"
    end
    table.insert(boxes, ui.row({
      border = colour, borderWidth = 1.5, radius = 4, paddingH = 3, paddingV = 1,
      align = "center", tooltip = tip,
    }, {
      ui.glyph({ name = agent.glyph, size = 14, color = colour }),
    }))
  end
  if key == shown then
    return
  end
  shown = key
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 4, align = "center" }, boxes))
end

function update()
  noctalia.setUpdateInterval(1000)
  render()
end

function onClick()
  noctalia.runAsync({ "kiln-sidekick" })
end
