local wezterm = require "wezterm"
local config = wezterm.config_builder()

local function switch_helix_scheme(scheme)
  local helix_config = wezterm.home_dir .. "/.config/helix/config.toml"
  -- read helix config
  local file = assert(io.open(helix_config, "r"))
  local data = file:read("*all")
  file:close()
  -- replace theme
  local updated_data = data:gsub("theme%s*=%s*\".-\"", "theme = " .. "\"" .. scheme .. "\"")
  -- refresh helix
  local _, _, _ = wezterm.run_child_process { "pkill", "-USR1", "hx" }
  -- save the new helix config
  file = assert(io.open(helix_config, "w"))
  file:write(updated_data)
  file:close()
end

function get_schemes()
  if dark_mode then
    return "OneHalfDark", "myonedark"
  else
    return "OneHalfLight", "onelight"
  end
end

function update_config(window)
  local term_scheme, helix_scheme = get_schemes()
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme ~= term_scheme then
    overrides.color_scheme = term_scheme
    window:set_config_overrides(overrides)
  end
  switch_helix_scheme(helix_scheme)
end

wezterm.on("switch-color", function (window, pane)
  dark_mode = not dark_mode
  update_config(window)
end)

wezterm.on('window-config-reloaded', function(window, pane)
  update_config(window)
end)

-- Default theme
dark_mode = false
if wezterm.gui.get_appearance():find("Dark") then
  dark_mode = true
end
local term_scheme, helix_scheme = get_schemes()
config.color_scheme = term_scheme
switch_helix_scheme(helix_scheme)

config.front_end = "WebGpu"
config.max_fps = 144

config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_padding = {
  bottom = 0
}
config.window_frame = {
  font_size = 13.0,
}
config.font = wezterm.font({ family = "MesloLGS NF" })
config.font_size = 13
config.set_environment_variables = {
  PATH = "/usr/local/bin:" .. os.getenv('PATH')
}

local function move_pane(key, direction)
  return {
    key = key,
    mods = "SUPER",
    action = wezterm.action.ActivatePaneDirection(direction),
  }
end

local session_manager = require("wezterm-session-manager/session-manager")
wezterm.on("save_session", function(window) session_manager.save_state(window) end)
wezterm.on("restore_session", function(window) session_manager.restore_state(window) end)

-- Track loaded workspaces
local loaded = {
  default = true
} 

config.keys = {
  {
    key = "S", 
    mods = "SUPER", 
    action = wezterm.action.EmitEvent "save_session"
  },
  {
    key = "R", 
    mods = "SUPER", 
    action = wezterm.action.EmitEvent "restore_session"
  },
  {
    key = "P",
    mods = "SUPER",
    action = wezterm.action.InputSelector {
      title = "Projects",
      choices = {
        { label = "default" },
        { label = "dev" },
        { label = "frafos" },
      },
      fuzzy = true,
      action = wezterm.action_callback(function(child_window, child_pane, id, label)
        wezterm.log_info("switching to" .. label)
        child_window:perform_action(wezterm.action.SwitchToWorkspace {
          name = label,
          spawn = { cwd = label }
        }, child_pane)
        if not loaded[label] then
          child_window:perform_action(wezterm.action.EmitEvent "restore_session", child_pane)
          loaded[label] = true
        end
      end),
    }
  },
  {
    key = ".",
    mods = "SUPER",
    action = wezterm.action.EmitEvent "switch-color"
  },
  {
    key = ",",
    mods = "SUPER",
    action = wezterm.action.SpawnCommandInNewTab {
      cwd = wezterm.home_dir,
      args = { "hx", wezterm.config_file },
    },
  },
  {
    key = "k",
    mods = "SUPER",
    action = wezterm.action.ClearScrollback "ScrollbackAndViewport"
  },
  {
    key = "w",
    mods = "SUPER",
    action = wezterm.action.CloseCurrentPane { confirm = false }
  },
  {
    key = "d",
    mods = "SUPER",
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = "D",
    mods = "SUPER",
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = "LeftArrow",
    mods = 'SHIFT|SUPER',
    action = wezterm.action.MoveTabRelative(-1),
  },
  {
    key = "RightArrow",
    mods = 'SHIFT|SUPER',
    action = wezterm.action.MoveTabRelative(1),
  },
  move_pane("J", "Down"),
  move_pane("K", "Up"),
  move_pane("H", "Left"),
  move_pane("L", "Right"),
  { mods = "OPT", key = "LeftArrow", action = wezterm.action.SendKey({ mods = "ALT", key = "b" }) },
  { mods = "OPT", key = "RightArrow", action = wezterm.action.SendKey({ mods = "ALT", key = "f" }) },
  { mods = "CMD", key = "LeftArrow", action = wezterm.action.SendKey({ mods = "CTRL", key = "a" }) },
  { mods = "CMD", key = "RightArrow", action = wezterm.action.SendKey({ mods = "CTRL", key = "e" }) },
  { mods = "CMD", key = "Backspace", action = wezterm.action.SendKey({ mods = "CTRL", key = "u" }) }
}

return config
