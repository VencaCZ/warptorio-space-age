local warp_settings = require("internal_settings")

local M = {}

local zero_offset = {x=0, y=0}

local function get_surface_offset(surface_name)
  if storage.warptorio and storage.warptorio.surface_positions then
    return storage.warptorio.surface_positions[surface_name] or zero_offset
  end
  return zero_offset
end

local function translate_surface_position(surface_name, position)
  local offset = get_surface_offset(surface_name)
  return {x = position.x + offset.x, y = position.y + offset.y}
end

local function teleport_fx()
   storage.warptorio = storage.warptorio or {}
   storage.warptorio.teleport_fx = storage.warptorio.teleport_fx or {}
   return storage.warptorio.teleport_fx
end

local function teleport_sounds()
   storage.warptorio = storage.warptorio or {}
   storage.warptorio.teleport_sounds = storage.warptorio.teleport_sounds or {}
   return storage.warptorio.teleport_sounds
end

function M.teleport_body(player, position, surface)
  if player.character then
    player.character.teleport(position, surface)
    if player.controller_type == defines.controllers.remote then
      player.exit_remote_view()
    end
  else
    player.teleport(position, surface)
  end
end

function M.play_teleport_sound(surface, position)
  if surface and surface.valid then
    surface.play_sound{path="warptorio-teleport", position=position}
  end
end

function M.teleport_effect(surface, position)
  if not surface or not surface.valid then return end
  if prototypes.entity["railgun-beam"] then
    surface.create_entity{name="railgun-beam", position=position, target=position}
  end
  table.insert(teleport_fx(), {surface_name=surface.name, position=position, tick=game.tick})
end

