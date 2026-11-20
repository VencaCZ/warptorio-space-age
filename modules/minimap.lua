local shared = require("shared")
local warp_settings = require("internal_settings")

local M = {}

local env

function M.init(env_table)
  env = env_table
  return M
end

local ground_minimap_frame_name = "warptorio_ground_minimap_frame"
local ground_minimap_name = "warptorio_ground_minimap"
local ground_minimap_size = warp_settings.minimap.size
local native_hud_width = 264

local function is_interior_floor(surface_name)
  return surface_name == "factory" or surface_name == "garden"
end

local function get_minimap_setting(player_settings, name, default)
  local setting = player_settings[name]
  if not setting or setting.value == nil then
    return default
  end
  return setting.value
end

local function get_ground_minimap_surface()
  if not storage.warptorio then return nil end
  local ground_name = storage.warptorio.warp_zone
  if storage.warptorio.teleporting then
    ground_name = "warp-space-transition"
  end
  local ground = game.surfaces[ground_name]
  if not ground then
    ground = game.surfaces[storage.warptorio.warp_zone]
  end
  return ground
end

local function pin_minimap(player, frame)
  local scale = player.display_scale
  local res = player.display_resolution
  frame.auto_center = false
  frame.location = {
    x = res.width - (native_hud_width + ground_minimap_size + 16) * scale,
    y = 0,
  }
end

local function manage_builtin_minimap(player, on_interior)
  local minimap_enabled = player.game_view_settings.show_minimap
  if on_interior then
    if minimap_enabled then
      storage.warptorio.minimap_saved = storage.warptorio.minimap_saved or {}
      storage.warptorio.minimap_saved[player.index] = true
      player.game_view_settings.show_minimap = false
    end
  else
    local saved = storage.warptorio.minimap_saved and storage.warptorio.minimap_saved[player.index]
    if saved ~= nil then
      storage.warptorio.minimap_saved[player.index] = nil
      player.game_view_settings.show_minimap = saved
    end
  end
end

local function sync_ground_minimap(player)
  local frame = player.gui.screen[ground_minimap_frame_name]
  local player_settings = settings.get_player_settings(player)
  local enabled = get_minimap_setting(player_settings, "warptorio-ground-minimap", true)
  local toggled = not (storage.warptorio.minimap_toggled and storage.warptorio.minimap_toggled[player.index] == false)

  if not enabled or not toggled then
    manage_builtin_minimap(player, false)
    if frame then frame.destroy() end
    return
  end

  local ground = get_ground_minimap_surface()
  local on_interior = player.connected and
    player.controller_type == defines.controllers.character and
    is_interior_floor(player.surface.name) and ground ~= nil

  manage_builtin_minimap(player, on_interior)

  if not on_interior then
    if frame then frame.visible = false end
    return
  end

  if not frame then
    frame = player.gui.screen.add{
      type = "frame",
      name = ground_minimap_frame_name,
      caption = {"warptorio.ground-minimap"},
      direction = "vertical",
    }
    frame.auto_center = false
    local minimap = frame.add{type = "minimap", name = ground_minimap_name}
    minimap.style.width = ground_minimap_size
    minimap.style.height = ground_minimap_size
    minimap.style.padding = 0
    pin_minimap(player, frame)
  end
  frame.visible = true

  local minimap = frame[ground_minimap_name]
  if minimap.surface_index ~= ground.index then
    minimap.surface_index = ground.index
  end
  local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
  local platform_size = (warp_settings.floor.levels[level] or 6) * 2
  local factor = storage.warptorio.minimap_zoom_factor and storage.warptorio.minimap_zoom_factor[player.index] or 1
  local zoom = math.max(math.min(ground_minimap_size / (platform_size * warp_settings.minimap.platform_fill) * factor, warp_settings.minimap.zoom_max), warp_settings.minimap.zoom_min)
  if minimap.zoom ~= zoom then
    minimap.zoom = zoom
  end
  minimap.position = env.translate_surface_position(ground.name, {x = 0, y = 0})
end

M.sync = sync_ground_minimap

