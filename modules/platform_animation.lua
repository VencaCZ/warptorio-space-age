local platform_animation = {}

local function position_key(x, y)
  return x .. "," .. y
end

local function build_position_set(tiles)
  local set = {}
  for _, tile in ipairs(tiles) do
    if tile_position_ok(tile) then
      set[position_key(tile_x(tile), tile_y(tile))] = true
    end
  end
  return set
end

local function sample_tiles(tiles, max_count)
  local count = #tiles
  if count <= max_count then
    return tiles
  end
  local step = math.floor(count / max_count)
  local sampled = {}
  for i = 1, count, step do
    table.insert(sampled, tiles[i])
    if #sampled >= max_count then
      break
    end
  end
  return sampled
end

local function shuffle_tiles(tiles)
  local shuffled = {}
  for i = 1, #tiles do
    shuffled[i] = tiles[i]
  end
  for i = #shuffled, 2, -1 do
    local j = math.random(i)
    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
  end
  return shuffled
end

local function sample_random(tiles, max_count)
  local count = #tiles
  if count <= max_count then
    return tiles
  end
  local shuffled = shuffle_tiles(tiles)
  local sampled = {}
  for i = 1, max_count do
    sampled[i] = shuffled[i]
  end
  return sampled
end

local warp_settings = require("internal_settings")
local repair_speed_config = warp_settings.repair.batch_configs[warp_settings.repair.speed] or warp_settings.repair.batch_configs.normal
local repair_batch_size = repair_speed_config.batch
local repair_interval = repair_speed_config.interval
local expand_lock_ticks = warp_settings.animation.expand_lock_ticks
local anim_offset_x = warp_settings.animation.build_anim_offset.x
local anim_offset_y = warp_settings.animation.build_anim_offset.y

local function platform_tile_names()
  local names = {[warp_settings.tiles.ground] = true}
  local proto = prototypes and prototypes.tile and prototypes.tile[warp_settings.tiles.ground]
  if proto then
    if proto.frozen_variant then
      names[proto.frozen_variant.name] = true
    end
    if proto.thawed_variant then
      names[proto.thawed_variant.name] = true
    end
  end
  return names
end

local neighbours = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

local function tile_x(tile)
  if tile.position.x ~= nil then
    return tile.position.x
  end
  return tile.position[1]
end

local function tile_y(tile)
  if tile.position.y ~= nil then
    return tile.position.y
  end
  return tile.position[2]
end

local function tile_position_ok(tile)
  return tile and tile.position and tile_x(tile) and tile_y(tile)
end

local function parse_key(key)
  local x, y = key:match("([^,]+),([^,]+)")
  return tonumber(x), tonumber(y)
end

local function is_missing(surface, x, y, names)
  return not names[surface.get_tile(x, y).name]
end

local function has_platform_neighbour(surface, x, y, names)
  for _, d in ipairs(neighbours) do
    if names[surface.get_tile(x + d[1], y + d[2]).name] then
      return true
    end
  end
  return false
end

function platform_animation.is_active()
  if not storage.warptorio then
    return false
  end
  if storage.warptorio.platform_rebuild_queue then
    return true
  end
  if storage.warptorio.platform_animation_active_until and
     game.tick < storage.warptorio.platform_animation_active_until then
    return true
  end
  return false
end

