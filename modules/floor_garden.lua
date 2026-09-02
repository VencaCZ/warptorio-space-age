local warp_settings = require("internal_settings")

local M = {}

local floor_tiles = {}
local floor_tiles_built = false

local function build_floor_tiles()
  if floor_tiles_built then return end
  floor_tiles_built = true
  for _, side in ipairs({"yumako", "jellynut"}) do
    for _, part in ipairs(warp_settings.garden[side].parts) do
      floor_tiles[part.tile] = true
    end
  end
end

local function remove_from_player(player, name)
  local cursor = player.cursor_stack
  if cursor and cursor.valid and cursor.valid_for_read and cursor.name == name then
    if cursor.count > 1 then
      cursor.count = cursor.count - 1
    else
      cursor.clear()
    end
    return
  end
  player.remove_item({name = name, count = 1})
end

local function tile_name(tile)
  return tile.old_tile and tile.old_tile.name or tile.name
end

local function restore_tiles(event)
  local tiles = {}
  for _, tile in ipairs(event.tiles) do
    local name = tile_name(tile)
    if floor_tiles[name] then
      table.insert(tiles, {name = name, position = tile.position})
    end
  end
  if #tiles > 0 then
    game.surfaces["garden"].set_tiles(tiles)
  end
end

local function restore_player(event)
  if not event.surface_index then return end
  if game.surfaces[event.surface_index].name ~= "garden" then return end
  restore_tiles(event)
  local player = game.players[event.player_index]
  if player and player.valid then
    for _, tile in ipairs(event.tiles) do
      local name = tile_name(tile)
      if floor_tiles[name] then
        remove_from_player(player, name)
      end
    end
  end
end

local function restore_robot(event)
  if not event.surface_index then return end
  if game.surfaces[event.surface_index].name ~= "garden" then return end
  restore_tiles(event)
  local robot = event.robot
  if robot and robot.valid then
    for _, tile in ipairs(event.tiles) do
      local name = tile_name(tile)
      if floor_tiles[name] then
        robot.remove_item({name = name, count = 1})
      end
    end
  end
end

function M.setup()
  build_floor_tiles()
  script.on_event(defines.events.on_player_mined_tile, restore_player)
  script.on_event(defines.events.on_robot_mined_tile, restore_robot)
end

return M