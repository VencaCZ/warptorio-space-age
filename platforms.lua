local warp_settings = require("internal_settings")

local module = {}

local warptorio_test = {
    test = require("platforms.generated.test")
}

local function get_surface_offset(surface_name)
  if storage.warptorio and storage.warptorio.surface_positions then
    return storage.warptorio.surface_positions[surface_name] or zero_offset
  end
  return zero_offset
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

  local tiles = {}
  for _, tile in ipairs(surface.find_tiles_filtered{area = area}) do
    tiles[#tiles + 1] = {
      name = tile.name,
      position = {
        x = tile.position.x - center.x,
        y = tile.position.y - center.y,
      }
    }
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
          warp_settings.platforms.duration = warp_settings.platforms.duration + 1
          return
       end
       warp_settings.platforms.duration = 0
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
   local x = 0
   local y = 0
   while x == 0 and y == 0 do
      x = math.random(
         warp_settings.platforms.position.x.min,
         warp_settings.platforms.position.x.max) * math.random(-1,1)
      y = math.random(
         warp_settings.platforms.position.y.min,
         warp_settings.platforms.position.y.max) * math.random(-1,1)
   end
   return b_x+x,b_y+y
end

function module.spawn(name,x,y)
   if not storage.warptorio then storage.warptorio = {} end
   if not storage.warptorio.platforms then storage.warptorio.platforms = {} end
   if not storage.warptorio.current_platforms then
       return
    end
   local x,y = roll_position(x or 0,y or 0)
   local platform = warptorio_test[name]
   if not platform then
      platform = storage.warptorio.platforms[name]
   end
   if not platform then
      game.print("ERROR: There is no platform with name:"..name)
      return
   end
   local tiles = {}
   for _,v in ipairs(platform.tiles) do
      table.insert(
         tiles,
         {
            name=v.name,
            position = {x=v.position.x+x,y=v.position.y+y}
         }
      )
   end
   local items = lootTable()
   local center = nil
   game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
   for i, v in ipairs(platform.entities) do
      if v.type == "container" or v.type == "logistic-container" then
         local entity = game.surfaces[storage.warptorio.warp_zone].create_entity(
            { name = v.name,
              position = {x=v.position.x+x,y=v.position.y+y},
              direction = v.direction,
              force = game.forces.player,
              quality = v.quality
                                                                                })
         local chance = math.random(0.00,1.00)
         if chance > warp_settings.platforms.items.chance then
            entity.insert(
               {
                  name = items[math.random(1, #items)],
                  count = math.random(
                     warp_settings.platforms.items.min,
                     warp_settings.platforms.items.max
                  )
               }
            )
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
                    quality = v.quality
                  })
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
   if center then
      -- TODO do this better. For now this is fine
      -- TODO add sound
      game.forces.player.print(center)
      storage.warptorio.current_platforms.platform = tiles
      storage.warptorio.current_platforms.surface = storage.warptorio.warp_zone
   end
end

function module.save(name, surface_name)
   game.print("Saving warp platform design")
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
   game.print(file_name)
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
    storage.warptorio.platforms[name] = design
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