function platform_animation.start_gradual_repair(surface_name, tiles, center)
  if not storage.warptorio then
    return
  end
  if type(tiles) ~= "table" or #tiles == 0 then
    return
  end

  local surface = game.surfaces[surface_name]
  if not surface or not surface.valid then
    return
  end

  local names = platform_tile_names()

  local target_set = {}
  local tile_by_key = {}
  for _, tile in ipairs(tiles) do
    if tile_position_ok(tile) then
      local x = tile_x(tile)
      local y = tile_y(tile)
      local key = position_key(x, y)
      target_set[key] = true
      tile_by_key[key] = tile
    end
  end

  local edge_set = {}
  local edge_list = {}
  for key, _ in pairs(target_set) do
    local x, y = parse_key(key)
    if is_missing(surface, x, y, names) and has_platform_neighbour(surface, x, y, names) then
      edge_set[key] = true
      table.insert(edge_list, key)
    end
  end

  if #edge_list == 0 then
    return
  end

  storage.warptorio.platform_rebuild_queue = {
    surface_name = surface_name,
    center = center,
    platform_tile_names = names,
    target_set = target_set,
    tile_by_key = tile_by_key,
    edge_set = edge_set,
    edge_list = edge_list,
  }
  game.print("Repair queued: " .. #edge_list .. " edge tiles on " .. surface_name)
end

function platform_animation.on_tick()
  local queue = storage.warptorio and storage.warptorio.platform_rebuild_queue
  if not queue then
    return
  end

  local surface = game.surfaces[queue.surface_name]
  if not surface or not surface.valid then
    game.print("Repair aborted: surface " .. queue.surface_name .. " invalid")
    storage.warptorio.platform_rebuild_queue = nil
    return
  end

  queue.pending = queue.pending or {}
  local batch = {}
  local placed_keys = {}

  -- tiles whose build animation just finished become visible now
  local names = queue.platform_tile_names

  for i = #queue.pending, 1, -1 do
    local pending = queue.pending[i]
    if not pending.entity.valid then
      table.insert(batch, pending.tile)
      table.insert(placed_keys, pending.key)
      table.remove(queue.pending, i)
    end
  end

  if #batch > 0 then
    surface.set_tiles(batch)
  end

  -- start new build animations on this tick
  if game.tick % repair_interval == 0 then
    local spawned = 0
    while spawned < repair_batch_size and #queue.edge_list > 0 do
      local idx = math.random(#queue.edge_list)
      local key = queue.edge_list[idx]
      queue.edge_list[idx] = queue.edge_list[#queue.edge_list]
      table.remove(queue.edge_list)
      queue.edge_set[key] = nil

      local x, y = parse_key(key)
      if queue.target_set[key] and is_missing(surface, x, y, names) then
        local tile = queue.tile_by_key[key]
        local anim = surface.create_entity{
          name = "warptorio-platform-build-anim",
          position = {x = tile_x(tile) + 0.5 + anim_offset_x, y = tile_y(tile) + 0.5 + anim_offset_y}
        }
        table.insert(queue.pending, {entity = anim, tile = tile, key = key})
        spawned = spawned + 1
      end
    end
  end

  for _, key in ipairs(placed_keys) do
    queue.target_set[key] = nil
    local x, y = parse_key(key)
    for _, d in ipairs(neighbours) do
      local nx, ny = x + d[1], y + d[2]
      local nkey = position_key(nx, ny)
      if queue.target_set[nkey] and not queue.edge_set[nkey] and
         is_missing(surface, nx, ny, names) and has_platform_neighbour(surface, nx, ny, names) then
        queue.edge_set[nkey] = true
        table.insert(queue.edge_list, nkey)
      end
    end
  end

  if #queue.edge_list == 0 and #queue.pending == 0 then
    storage.warptorio.platform_rebuild_queue = nil
  end
end

function platform_animation.animate_ground_platform(surface, old_tiles, new_tiles, center, mode)
  if not surface or not surface.valid then
    return
  end
  if not center or center.x == nil or center.y == nil then
    return
  end
  if type(new_tiles) ~= "table" then
    return
  end

  storage.warptorio.platform_animation_active_until = game.tick + expand_lock_ticks

  local effect = (mode == "repair") and "explosion" or "space-platform-foundation-explosion"
  local max_effects = 120
  local tiles_to_animate = new_tiles

  if mode == "expand" then
    tiles_to_animate = sample_random(new_tiles, max_effects)
  end

  surface.create_entity{name = "big-explosion", position = center}

  for _, tile in ipairs(sample_tiles(tiles_to_animate, max_effects)) do
    if tile_position_ok(tile) then
      surface.create_entity{
        name = effect,
        position = {x = tile_x(tile) + 0.5, y = tile_y(tile) + 0.5}
      }
    else
      log("platform_animation: skipped tile without position in " .. (mode or "?"))
    end
  end
end

return platform_animation