script.on_nth_tick(2, function()
  local now = game.tick
  local sq = teleport_sounds()
  for i = #sq, 1, -1 do
    local s = sq[i]
    if s.tick <= now then
      table.remove(sq, i)
      local surface = s.surface_name and game.surfaces[s.surface_name]
      M.play_teleport_sound(surface, s.position)
      local p = game.get_player(s.player_index)
      if p and p.connected and p.controller_type == defines.controllers.character then
        p.play_sound{path="warptorio-teleport", position=s.position}
      end
    end
  end
  local fx_list = teleport_fx()
  for i = #fx_list, 1, -1 do
    local fx = fx_list[i]
    local surface = fx.surface_name and game.surfaces[fx.surface_name]
    if not (surface and surface.valid) then
      table.remove(fx_list, i)
    else
      local p = (now - fx.tick) / 15
      if p >= 1 then
        table.remove(fx_list, i)
      else
        rendering.draw_circle{
          surface = surface,
          target = fx.position,
          radius = 0.5 + p * 3,
          width = 3,
          filled = false,
          color = {0.3, 0.8, 1, (1 - p) * 0.9},
          time_to_live = 3,
        }
        if p < 0.4 then
          local k = p / 0.4
          rendering.draw_circle{
            surface = surface,
            target = fx.position,
            radius = 0.5 + (1 - k) * 1.5,
            filled = true,
            color = {0.5, 0.9, 1, (1 - k) * 0.7},
            time_to_live = 3,
          }
        end
      end
    end
  end

  local charges = storage.warptorio.teleport_charge
  local delay = settings.startup["warptorio_teleport-delay"] and settings.startup["warptorio_teleport-delay"].value or 20
  if charges and delay > 0 then
    for i, player in pairs(game.players) do
      if player.connected and player.controller_type == defines.controllers.character then
        local prefix = i .. "|"
        local start_tick = nil
        for k, t in pairs(charges) do
          if string.sub(k, 1, #prefix) == prefix then
            start_tick = t
            break
          end
        end
        if start_tick and now - start_tick < delay then
          local p = (now - start_tick) / delay
          local filled = math.floor(p * 10 + 0.5)
          local bar = string.rep("█", filled) .. string.rep("░", 10 - filled)
          rendering.draw_text{
            surface = player.surface,
            target = {player.position.x, player.position.y - 1.2},
            text = bar,
            color = {0.3, 0.8, 1},
            scale = 0.7,
            scale_with_zoom = false,
            alignment = "center",
            time_to_live = 3,
          }
        end
      end
    end
  end
end)

function M.check_teleport(player,location,destination,box)
  if storage.warptorio.factory_level == 0 then return end
  local character = player.character
  if not character then return end
  if character.surface.name ~= location.surface then return end
  local charges = storage.warptorio.teleport_charge
  if not charges then
    charges = {}
    storage.warptorio.teleport_charge = charges
  end
  local charge_key = player.index .. "|" .. location.surface .. "|" .. location.x .. "|" .. location.y .. "|" .. destination
  local player_key = player.index .. "|"
  local delay = settings.startup["warptorio_teleport-delay"] and settings.startup["warptorio_teleport-delay"].value or 20
  local location_pos = translate_surface_position(location.surface, {x=location.x, y=location.y})
  local minx = box and box.minx or -0.4
  local maxx = box and box.maxx or 2.4
  local miny = box and box.miny or -0.4
  local maxy = box and box.maxy or 2.5
  if character.position.x > location_pos.x+minx and
     character.position.x < location_pos.x+maxx and
     character.position.y > location_pos.y+miny and
     character.position.y < location_pos.y+maxy then
    local now = game.tick
    local charge = charges[charge_key]
    if not charge and delay > 0 then
      charges[charge_key] = now
      return
    end
    if delay > 0 and now - charge < delay then return end
    for k in pairs(charges) do
      if string.sub(k, 1, #player_key) == player_key then
        charges[k] = nil
      end
    end
    local dest_pos = translate_surface_position(destination, {x=location.x, y=location.y})
    local player_pos = nil
    if dest_pos then
       player_pos = game.surfaces[destination].find_non_colliding_position("character", {dest_pos.x,dest_pos.y}, 0, 0.5, false) or dest_pos
    end
    if not player_pos then
       error("No free space for destination. Looks like teleporter is blocked")
    end
    local from_surface = player.character and player.character.surface or player.surface
    local from_position = player.character and player.character.position or player.position
    M.teleport_body(player, player_pos, destination)
    table.insert(teleport_sounds(), {surface_name=game.surfaces[destination] and game.surfaces[destination].name, position=player_pos, player_index=player.index, tick=game.tick+8})
    M.teleport_effect(from_surface, from_position)
    M.teleport_effect(game.surfaces[destination], player_pos)
  else
    charges[charge_key] = nil
  end
end

function M.teleport_players(source,destination,factory)
  local level = storage.warptorio.ground_level or 0
  local platform = warp_settings.floor.levels[level] or 0
  local source_offset = get_surface_offset(source)
  local dest_offset = get_surface_offset(destination)
  local minx = source_offset.x - platform
  local maxx = source_offset.x + platform
  local miny = source_offset.y - platform
  local maxy = source_offset.y + platform

  local function teleport_player_to(player, target)
    local from_surface = player.character and player.character.surface or game.surfaces[destination]
    local from_position = player.character and player.character.position or target
    M.play_teleport_sound(from_surface, from_position)
    M.play_teleport_sound(game.surfaces[destination], target)
    M.teleport_body(player, target, destination)
    M.teleport_effect(from_surface, from_position)
    M.teleport_effect(game.surfaces[destination], target)
  end

  local function player_on_factory_warp_belt(player)
    if not player.character or player.character.surface.name ~= "factory" then return false end
    local pos = player.character.position
    local area = {{pos.x - 0.25, pos.y - 0.25}, {pos.x + 0.25, pos.y + 0.25}}
    local nearby_belts = game.surfaces["factory"].find_entities_filtered({area = area, type = "linked-belt"})
    for _,belt in ipairs(nearby_belts) do
      if belt.name:find("^warp%-platform%-belt%-") then
        return true
      end
    end
    return false
  end

  for _, v in pairs(game.players) do
    if not (v.is_player() and v.connected and v.character) then goto continue end

    if factory and player_on_factory_warp_belt(v) then
      local home = game.surfaces["factory"].find_non_colliding_position("character", {0,-2}, 0, 0.5, false) or {0,-2}
      teleport_player_to(v, home)
      goto continue
    end

    if v.character.surface.name ~= source then goto continue end

    local character_pos = v.character.position
    local target
    if factory then
      target = game.surfaces["factory"].find_non_colliding_position("character", {0,-2}, 0, 0.5, false) or {0,-2}
    elseif character_pos.x >= minx and character_pos.x <= maxx and character_pos.y >= miny and character_pos.y <= maxy then
      target = {x = dest_offset.x + (character_pos.x - source_offset.x), y = dest_offset.y + (character_pos.y - source_offset.y)}
    else
      target = game.surfaces[destination].find_non_colliding_position("character", {x=dest_offset.x, y=dest_offset.y}, 0, platform, false) or {x=dest_offset.x, y=dest_offset.y}
    end
    teleport_player_to(v, target)
    ::continue::
  end
end

return M