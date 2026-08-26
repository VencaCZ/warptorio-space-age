local warp_settings = require("internal_settings")

local module = {}

local warptorio_test = {
    test = require("platforms.generated.test")
}

local zero_offset = {x=0, y=0}

local function get_surface_offset(surface_name)
  if storage.warptorio and storage.warptorio.surface_positions then
    return storage.warptorio.surface_positions[surface_name] or zero_offset
  end
  return zero_offset
end

-- Saved platform designs store raw prototype names. A design captured while another mod was
-- installed can reference entities/tiles/qualities that no longer exist once that mod is removed
-- or renamed, and create_entity/set_tiles raise a non-recoverable error on unknown names.
-- Everything that replays a design must go through these checks.
local function entity_exists(name)
   return name ~= nil and prototypes.entity[name] ~= nil
end

local function tile_exists(name)
   return name ~= nil and prototypes.tile[name] ~= nil
end

local function valid_quality(name)
   if name ~= nil and prototypes.quality[name] then
      return name
   end
   return nil
end

-- Drops entities and tiles whose prototypes no longer exist from a saved design (in place) and
-- clears qualities that are gone. Returns the number of removed entries.
local function prune_design(design)
   if type(design) ~= "table" then return 0 end
   local removed = 0
   if type(design.entities) == "table" then
      local kept = {}
      for _, v in ipairs(design.entities) do
         if entity_exists(v.name) then
            if v.quality ~= nil and not valid_quality(v.quality) then
               v.quality = nil
            end
            kept[#kept + 1] = v
         else
            removed = removed + 1
         end
      end
      design.entities = kept
      if design.entity_count ~= nil then design.entity_count = #kept end
   end
   if type(design.tiles) == "table" then
      local kept = {}
      for _, v in ipairs(design.tiles) do
         if tile_exists(v.name) then
            kept[#kept + 1] = v
         else
            removed = removed + 1
         end
      end
      design.tiles = kept
      if design.tile_count ~= nil then design.tile_count = #kept end
   end
   return removed
end

local function lootTable()
   local lt={}
   for _,v in ipairs(warp_settings.platforms.loot_items)do
      local r=game.forces.player.recipes[v]
      if(r and r.enabled==true)then
         table.insert(lt,v)
      end
   end
   return lt
end

local function serialize_ground_platform_design(surface_name)
  if not storage.warptorio then return nil, "warptorio_not_initialized" end
  local level = storage.warptorio.ground_level or 0
  if level == 0 then return nil, "ground_platform_not_unlocked" end
  local platform = warp_settings.floor.levels[level]
  if not platform then return nil, "ground_platform_level_invalid" end
  local surface = game.surfaces[surface_name]
  if not surface then return nil, "surface_not_found" end

  local center = get_surface_offset(surface_name)
  local area = {
    {center.x - platform, center.y - platform},
    {center.x + platform, center.y + platform}
  }

  -- Only capture the platform itself (foundation tiles). With non-square ground shapes the
  -- bounding box corners are planet terrain, which we must not bake into the saved design.
  local tiles = {}
  for _, tile in ipairs(surface.find_tiles_filtered{area = area}) do
    if tile.prototype.is_foundation then
      tiles[#tiles + 1] = {
        name = tile.name,
        position = {
          x = tile.position.x - center.x,
          y = tile.position.y - center.y,
        }
      }
    end
  end

  local entities = {}
  for _, entity in ipairs(surface.find_entities_filtered{area = area, force = game.forces.player}) do
    if entity.valid and entity.type ~= "character" then
      local data = {
        name = entity.name,
        type = entity.type,
        position = {
          x = entity.position.x - center.x,
          y = entity.position.y - center.y,
        },
        direction = entity.direction,
      }
      if entity.quality then
        data.quality = entity.quality.name
      end
      if entity.rotatable then
        data.orientation = entity.orientation
      end
      --if entity.get_recipe and entity.get_recipe() then
      --  data.recipe = entity.get_recipe().name
      --end
      if entity.get_requester_point then
        local point = entity.get_requester_point()
        if point and point.enabled ~= nil then
          data.requester_enabled = point.enabled
        end
      end
      entities[#entities + 1] = data
    end
  end

  return {
    version = 1,
    surface = surface_name,
    level = level,
    radius = platform,
    entity_count = #entities,
    tile_count = #tiles,
    entities = entities,
    tiles = tiles,
    saved_tick = game.tick,
  }
end

function module.on_tick()
    if not storage.warptorio then return end
    if not storage.warptorio.current_platforms then
       return
    end
    if not module.has_platforms() then return end
    if storage.warptorio.current_platforms.platform then
       if storage.warptorio.current_platforms.duration < warp_settings.platforms.duration then
          storage.warptorio.current_platforms.duration = storage.warptorio.current_platforms.duration + 1
          return
       end
       storage.warptorio.current_platforms.duration = 0
       module.delete()
       return
    end
    if storage.warptorio.current_platforms.timer < warp_settings.platforms.spawn_timer then
       storage.warptorio.current_platforms.timer = storage.warptorio.current_platforms.timer + 1
       return
    end
    module.spawn_random()
    storage.warptorio.current_platforms.timer = 0
end

function module.on_warp(source,name)
    if not storage.warptorio then storage.warptorio = {} end
    storage.warptorio.current_platforms = {
       timer = 0,
       -- Can be expanded to support more that one platform
       platform = nil,
       duration = 0,
    }
end

function module.on_research(event)
   for _,v in ipairs(warp_settings.platforms.save_triggers) do
      if v == event.research.name then
         module.save(v)
       end
    end
end

function module.has_platforms()
   if not storage.warptorio then return nil end
   if not storage.warptorio.platforms then return nil end
   local names = {}
   for name,_ in pairs(storage.warptorio.platforms) do
      table.insert(names,name)
   end
   if #names == 0 then return nil end
   return names
end

function module.spawn_random()
   local chance = math.random(0.00,1.00)
   if chance > warp_settings.platforms.spawn_chance then
      return false
   end
   local names = module.has_platforms()
   if not names or #names == 0 then return false end
   module.spawn(names[math.random(1,#names)])
   return true
end

local function roll_position(b_x,b_y)
   local sign_x = math.random(2) == 1 and -1 or 1
   local sign_y = math.random(2) == 1 and -1 or 1
   local x = math.random(
      warp_settings.platforms.position.x.min,
      warp_settings.platforms.position.x.max) * sign_x
   local y = math.random(
      warp_settings.platforms.position.y.min,
      warp_settings.platforms.position.y.max) * sign_y
   return b_x+x,b_y+y
end

function module.spawn(name,x,y)
   if not storage.warptorio then storage.warptorio = {} end
   if not storage.warptorio.platforms then storage.warptorio.platforms = {} end
   if not storage.warptorio.current_platforms then
       return
    end
   local surface_offset = get_surface_offset(storage.warptorio.warp_zone)
   local x,y = roll_position(x or surface_offset.x, y or surface_offset.y)
   local platform = warptorio_test[name]
   if not platform then
      platform = storage.warptorio.platforms[name]
   end
   if not platform then
      game.print("ERROR: There is no platform with name:"..name)
      return
   end
   -- Anything referencing a prototype that no longer exists is skipped instead of crashing.
   local skipped = {}
   local function skip(prototype_name)
      prototype_name = tostring(prototype_name)
      skipped[prototype_name] = (skipped[prototype_name] or 0) + 1
   end
   local tiles = {}
   for _,v in ipairs(platform.tiles) do
      if tile_exists(v.name) then
         table.insert(
            tiles,
            {
               name=v.name,
               position = {x=v.position.x+x,y=v.position.y+y}
            }
         )
      else
         skip(v.name)
      end
   end
   local items = lootTable()
   local center = nil
   local level = storage.warptorio.ground_level or 1
   local chests = {}
   game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
   for i, v in ipairs(platform.entities) do
      if not entity_exists(v.name) then
         skip(v.name)
      elseif v.type == "container" or v.type == "logistic-container" then
         local entity = game.surfaces[storage.warptorio.warp_zone].create_entity(
            { name = v.name,
              position = {x=v.position.x+x,y=v.position.y+y},
              direction = v.direction,
              force = game.forces.player,
              quality = valid_quality(v.quality)
            }
         )
         if entity then
            table.insert(chests,entity)
         end
        else
            if v.name == "warp-power" or v.name == "warp-power-2" or v.name == "warp-power-3" then
               local entity = game.surfaces[storage.warptorio.warp_zone].create_entity(
                  { name = "electric-energy-interface",
                    position = {x=v.position.x+x,y=v.position.y+y},
                    direction = v.direction,
                    force = game.forces.enemy
               })
               center = entity
            elseif v.name ~= "entity-ghost" and prototypes.item[v.name] then
               local entity = game.surfaces[storage.warptorio.warp_zone].create_entity(
                  { name = v.name,
                    position = {x=v.position.x+x,y=v.position.y+y},
                    direction = v.direction,
                    force = game.forces.enemy,
                    quality = valid_quality(v.quality)
                  })
               if entity then
                  for _,weapon in ipairs(warp_settings.platforms.weapons) do
                     if v.name == weapon.name then
                        if weapon.fluid then
                           entity.insert_fluid(weapon.ammo)
                        else
                           entity.insert(weapon.ammo)
                        end
                     end
                  end
               end
            end
        end
   end
   if next(skipped) then
      local parts = {}
      for prototype_name, count in pairs(skipped) do
         parts[#parts + 1] = prototype_name.." x"..count
      end
      table.sort(parts)
      log("Warptorio: skipped entries with unknown prototypes while spawning platform '"
          ..tostring(name).."': "..table.concat(parts, ", "))
   end
   if center then
      -- TODO do this better. For now this is fine
      -- TODO add sound
      game.print({"warptorio.platform-spawn"})
      storage.warptorio.current_platforms.platform = tiles
      storage.warptorio.current_platforms.surface = storage.warptorio.warp_zone
   end
   local max = math.min(warp_settings.platforms.chests,#chests)
   for _=1,max do
      local index = 1
      if #chests > 2 then
         index = math.random(1,#chests)
      else
         return
      end
      local entity = chests[index]
      entity.insert(
         {
            name = items[math.random(1, #items)],
            count = math.random(
               warp_settings.platforms.items.min,
               warp_settings.platforms.items.max+(level*warp_settings.platforms.items.scale)
            )
         }
      )
      table.remove(chests,index)
   end
end

function module.save(name, surface_name)
   --game.print("Saving warp platform design")
   if not storage.warptorio then storage.warptorio = {} end
   if not storage.warptorio.platforms then
      storage.warptorio.platforms = {}
   end
   local design_name = name or "default"
   local source_surface = surface_name or storage.warptorio.warp_zone
   local design, err = serialize_ground_platform_design(source_surface)
   if not design then return nil, err end
   if #design.entities < warp_settings.platforms.minimum_entities then
      return nil
   end
   local file_name = design_name.."_"..source_surface..".json"
   --game.print(file_name)
   helpers.write_file(file_name,helpers.table_to_json(design))
   storage.warptorio.platforms[design_name] = design
   return design
end

function module.list()
    local names = {}
    for i, _ in pairs(storage.warptorio.platforms) do
        table.insert(names, i)
    end
    return names
end

function module.add(name, design)
    if not storage.warptorio then storage.warptorio = {} end
    if not storage.warptorio.platforms then
        storage.warptorio.platforms = {}
    end
    if not name then
        game.print("Could not add platform design without name")
        return
    end
    if not design then
        game.print("Could not add platform design without design")
        return
    end
    prune_design(design)
    storage.warptorio.platforms[name] = design
end

-- Saved backups outlive the mods they were captured with. Prune entries whose prototypes
-- disappeared so old saves self-heal instead of crashing the next time that design is spawned.
function module.on_configuration_changed()
   if not storage.warptorio or not storage.warptorio.platforms then return end
   local removed = 0
   for _, design in pairs(storage.warptorio.platforms) do
      removed = removed + prune_design(design)
   end
   if removed > 0 then
      log("Warptorio: removed "..removed.." entries referencing missing prototypes from saved platform designs")
   end
end

function module.delete()
   game.print("Deleting platform")
    if not storage.warptorio then return end
    if not storage.warptorio.current_platforms then
       return
    end
    for _,v in ipairs(storage.warptorio.current_platforms.platform) do
       v.name = "empty-space"
    end
    game.surfaces[storage.warptorio.current_platforms.surface].set_tiles(
       storage.warptorio.current_platforms.platform)
    storage.warptorio.current_platforms.platform = nil
end

return module