local function is_cursor_over_minimap(player, display_location)
  local frame = player.gui.screen[ground_minimap_frame_name]
  if not (frame and frame.valid and frame.visible) then return false end
  if not display_location then return false end
  local scale = player.display_scale
  local x, y = display_location.x, display_location.y
  local x0, y0 = frame.location.x, frame.location.y
  local minimap = frame[ground_minimap_name]
  local x1, y1
  if minimap and minimap.valid and minimap.location then
    x1 = x0 + (minimap.location.x + ground_minimap_size) * scale
    y1 = y0 + (minimap.location.y + ground_minimap_size) * scale
  else
    x1 = x0 + (ground_minimap_size + 16) * scale
    y1 = y0 + (ground_minimap_size + 40) * scale
  end
  return x >= x0 and x <= x1 and y >= y0 and y <= y1
end

local function on_ground_minimap_scroll(event, direction)
  local player = game.get_player(event.player_index)
  if not player then return end
  local element = event.element
  local over_element = element and element.valid and
    (element.name == ground_minimap_name or element.name == ground_minimap_frame_name)
  if not over_element and not is_cursor_over_minimap(player, event.cursor_display_location) then return end
  if not storage.warptorio.minimap_zoom_factor then
    storage.warptorio.minimap_zoom_factor = {}
  end
  local factor = storage.warptorio.minimap_zoom_factor[player.index] or 1
  if direction > 0 then
    factor = factor * warp_settings.minimap.zoom_step
  else
    factor = factor / warp_settings.minimap.zoom_step
  end
  factor = math.max(warp_settings.minimap.zoom_factor_min, math.min(warp_settings.minimap.zoom_factor_max, factor))
  storage.warptorio.minimap_zoom_factor[player.index] = factor
  sync_ground_minimap(player)
end

script.on_event(shared.input_minimap_zoom_in, function(e)
  on_ground_minimap_scroll(e, 1)
end)
script.on_event(shared.input_minimap_zoom_out, function(e)
  on_ground_minimap_scroll(e, -1)
end)

script.on_event(defines.events.on_player_changed_surface, function(e)
  local player = game.get_player(e.player_index)
  if player then sync_ground_minimap(player) end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting == "warptorio-ground-minimap" then
    for _, player in pairs(game.players) do
      sync_ground_minimap(player)
    end
  end
end)

script.on_event(defines.events.on_player_display_resolution_changed, function(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  local frame = player.gui.screen[ground_minimap_frame_name]
  if frame then pin_minimap(player, frame) end
end)

script.on_event(defines.events.on_player_display_scale_changed, function(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  local frame = player.gui.screen[ground_minimap_frame_name]
  if frame then pin_minimap(player, frame) end
end)

function M.chart(surface_name)
  local surface = game.surfaces[surface_name]
  if not (surface and surface.valid) then return end
  local force = game.forces.player
  if not (force and force.valid) then return end
  local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
  local platform_tiles = (warp_settings.floor.levels[level] or 6) * 2
  local visible = platform_tiles * warp_settings.minimap.platform_fill
  local radius = math.ceil(visible / 2) + 4
  -- Bosses spawn at floor level distance + up to ~300 tiles out, i.e. far
  -- outside the platform view; chart down to that ring or the (enlarged) boss
  -- dots and their skull tags stay invisible off-chart. Margin covers
  -- find_non_colliding_position jitter and inward drift while approaching.
  local boss_ring = (warp_settings.floor.levels[level] or 6) + (warp_settings.minimap.boss_reveal or 340)
  if boss_ring > radius then radius = boss_ring end
  local center = env.translate_surface_position(surface_name, {x = 0, y = 0})
  force.chart(surface, {
    {center.x - radius, center.y - radius},
    {center.x + radius, center.y + radius},
  })
end

function M.on_click(event)
  if event.element and (event.element.name == ground_minimap_name or event.element.name == ground_minimap_frame_name) then
    local player = game.get_player(event.player_index)
    local ground = get_ground_minimap_surface()
    if player and ground and player.controller_type == defines.controllers.character then
      player.set_controller{
        type = defines.controllers.remote,
        surface = ground,
        position = env.translate_surface_position(ground.name, player.position),
      }
    end
    return true
  end
  return false
end

function M.on_shortcut(event)
  if event.prototype_name == shared.shortcut_minimap_toggle then
    local player = game.get_player(event.player_index)
    if player then
      storage.warptorio.minimap_toggled = storage.warptorio.minimap_toggled or {}
      local toggled = storage.warptorio.minimap_toggled[player.index]
      if toggled == nil then toggled = true end
      toggled = not toggled
      storage.warptorio.minimap_toggled[player.index] = toggled
      player.set_shortcut_toggled(shared.shortcut_minimap_toggle, toggled)
      sync_ground_minimap(player)
    end
    return true
  end
  return false
end

return M
