local shared = require("shared")
local events = require("modules.events")
local warp_settings = require("internal_settings")
local map_gens = require("map_gens")
local train_code = require("train")
local platform_code = require("platforms")
local warp_constant_combinator = require("warp_constant_combinator")
local player_teleport = require("modules.player_teleport")
local gui_state = require("modules.gui_state")
local platform_animation = require("modules.platform_animation")
local ok, warpcheat = pcall(require, "modules.warpcheat")
if type(warpcheat) ~= "table" then
  log("[warpcheat] unavailable: " .. tostring(warpcheat))
  warpcheat = nil
end
local floor_garden = require("modules.floor_garden")
local warp_vote = require("modules.warp_vote")
local speech_bubbles = require("modules.speech_bubbles")
local minimap = require("modules.minimap")
local teleporter_visualize = require("modules.teleporter_visualize")
local compat_repair_turret = require("modules.compat_repair_turret")
local research_pause = require("modules.research_pause")
local power_tick = require("modules.power_tick")
local boss_system = require("modules.boss_system")
local platform_builder = require("modules.platform_builder")
platform_animation.set_platform_builder(platform_builder)

-- Helper function to create a tile
local function create_tile(name, x, y)
    return {name = name, position = {x, y}}
end

-- Function to generate a rectangle
local function generate_rectangle(width, height, tile,offset_x,offset_y)
    local tiles = {}
    local half_width = math.floor(width / 2)
    local half_height = math.floor(height / 2)
    local offset_x = offset_x or 0
    local offset_y = offset_y or 0

    for y = -half_height, math.ceil(height / 2)-1 do
        for x = -half_width, math.ceil(width / 2)-1 do
            if x >= -half_width and x <= half_width and y >= -half_height and y <= half_height then
                table.insert(tiles, create_tile(tile, x+offset_x, y+offset_y))
            --else
                --table.insert(tiles, create_tile("out-of-map", x, y))
            end
        end
    end

    return tiles
end

-- Function to generate a cross
local function generate_cross(width, height,arm_width)
    local tiles = {}
    local half_width = math.floor(width / 2)
    local half_height = math.floor(height / 2)

    for y = -half_height, half_height-1 do
        for x = -half_width, half_width-1 do
            if (y >= -arm_width and y < arm_width) or (x >= -arm_width and x < arm_width) then
                table.insert(tiles, create_tile(shared.tiles.factory, x, y))
            else
                table.insert(tiles, create_tile("out-of-map", x, y))
            end
        end
    end

    return tiles
end

-- Function to generate a hexagon
local function generate_hexagon(radius, tile,offset_x,offset_y)
    local tiles = {}
    local sqrt3 = math.sqrt(3)
    local offset_x = offset_x or 0
    local offset_y = offset_y or 0

    -- Distance from the center to the flat top/bottom edges of a regular hexagon.
    local height = radius * sqrt3 / 2

    local min_x = math.floor(-radius)
    local max_x = math.ceil(radius)
    local min_y = math.floor(-height)
    local max_y = math.ceil(height)

    -- Iterate integer tiles and test at tile centers (coord + 0.5) so the shape stays
    -- symmetric around the platform center.
    for y = min_y, max_y do
        local yy = math.abs(y + 0.5)
        for x = min_x, max_x do
            local xx = math.abs(x + 0.5)
            if yy <= height and sqrt3 * xx + yy <= sqrt3 * radius then
                tiles[#tiles + 1] = create_tile(tile, x + offset_x, y + offset_y)
            end
        end
    end
    return tiles
end

local function generate_ellipse(width, height, tile, offset_x, offset_y)
    local tiles = {}
    offset_x = offset_x or 0
    offset_y = offset_y or 0

    -- Radii in tiles (semi-axes)
    local rx = width  / 2
    local ry = height / 2

    -- Integer bounds to iterate
    local min_x = math.floor(-rx)
    local max_x = math.ceil(rx)
    local min_y = math.floor(-ry)
    local max_y = math.ceil(ry)

    -- Use ellipse equation: (x^2/rx^2) + (y^2/ry^2) <= 1
    -- Add 0.5 to sample at tile centers (optional but usually looks better).
    local inv_rx2 = (rx > 0) and (1 / (rx * rx)) or 0
    local inv_ry2 = (ry > 0) and (1 / (ry * ry)) or 0

    for y = min_y, max_y do
        local yy = (y + 0.5)
        for x = min_x, max_x do
            local xx = (x + 0.5)
            if (xx * xx) * inv_rx2 + (yy * yy) * inv_ry2 <= 1 then
                tiles[#tiles + 1] = create_tile(tile, x + offset_x, y + offset_y)
            end
        end
    end

    return tiles
end

local zero_offset = {x=0, y=0}

local function ensure_surface_positions()
  storage.warptorio = storage.warptorio or {}
  storage.warptorio.surface_positions = storage.warptorio.surface_positions or {}
  return storage.warptorio.surface_positions
end

local function get_surface_offset(surface_name)
  if storage.warptorio and storage.warptorio.surface_positions then
    return storage.warptorio.surface_positions[surface_name] or zero_offset
  end
  return zero_offset
end

local function ensure_surface_offset(surface_name)
  local positions = ensure_surface_positions()
  if not positions[surface_name] then
    positions[surface_name] = {x=0, y=0}
  end
  return positions[surface_name]
end

local function set_surface_offset(surface_name, position)
  local positions = ensure_surface_positions()
  positions[surface_name] = {x = position.x, y = position.y}
  return positions[surface_name]
end

local function translate_surface_position(surface_name, position)
  local offset = get_surface_offset(surface_name)
  return {x = position.x + offset.x, y = position.y + offset.y}
end

local function translate_surface_coordinates(surface_name, x, y)
  local offset = get_surface_offset(surface_name)
  return x + offset.x, y + offset.y
end

local function translate_surface_area(surface_name, area, radius)
  if area then
    local offset = get_surface_offset(surface_name)
    return {
      {area[1][1] + offset.x, area[1][2] + offset.y},
      {area[2][1] + offset.x, area[2][2] + offset.y}
    }
  end
  if radius then
    local offset = get_surface_offset(surface_name)
    return {
      {offset.x - radius, offset.y - radius},
      {offset.x + radius, offset.y + radius}
    }
  end
end

local function generate_surface_rectangle(surface_name, width, height, tile, offset_x, offset_y)
  local base = get_surface_offset(surface_name)
  local x = (offset_x or 0) + base.x
  local y = (offset_y or 0) + base.y
  return generate_rectangle(width, height, tile, x, y)
end

local shape_delta_cache = {}

-- The platform geometry (relative {x, y} list) is identical for every surface and only
-- depends on the configured shape and size, so compute it once per (shape, size). The
-- previous per-call generation rebuilt the whole ellipse/hexagon/rectangle math for each
-- warp stamp and clone brush even though the shape never changed.
local function shape_positions(shape, size)
  local key = shape .. "_" .. tostring(size)
  local positions = shape_delta_cache[key]
  if positions then
    return positions
  end
  local tiles
  if shape == "circle" then
    tiles = generate_ellipse(size, size, nil, 0, 0)
  elseif shape == "hexagon" then
    tiles = generate_hexagon(size * 0.62, nil, 0, 0)
  else
    tiles = generate_rectangle(size, size, nil, 0, 0)
  end
  positions = {}
  for i = 1, #tiles do
    positions[i] = tiles[i].position
  end
  shape_delta_cache[key] = positions
  return positions
end

-- Generates the ground floor tiles in the shape configured by warp_settings.floor.shape.
-- size is the full diameter/side length of the platform.
local function generate_ground_shape(surface_name, size, tile)
  local base = get_surface_offset(surface_name)
  local positions = shape_positions(warp_settings.floor.shape, size)
  local tiles = {}
  for i = 1, #positions do
    local p = positions[i]
    tiles[i] = {name = tile, position = {p[1] + base.x, p[2] + base.y}}
  end
  return tiles
end

local function prepare_surface_spawn(surface, surface_name, allow_random)
  local size = 10
  if not allow_random then
    set_surface_offset(surface_name, {x=0, y=0})
    surface.request_to_generate_chunks({0,0}, size)
    return {x=0, y=0}, size
  end
  local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
  local platform = warp_settings.floor.levels[level]
  local chunk_radius = math.ceil((platform * 2) / 32) + 2
  local base_range = warp_settings.random_position_offset
  --if storage.warporio and storage.warporio.index then
  --  base_range = math.max(base_range, chunk_radius + storage.warporio.index * 2)
  --end
  local chunk_x = 0
  local chunk_y = 0
  if warp_settings.allow_random_position and storage.warptorio.allow_random_spawn then
     chunk_x = math.random(-base_range, base_range)
     chunk_y = math.random(-base_range, base_range)
  end
  local center = {x = chunk_x * 32 + 16, y = chunk_y * 32 + 16}
  set_surface_offset(surface_name, center)
  local radius = math.max(chunk_radius, size)
  surface.request_to_generate_chunks(center, radius)
  return center, radius
end

local my_map_gen_settings = {
		default_enable_all_autoplace_controls = false,
		property_expression_names = {cliffiness = 0},
		autoplace_settings = {tile = {settings = { ["out-of-map"] = {frequency="normal", size="normal", richness="normal"} }}},
		starting_area = "none",
}

local space_gen_settings = {
		default_enable_all_autoplace_controls = false,
		property_expression_names = {cliffiness = 0},
		autoplace_settings = {tile = {settings = { ["empty-space"] = {frequency="normal", size="normal", richness="normal"} }}},
		starting_area = "none",
}

local starter_items=warp_settings.starter_items

local function get_or_create(name,pos)
  local surface_obj = game.surfaces[pos.surface]
  if not surface_obj then
     log("Warning: get_or_create skipped, surface \"" .. tostring(pos.surface) .. "\" is missing " .. name)
     return nil
  end
  local x, y = translate_surface_coordinates(pos.surface, pos.x, pos.y)
  local exist = surface_obj.find_entity(
    name,
    {
      x + (x > 0 and -0.5 or 0.5),
      y + 0.5
    }
  )
  if exist ~= nil then
    return exist
  end
  --game.print("Could not find entity "..(pos.x + (pos.x > 0 and -0.5 or 0.5)).."|"..pos.y + (pos.y > 0 and -0.5 or 0.5))
  local test = game.surfaces[pos.surface].can_place_entity{name=name, position = {x,y}}
  if not test then
    --game.print("Could not place entity. Making some space for"..name)
    for i,v in pairs(game.surfaces[pos.surface].find_entities({{x, y}, {x+1, y+1}})) do
      v.destroy()
    end
  end
  return game.surfaces[pos.surface].create_entity({name=name, position = {x,y}, direction = pos.dir, force=game.forces.player})
end

local function get_evolution_factor()
    local settings = warp_settings.biter.evolution or {}
    local evolution = settings.base or 0
    local researches = settings.researches or {}
    local technologies = game.forces["player"].technologies

    for _, research in ipairs(researches) do
       local tech = technologies[research.name]
      if tech and tech.researched then
        evolution = research.factor or evolution
      end
    end

    if evolution < 0 then evolution = 0 end
    if evolution > 1 then evolution = 1 end
    return evolution
end

local function remove_resources(surface)
  if storage.warptorio.ground_level == 0 then return end
  local level = storage.warptorio.ground_level
  local platform = warp_settings.floor.levels[level]

  local area = translate_surface_area(surface, nil, platform)
  local surface_obj = game.surfaces[surface]
  if not surface_obj or not surface_obj.valid then return end
  local resources = surface_obj.find_entities_filtered{area = area, type = "resource"}
  for i,v in ipairs(resources) do
    v.destroy()
  end
end

local function remove_recipes(surface)
  if storage.warptorio.ground_level == 0 then return end
  local level = storage.warptorio.ground_level
  local platform = warp_settings.floor.levels[level]

  local area = translate_surface_area(surface, nil, platform)
  local surface_obj = game.surfaces[surface]
  if not surface_obj or not surface_obj.valid then return end
  local entities = surface_obj.find_entities_filtered{area = area, type = "assembling-machine"}
  for i,v in ipairs(entities) do
     local recipe,quality = v.get_recipe()
     if recipe and recipe.prototype.surface_conditions then
        for a,b in ipairs(recipe.prototype.surface_conditions) do
           local value = game.surfaces[surface].get_property(b.property)
           if value < b.min or value > b.max then
              v.set_recipe()
           end
        end
     end
  end
end

local function starter_chest()
  if not warp_settings.starter then return end
  local container = get_or_create("steel-chest",{x=0,y=-10,surface="nauvis"})
  for i,v in pairs(starter_items) do
    container.insert({name=i, count=v})
  end
end

local function on_init_or_load()

   storage.warporio = storage.warporio or {}
   storage.warptorio = storage.warptorio or {}
   storage.warporio.index = storage.warporio.index or 0
   storage.warptorio.warp_zone = storage.warptorio.warp_zone or "nauvis"
   storage.warptorio.factory_level = storage.warptorio.factory_level or 0
   storage.warptorio.ground_level = storage.warptorio.ground_level or 0
   storage.warptorio.belt_level = storage.warptorio.belt_level or 0
   storage.warptorio.power_level = storage.warptorio.power_level or 0
   storage.warptorio.time_passed = storage.warptorio.time_passed or 0
   storage.warptorio.time_level = storage.warptorio.time_level or 0
   storage.warptorio.wave_time = storage.warptorio.wave_time or 0
   storage.warptorio.wave_index = storage.warptorio.wave_index or 0
    storage.warptorio.warp_out = storage.warptorio.warp_out or 0
    storage.warptorio.surface_name = storage.warptorio.surface_name or "nauvis"
    storage.warptorio.planet_timer = storage.warptorio.planet_timer or 0
    storage.warptorio.planet_next = storage.warptorio.planet_next or nil
    storage.warptorio.game_over = storage.warptorio.game_over or false
    research_pause.init()
    ensure_surface_positions()
   ensure_surface_offset(storage.warptorio.warp_zone)
   starter_chest()
   warp_constant_combinator.init()
end

local function pollution_settings()
    game.map_settings.pollution.enabled = true
		game.map_settings.pollution.diffusion_ratio = 0.1

end

script.on_init(function()

    if not game.surfaces["factory"] then

        local surface = game.create_surface("factory",my_map_gen_settings)
        local size = 10
        surface.create_global_electric_network()
        surface.always_day = true
        surface.request_to_generate_chunks({0,0}, size)
        surface.force_generate_chunk_requests()
    end

  on_init_or_load()
  local spawn_offset = get_surface_offset(storage.warptorio.warp_zone)
  game.forces.player.set_spawn_position({x=spawn_offset.x,y=spawn_offset.y+2}, game.surfaces[storage.warptorio.warp_zone])
  local tiles = generate_surface_rectangle("nauvis", warp_settings.floor.levels[1]*2,warp_settings.floor.levels[1]*2,"hazard-concrete-left")
  game.surfaces["nauvis"].set_tiles(tiles)
end)

local minimap_needs_reposition = false

script.on_load(function()
  --on_init_or_load()
  minimap_needs_reposition = true
end)

script.on_event(defines.events.on_force_created, function(e)
  local spawn = translate_surface_position("nauvis", {x=0, y=0})
  e.force.set_spawn_position(spawn, game.surfaces["nauvis"])
end)

--e.surface.create_entity({name="ei_2x2-container", position = {1, -1}, force=game.forces.player})

script.on_event(defines.events.on_chunk_generated, function(e)
  local f=e.surface
  if (not (f.name=="factory")) and (not (f.name=="garden")) then
    return
  end

	local minx = e.area.left_top.x
	local maxx = e.area.right_bottom.x
	local miny = e.area.left_top.y
	local maxy = e.area.right_bottom.y
  local platform=8
  local start_area = false

  local tiles = {}
	for x=minx-1, maxx do
		for y=miny-1, maxy do
      if x < platform and x > -(platform+1) and y < platform and y > - (platform+1) then
          table.insert(tiles, {name=shared.tiles.factory, position={x,y}})
          start_area = true
      else
	        table.insert(tiles, {name="out-of-map", position={x,y}})
      end
    end
	end
  e.surface.set_tiles(tiles)

  --[[if start_area then
  	local belt = game.surfaces["nauvis"].create_entity({name="linked-belt", position = {1, 1}, force=game.forces.player})
    local belt2 = game.surfaces["nauvis"].create_entity({name="linked-belt", position = {1, -1}, force=game.forces.player})
    belt2.linked_belt_type = "input"
    belt.linked_belt_type = "output"
    belt.connect_linked_belts(belt2)
  end]]
end)

script.on_event(defines.events.on_train_changed_state, train_code.on_train_changed_state)

local function average(c1c,c2c)
	local average_content = (c1c+c2c)/2
	c1c = average_content
	c2c = average_content
  return c1c,c2c
end

local function delete_items(bounding_box,name,surface)
  local area = translate_surface_area(surface, bounding_box)
  local entities = game.surfaces[surface].find_entities_filtered{area = area, name = name}
  for i,v in ipairs(entities) do
    v.destroy()
  end
end

function mysplit (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

local function set_ground_tiles(params)
  local size = params.size

  local offset = get_surface_offset(params.surface)

        local minx = params.x + offset.x
        local maxx = params.x + offset.x + size
        local miny = params.y + offset.y
        local maxy = params.y + offset.y + size

  local tiles = {}
        for x=minx, maxx do
                for y=miny, maxy do
      table.insert(tiles, {name=params.tiles, position={x,y}})
    end
	end
  game.surfaces[params.surface].set_tiles(tiles)
end

local function refresh_power_and_teleport(dest)
   local dest = dest or storage.warptorio.warp_zone
    storage.warptorio.power_name = storage.warptorio.power_name or shared.power[1]
    local dest_obj = game.surfaces[dest]
    if not dest_obj or not dest_obj.valid then
       log("Warning: refresh_power_and_teleport skipped, surface \"" .. tostring(dest) .. "\" is missing")
       return
    end
    local power_1 = power_tick.get_or_create_power(dest)
    local power_2 = power_tick.get_or_create_power("factory")
    power_1.minable_flag = false
    power_2.minable_flag = false
    power_1.rotatable = false
    power_2.rotatable = false
    set_ground_tiles({x=-1,y=-3,tiles="green-refined-concrete",surface=dest,size=1})
    set_ground_tiles({x=-1,y=1,tiles="green-refined-concrete",surface="factory",size=1})
    set_ground_tiles({x=-1,y=-3,tiles="red-refined-concrete",surface="factory",size=1})
    set_ground_tiles({x=-1,y=1,tiles="red-refined-concrete",surface=dest,size=1})
    set_ground_tiles({x=-1,y=-1,tiles="black-refined-concrete",surface="factory",size=1})
    set_ground_tiles({x=-1,y=-1,tiles="black-refined-concrete",surface=dest,size=1})
    set_ground_tiles({y=-1,x=-3,tiles="hazard-concrete-left",surface="factory",size=1})
    set_ground_tiles({y=-1,x=1,tiles="hazard-concrete-left",surface="factory",size=1})


	

    storage.warptorio.power = storage.warptorio.power or {}
    storage.warptorio.power[1] = power_1
    storage.warptorio.power[2] = power_2
    storage.warptorio.power_unit_number = storage.warptorio.power_unit_number or {}
    storage.warptorio.power_unit_number[1] = power_1.unit_number
    storage.warptorio.power_unit_number[2] = power_2.unit_number

    if storage.warptorio.biochamber_level then
        local power_3 = power_tick.get_or_create_power("garden")
        power_3.minable_flag = false
        power_3.rotatable = false
        storage.warptorio.power[3] = power_3
        storage.warptorio.power_unit_number[3] = power_3.unit_number
        set_ground_tiles({y=-1,x=-3,tiles="blue-refined-concrete",surface="factory",size=1})
        set_ground_tiles({y=-1,x=1,tiles="red-refined-concrete",surface="factory",size=1})
        set_ground_tiles({y=-1,x=-3,tiles="red-refined-concrete",surface="garden",size=1})
        set_ground_tiles({y=-1,x=1,tiles="blue-refined-concrete",surface="garden",size=1})		
    end

    local connects = {defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}
    for i,v in ipairs(connects) do
      local color = v
      local connector1 = storage.warptorio.power[1].get_wire_connector(v,true)
      local connector2 = storage.warptorio.power[2].get_wire_connector(v,true)
      connector1.connect_to(connector2,false,defines.wire_origin.script)
      if storage.warptorio.biochamber_level then
        local connector3 = storage.warptorio.power[3].get_wire_connector(v,true)
        connector1.connect_to(connector3,false,defines.wire_origin.script)
      end
    end

    local t_surface = game.surfaces[dest]
    if t_surface and t_surface.valid then
       for _, c in pairs(t_surface.find_entities_filtered{name=shared.container}) do
          if c.valid then c.destroy() end
       end
    end
    
    if storage.warptorio.container_left_enabled then
      local container = get_or_create(shared.container,{x=-2,y=0,surface=dest})
      local inventory = container.get_inventory(defines.inventory.chest)
      if inventory.get_item_count(shared.container) == 0 then
        container.insert({name=shared.container, count=1})
      end
      container.minable_flag = false
      container.rotatable = false
    end
    if storage.warptorio.container_right_enabled then
      local container = get_or_create(shared.container,{x=2,y=0,surface=dest})
      local inventory = container.get_inventory(defines.inventory.chest)
      if inventory.get_item_count(shared.container) == 0 then
        container.insert({name=shared.container, count=1})
      end
      container.minable_flag = false
      container.rotatable = false
    end

    teleporter_visualize.refresh()
end

local function update_factory_platform(e)
  --game.print("Upgrading ground platform size")
  local level = storage.warptorio.ground_level
  if e then
    level = mysplit(e,"-")
    level = tonumber(level[#level])
  end

  --if tonumber(level) == 1 then
    -- First upgrade generate base buildings
    --game.print("Spawning factory building")
    --game.surfaces["factory"].create_entity({name="space-platform-hub", position = {0,0}, force=game.forces.player})
  --end

  local platform = warp_settings.factory.levels[level]
  local tiles = {}
  
  if warp_settings.factory.shape == "ellipse" then
     tiles = generate_ellipse(platform.width,platform.height,shared.tiles.factory)
  elseif warp_settings.factory.shape == "hexagon" then
     tiles = generate_hexagon(platform.width*0.62,shared.tiles.factory)
  else
     tiles = generate_cross(platform.width,platform.height,platform.arm)
  end

	--for x=minx-1, maxx do
	--	for y=miny-1, maxy do
  --    table.insert(tiles, {name=shared.tiles.factory, position={x,y}})
  --  end
	--end
  game.surfaces["factory"].set_tiles(tiles)  
  storage.warptorio.factory_level = level

  if level == 1 and platform.width == 10 then
      -- This is horrible fix, but it will do for now
      local tiles = generate_rectangle((platform.width*2)-4,(platform.height*2)-4,"hazard-concrete-left")
      game.surfaces["factory"].set_tiles(tiles)
      local tiles = generate_rectangle((platform.width*2)-8,(platform.height*2)-4,shared.tiles.factory)
      game.surfaces["factory"].set_tiles(tiles)
      local tiles = generate_rectangle((platform.width*2)-4,(platform.height*2)-8,shared.tiles.factory)
      game.surfaces["factory"].set_tiles(tiles)
  elseif level == 2 then
      game.print({"warptorio.help-text-2",warp_settings.trigger_research})
  end
  
  -- warp belt factory
  set_ground_tiles({y=-1,x=-6,tiles="hazard-concrete-left",surface="factory",size=1}) -- to garden
  set_ground_tiles({x=-1,y=-6,tiles="hazard-concrete-left",surface="factory",size=1}) -- to ground
  set_ground_tiles({x=-1,y=4,tiles="hazard-concrete-left",surface="factory",size=1}) -- to ground

  if storage.warptorio.factory_level > 0 then
    refresh_power_and_teleport()
  end
end

local function new_random_surface(name)
   
   if name == "home" then
      storage.warptorio.warp_next = "nauvis"
      game.print({"warptorio.map-home"})
      return game.planets["nauvis"].surface
   end
  
  local surface_name = storage.warptorio.planet_next ~= "void" and storage.warptorio.planet_next or "nauvis"
  if name == "garden" or name == "space" then 
     surface_name = "nauvis"
  end
  if name ~= "garden" then
     storage.warptorio.surface_name = storage.warptorio.planet_next
  end
  local map_gen = nil
  map_gen = game.planets[surface_name].prototype.map_gen_settings
  storage.warptorio.allow_random_spawn = true

  if (storage.warptorio.planet_next == "void" and name ~= "space") or name == "garden" then
     map_gen = my_map_gen_settings
     if name ~= "garden" then
        storage.warptorio.void = true
     end
     storage.warptorio.allow_random_spawn = false
  elseif name == "space" then
     map_gen = space_gen_settings
     storage.warptorio.allow_random_spawn = false
  else
     storage.warptorio.void = false
  end
  map_gen.seed = math.random(0,math.pow(2,16))

  -- edit map gen
  map_gen.peaceful_mode = false
  map_gen.no_enemies_mode = false
  local ms = nil
  storage.warptorio.current_variant = "normal"
  
  --game.print("Generating surface:"..surface_name)
  if storage.warptorio.planet_next == "void" or name == "garden" or name == "space" then
     ms = map_gen
     if name == "space" then
        game.print({"warptorio.map-space"})
     elseif name == "garden" then
        -- no message, garden is an internal floor
     elseif storage.warptorio.planet_next == "void" then
        game.print({"warptorio.map-void"})
     end
  else
     local ms_i = storage.warptorio.forced_variant or map_gens.variant_list[math.random(1,#map_gens.variant_list)]
     storage.warptorio.current_variant = ms_i
     if ms_i == "rich" then
        storage.warptorio.allow_random_spawn = false
     end
     ms = map_gens.functions.generate(surface_name,ms_i,map_gen)
     game.print({"warptorio.map-gen-"..ms_i})
  end

  ms.seed = math.random(0,math.pow(2,32))
  if name ~= "garden" then
    storage.warptorio.warp_next = name
  end
  --ms = space_gen_settings
  
  if surface_name == "nauvis" then
    return game.create_surface(name,ms)
  else
    -- clear planets and reconect surfaces
    if game.planets[storage.warptorio.surface_name].surface and storage.warptorio.surface_name ~= surface_name then
      compat_repair_turret.destroy_before_clear(game.planets[storage.warptorio.surface_name].surface)
      game.planets[storage.warptorio.surface_name].surface.clear()
      game.delete_surface(game.planets[storage.warptorio.surface_name].surface.name)
    end

    if game.planets[storage.warptorio.surface_name].prototype.entities_require_heating or game.planets[storage.warptorio.surface_name].surface ~= nil then
      if game.planets[storage.warptorio.surface_name].surface ~= nil then
         game.planets[storage.warptorio.surface_name].surface.map_gen_settings = ms
      end
      local surf = game.planets[storage.warptorio.surface_name].create_surface()
      surf.name = name
      return surf
    else
      local surf = game.create_surface(name,ms)
      game.planets[storage.warptorio.surface_name].associate_surface(surf)
      return surf
    end
  end
end

local function belt_pair(pos1,pos2,speed)
    local speed = speed or 15
    local belt = nil
    local belt2 = nil

  	belt = get_or_create(shared.belt.prefix..speed,pos1)
    belt2 = get_or_create(shared.belt.prefix..speed,pos2)

    if belt == nil or belt2 == nil then
      --game.print("Belt link error")
      --game.print(belt)
      --game.print(belt2)
      return
    end

    -- Destroy both ends so the chain starts clean: a leftover linked belt may
    -- keep a stale chain that connect_linked_belts silently refuses to rebind,
    -- which made the warp links stop working randomly.
    belt.destroy()
    belt2.destroy()
    belt = get_or_create(shared.belt.prefix..speed,pos1)
    belt2 = get_or_create(shared.belt.prefix..speed,pos2)
    if belt == nil or belt2 == nil then
      return
    end
    belt2.linked_belt_type = "output"
    belt.linked_belt_type = "input"
    belt.connect_linked_belts(belt2)
    belt.minable_flag = false
    belt2.minable_flag = false
    belt.rotatable = false
    belt2.rotatable = false
end

local function update_belt_biochamber(e)
    if storage.warptorio.belt_level == 0 and e == nil then return end
    local speed = {15,30,45,60}
    --game.print("Upgrading belts connection")
    local level = storage.warptorio.belt_level
    if e then
      local e_level = mysplit(e,"-")
      level = tonumber(e_level[#e_level])
    end

    local names = {}

    for i,v in ipairs(speed) do
      if i ~= level then
        table.insert(names,shared.belt.prefix..v)
      end
    end

    for i,v in ipairs(names) do
      delete_items({{-5,-1},{-4,1}},v,"factory")
      delete_items({{-5,-1},{-4,1}},v,"garden")
      --delete_items({{4,-1},{5,1}},v,"factory")
      --delete_items({{4,-1},{5,1}},v,"garden")
    end

    belt_pair({y=0,x=-5,dir=defines.direction.east,surface="garden"},{y=0,x=-5,dir=defines.direction.east,surface="factory"},speed[level])
    belt_pair({y=-1,x=-5,dir=defines.direction.east,surface="garden"},{y=-1,x=-5,dir=defines.direction.east,surface="factory"},speed[level])
    --belt_pair({y=0,x=4,dir=defines.direction.west,surface="factory"},{y=0,x=4,dir=defines.direction.west,surface="garden"},speed[level])
    --belt_pair({y=-1,x=4,dir=defines.direction.west,surface="factory"},{y=-1,x=4,defines.direction.west,surface="garden"},speed[level])
end

local function update_biochamber_platform(e)
  local level = storage.warptorio.biochamber_level or 1
  if e then
    level = mysplit(e,"-")
    level = tonumber(level[#level])
  end

  if level == 3 then
     level = game.forces["player"].technologies[e].level-1
  end

  -- Calculate platform offset dynamically for infinite levels
  local platform = {
    width = warp_settings.garden.platform.width,
    height = warp_settings.garden.platform.height,
    offset_x = warp_settings.garden.platform.width * (level - 1),
    offset_y = 0,
    yumako = level,
    jellynut = level
  }

  -- Create garden surface if it doesn't already exist
  if not game.surfaces["garden"] then
      local surface = new_random_surface("garden")
      local size = 10   
      surface.create_global_electric_network()
      surface.always_day = true
      surface.request_to_generate_chunks({0,0}, size)
      surface.force_generate_chunk_requests()
  end
  
  -- Generate warp_tile_platform base for this upgrade's extension.
  local tiles = generate_rectangle(platform.width, platform.height, shared.tiles.factory, platform.offset_x, platform.offset_y)
  game.surfaces["garden"].set_tiles(tiles) 

  -- warp belt garden 	
  set_ground_tiles({y=-1,x=-6,tiles="hazard-concrete-left",surface="garden",size=1}) -- to factory
  storage.warptorio.biochamber_level = level

  -- add concrete, water, and soil for the yumako side of the platform. Only affects section added by this upgrade.
   do 
      local center_y = warp_settings.garden.yumako.y + warp_settings.garden.yumako.offset
      local center_x = warp_settings.garden.yumako.x * (platform.yumako-1)
      for _, part in ipairs(warp_settings.garden.yumako.parts) do
        local x = center_x
        local y = center_y
        x = x + (part.x and part.x or 0)
        y = y + (part.y and part.y or 0)
        local tiles = generate_rectangle(part.width, part.height, part.tile, x, y)
        game.surfaces["garden"].set_tiles(tiles)
      end
   end

   -- add concrete, water, and soil for the jellynut side of the platform. Only affects section added by this upgrade.
   do
      local center_y = warp_settings.garden.jellynut.y + warp_settings.garden.jellynut.offset
      local center_x = warp_settings.garden.jellynut.x * (platform.jellynut-1)
      for _, part in ipairs(warp_settings.garden.jellynut.parts) do
        local x = center_x
        local y = center_y
        x = x + (part.x and part.x or 0)
        y = y + (part.y and part.y or 0)
        local tiles = generate_rectangle(part.width, part.height, part.tile, x, y)
        game.surfaces["garden"].set_tiles(tiles)
      end
   end

  update_belt_biochamber()
  refresh_power_and_teleport()
  
  if level == 1 then
      local container = get_or_create(shared.container, {x=5, y=0, surface="garden"})
      container.minable_flag = false
      container.rotatable = false
  end
end

local function update_reactor_platform(e)

  local level = game.forces["player"].technologies[e].level

  -- Calculate platform offset dynamically for infinite levels
  local platform = {
    width = warp_settings.garden.platform.width,
    height = warp_settings.garden.platform.height,
    offset_x = warp_settings.garden.platform.width * (level - 1),
    offset_y = 0,
    yumako = level,
    jellynut = level
  }

  -- Create garden surface if it doesn't already exist
  if not game.surfaces["garden"] then
      local surface = new_random_surface("garden")
      local size = 10   
      surface.create_global_electric_network()
      surface.always_day = true
      surface.request_to_generate_chunks({0,0}, size)
      surface.force_generate_chunk_requests()
  end
  
  -- Generate warp_tile_platform base for this upgrade's extension.
  local tiles = generate_rectangle(platform.width, platform.height, shared.tiles.factory, -platform.offset_x, -platform.offset_y)
  game.surfaces["garden"].set_tiles(tiles) 

end

local function create_void_platform(surface, delete_entities,tile,multiplier)
   local tile = tile or "out-of-map"
   local multiplier = multiplier or 1
    if storage.warptorio.ground_level == 0 then return end
    local level = storage.warptorio.ground_level
    local platform = warp_settings.floor.levels[level]

    local tiles = generate_ground_shape(surface, platform * 2 * multiplier, tile)

    game.surfaces[surface].set_tiles(tiles)

    if delete_entities then
       -- Remove bots from old surface
       local area = translate_surface_area(surface, nil, platform)
       local entities = game.surfaces[surface].find_entities_filtered{
          area = area, force = "player"}
       for i,v in ipairs(entities) do
          v.destroy({raise_destroy=true})
       end
    end
end

local function set_hidden_tiles(surface,tile)
   local tile = tile or nil
    local level = storage.warptorio.ground_level
    local platform = warp_settings.floor.levels[level]

    local width = platform*2
    local height = platform*2
    local half_width = math.floor(width / 2)
    local half_height = math.floor(height / 2)
    local offset_x = offset_x or 0
    local offset_y = offset_y or 0
    local offset = get_surface_offset(surface)

    for y = -half_height, math.ceil(height / 2)-1 do
       for x = -half_width, math.ceil(width / 2)-1 do
          game.surfaces[surface].set_hidden_tile({x + offset.x,y + offset.y},nil)
       end
    end

end

local function update_ground_platform(e)
  if storage.warptorio.teleporting then
    storage.warptorio.pending_ground_platform_update = e or true
    return
  end

  local previous_level = storage.warptorio.ground_level
  local level = storage.warptorio.ground_level
  local dest = storage.warptorio.warp_zone
  
  if e then
    level = mysplit(e,"-")
    level = tonumber(level[#level])
    --storage.warptorio.wave_time = 0
    if level == 1 then
      create_void_platform(dest)
    end
  end

  --if tonumber(level) == 1 then
    -- First upgrade generate base buildings
    --game.print("Spawning factory building")
    --game.surfaces["factory"].create_entity({name="space-platform-hub", position = {0,0}, force=game.forces.player})
  --end

  local platform = warp_settings.floor.levels[level]

  --remove_resources(storage.warptorio.warp_zone)

  storage.warptorio.ground_level = level
  storage.warptorio.ground_size = platform*2

  local mode = (previous_level == level) and "repair" or "expand"
  local offset = get_surface_offset(dest)
  local center = {x = offset.x + 0.5, y = offset.y + 0.5}

  -- cancel any running gradual repair before changing platform
  if storage.warptorio.platform_rebuild_queue then
    storage.warptorio.platform_rebuild_queue = nil
  end

  game.print({"warptorio.platform-animation-starting"})

  if mode == "repair" then
    local new_tiles = generate_ground_shape(dest, platform*2, shared.tiles.ground)
    platform_animation.start_gradual_repair(dest, new_tiles, center)
    set_ground_tiles({x=-1,y=-6,tiles="hazard-concrete-left",surface=dest,size=1})
    set_ground_tiles({x=-1,y=4,tiles="hazard-concrete-left",surface=dest,size=1})
    if level == 1 then
        local tiles = generate_surface_rectangle(dest, 2,6,"hazard-concrete-left")
        game.surfaces[dest].set_tiles(tiles)
    end
    if not storage.warptorio.container_left_enabled then
        local tiles = generate_surface_rectangle(dest, 2,2,"hazard-concrete-left",-2)
        game.surfaces[dest].set_tiles(tiles)
    end
    if storage.warptorio.factory_level > 0 then
      refresh_power_and_teleport()
    end
  else
    local old_tiles = {}
    if previous_level and previous_level > 0 then
      local old_size = warp_settings.floor.levels[previous_level] * 2
      old_tiles = generate_ground_shape(dest, old_size, shared.tiles.ground)
    end
    local new_tiles = generate_ground_shape(dest, platform*2, shared.tiles.ground)
    platform_animation.animate_ground_platform(
      game.surfaces[dest],
      old_tiles,
      new_tiles,
      center,
      mode,
      dest,
      level
    )
  end
  -- Re-chart after a real platform resize so the bigger boss ring is revealed
  -- (the initial warp-time chart may use the previous, smaller level).
  if mode ~= "repair" then
    minimap.chart(dest)
  end
end

local function create_asteroids(amount, surface)
   local int_amount = math.floor(amount*warp_settings.space.multiplier)
   if int_amount == 0 then
      return
   end
   local dest = storage.warptorio.space
   local level = storage.warptorio.ground_level
   local size = warp_settings.floor.levels[level]
   local evolution = game.forces["enemy"].get_evolution_factor(storage.warptorio.warp_zone)

   local function roll_position()
      local x = 0
      local y = 0
      while x == 0 and y == 0 do
         x = math.random(
            size*4,
            size*8) * math.random(-1,1)
         y = math.random(
            size*4,
            size*8) * math.random(-1,1)
      end
      if x == 0 then
         x = math.random(-size*2,size*2)
      end
      if y == 0 then
         y = math.random(-size*2,size*2)
      end
      return x,y
   end

  
   for i,v in ipairs(warp_settings.space.tresholds) do
      if v < evolution then
         for _=1,int_amount do
            local x,y = roll_position()
            local length = math.sqrt(x*x + y*y)
            local speed = warp_settings.space.speed
            local velocity = {x = 0, y = 0}
            if length > 0 then
               velocity = {x = -x / length * speed, y = -y / length * speed}
            end
            local index = math.random(1,#warp_settings.space.asteroids[i])
            local asteroid = warp_settings.space.asteroids[i][index]
            game.surfaces[surface].create_entity{
               name=asteroid,
               position={x,y},
               velocity=velocity,
               target={0,0},
               force="enemy"}
         end
      end
   end
end

local transition_asteroid_names = {}
do
  local seen = {}
  for _, tier in ipairs(warp_settings.space.asteroids) do
    for _, name in ipairs(tier) do
      if not seen[name] then
        seen[name] = true
        transition_asteroid_names[#transition_asteroid_names + 1] = name
      end
    end
  end
end

-- warp-space-transition is created once and never recreated, so every ride leaves
-- its trailing asteroids behind for every future warp: they drift past the pad and
-- keep simulating until the next visit. Sweep the leftovers when the ride is over
-- (the pad is being abandoned at that point anyway).
boss_system.init({
  get_surface_offset = get_surface_offset,
  create_asteroids = create_asteroids,
})

local function clear_transition_asteroids()
  if #transition_asteroid_names == 0 then
    return
  end
  local surface = game.surfaces["warp-space-transition"]
  if not surface or not surface.valid then
    return
  end
  local found = surface.find_entities_filtered{name = transition_asteroid_names}
  for _, asteroid in ipairs(found) do
    if asteroid.valid then
      asteroid.destroy()
    end
  end
end

local function update_belt(e)
    if storage.warptorio.belt_level == 0 and e == nil then return end
    local speed = {15,30,45,60}
    --game.print("Upgrading belts connection")
    local level = storage.warptorio.belt_level
    if e then
      local e_level = mysplit(e,"-")
      level = tonumber(e_level[#e_level])
    end

    local names = {}

    for i,v in ipairs(speed) do
      if i ~= level then
        table.insert(names,shared.belt.prefix..v)
      end
    end

    for i,v in ipairs(names) do
      delete_items({{-1,-5},{1,-4}},v,"factory")
      delete_items({{-1,-5},{1,-4}},v,storage.warptorio.warp_zone)
      delete_items({{-1,4},{1,5}},v,"factory")
      delete_items({{-1,4},{1,5}},v,storage.warptorio.warp_zone)
    end

    belt_pair({x=0,y=-5,dir=defines.direction.south,surface=storage.warptorio.warp_zone},{x=0,y=-5,dir=defines.direction.south,surface="factory"},speed[level])
    belt_pair({x=-1,y=-5,dir=defines.direction.south,surface=storage.warptorio.warp_zone},{x=-1,y=-5,dir=defines.direction.south,surface="factory"},speed[level])
    belt_pair({x=0,y=4,dir=defines.direction.north,surface="factory"},{x=0,y=4,dir=defines.direction.north,surface=storage.warptorio.warp_zone},speed[level])
    belt_pair({x=-1,y=4,dir=defines.direction.north,surface="factory"},{x=-1,y=4,dir=defines.direction.north,surface=storage.warptorio.warp_zone},speed[level])


    storage.warptorio.belt_level = level
end

local function technology_check()
  if storage.warptorio and storage.warptorio.transition_timer and storage.warptorio.transition_timer > 60 then return false end
  if not game.forces["player"].current_research then return false end
  if game.forces["player"].current_research.name == shared.techs.end_prepare or game.forces["player"].current_research.name == shared.techs.end_win then
    return true
  end
  return false
end

gui_state.configure({technology_check = technology_check})

local function replace_with_high_quality(old_entity, strquality)

	local name = old_entity.name
	local surface = old_entity.surface
	local position = old_entity.position
	local force = old_entity.force
	local old_unit_number = old_entity.unit_number
	local boss_data = storage.warptorio and storage.warptorio.bosses
		and storage.warptorio.bosses[old_unit_number]
	local old_health = old_entity.health
	old_entity.destroy({raise_destroy=true})
	local new_entity = surface.create_entity{
		name = name,
		position = position,
		force = force,
		quality = strquality
	}
	-- Quality replacement destroys the old entity, which unregisters it as a
	-- boss; carry the registration over so the replacement still drops loot.
	if boss_data then
		boss_system.scale_health(new_entity)
		boss_system.register(new_entity, boss_data.quality, {lives = boss_data.lives, lives_total = boss_data.lives_total, health = old_health})
	end

end

local function choose_quality(index)
   if not script.active_mods["quality"] then
      return "normal"
   end
   -- During the final research, lock enemy quality to "warp" instead of scaling it
   -- from evolution/index like normal waves.
   if game.forces["player"].current_research and game.forces["player"].current_research.name == shared.techs.end_win then
      return "warp"
   end
   local evolution = get_evolution_factor()
   if evolution < warp_settings.biter.quality_evolution then
      storage.warptorio.last_normal = index
      return "normal"
   end
   local start = storage.warptorio.last_normal or 400
   local step = index-start
   step = math.ceil(step/warp_settings.biter.quality_step)
   if step < 1 then step = 1 end
   if step > #warp_settings.biter.quality then
      step = #warp_settings.biter.quality
   end
   return warp_settings.biter.quality[step]
end

local function replace_common(entity)
   if entity.force.name ~= "enemy" then return end
   local evolution = get_evolution_factor()
   -- Same gate as choose_quality: below it every enemy is normal quality anyway,
   -- so there is nothing to replace.
   if evolution < warp_settings.biter.quality_evolution then
      return
   end
   local types = {
      "unit","spider-unit","turret",
   }
   local work = false
   for _,v in ipairs(types) do
      if entity.type == v then
         work = true
      end
   end
   if not work then return end
   local quality = choose_quality(storage.warporio.index)
   if(quality ~= "normal") then
			replace_with_high_quality(entity, quality)
   end
end

-- Spawn the boss component of a wave on the current warp zone: decide how
-- many bosses are due (linear wave/warp count), build the per-planet weighted
-- boss pool (maf-boss-* variants belong to their home planet) and raise the
-- boss_spawned event. Shared by the natural wave cadence (check_wave) and the
-- warpcheat "Spawn boss wave" button.
local function spawn_boss_wave(biter_index, quality)
   -- Count dials live in internal_settings (boss_count_wave_divisor,
   -- boss_warp_count_every, boss_count_random, boss_alive_cap,
   -- boss_final_groups); the defaults reproduce the original pressure.
   local cfg = warp_settings.biter
   local final = technology_check()
   local wave_number = storage.warptorio.wave_index + 1
   local count = math.ceil(wave_number / (cfg.boss_count_wave_divisor or 10))
   if (cfg.boss_warp_count_every or 0) > 0 then
      count = count + math.floor((storage.warporio.index or 0) / cfg.boss_warp_count_every)
   end
   count = math.min(cfg.max_bosses, count)
   local function roll()
      if cfg.boss_count_random and count > 0 then return math.random(1, count) end
      return count
   end
   local groups = (final and cfg.boss_final_groups) and count or 1
   local boss_count = 0
   for _=1,groups do boss_count = boss_count + roll() end
   -- Hard cap on bosses alive at once (final research included): every
   -- boss brings lives and an escort, so an uncapped pile-up kills UPS.
   if cfg.boss_alive_cap then
      boss_count = math.max(0, math.min(boss_count, cfg.boss_alive_cap - boss_system.alive_boss_count()))
   end
   -- Modded boss variants (maf-boss-*) belong to their home planet. Bosses
   -- from another planet are excluded unless listed in boss_rare_planets,
   -- in which case they spawn with the given reduced weight. During the
   -- final researches (boss_final_all_planets) every variant is allowed.
   local ignore_planet = final and cfg.boss_final_all_planets
   local surface_name = storage.warptorio.surface_name
   local boss_cfg = warp_settings.biter.entity_type or {}
   local boss_planet_map = boss_cfg.boss_planet or {}
   local boss_rare_map = boss_cfg.boss_rare_planets or {}
   local boss_weight_map = boss_cfg.boss_weights or warp_settings.biter.boss_weights or {}
   local tier = warp_settings.biter.entity_type and warp_settings.biter.entity_type["boss"]
   if tier then tier = tier[biter_index] end
   local boss_pool = {}
   local boss_weight_total = 0
   if tier then
      for _, boss_name in ipairs(tier) do
         local prefix, home = nil, nil
         for p, planet in pairs(boss_planet_map) do
            if boss_name:sub(1, #p) == p then prefix, home = p, planet end
         end
         local weight = 1
         if prefix and not ignore_planet then
            if home == surface_name then
               weight = 1
            else
               local rare = boss_rare_map[prefix]
               if rare then
                  weight = rare[surface_name] or rare.default
               else
                  weight = nil
               end
            end
         end
         -- Variant-level rarity: multiply by the most specific matching prefix.
         if weight then
            for pw, w in pairs(boss_weight_map) do
               if boss_name:sub(1, #pw) == pw then
                  weight = weight * w
                  break
               end
            end
         end
         if weight and weight > 0 then
            boss_weight_total = boss_weight_total + weight
            table.insert(boss_pool, {name = boss_name, weight = weight})
         end
      end
      local function pick_boss()
         if #boss_pool == 0 then return nil end
         local r = math.random() * boss_weight_total
         for _, entry in ipairs(boss_pool) do
            r = r - entry.weight
            if r <= 0 then return entry.name end
         end
         return boss_pool[#boss_pool].name
      end
      -- Every boss leads its own group with an escort resolved from
      -- internal_settings boss_escort (see the comment there).
      local wave_group = warp_settings.biter.entity_type["default"]
      if surface_name and warp_settings.biter.entity_type[surface_name] then
         wave_group = warp_settings.biter.entity_type[surface_name]
      end
      local escort_cfg = cfg.boss_escort or {}
      local function escort_for(boss_name)
         local entry = {
            count = escort_cfg.count or {0, 0},
            tier_offset = escort_cfg.tier_offset or 0,
            top_quality = escort_cfg.top_quality or "legendary",
         }
         local function apply(over)
            if not over then return end
            for k, v in pairs(over) do entry[k] = v end
         end
         apply((escort_cfg.tiers or {})[biter_index])
         local best, best_len = nil, 0
         for prefix, over in pairs(escort_cfg.bosses or {}) do
            if #prefix > best_len and boss_name:sub(1, #prefix) == prefix then
               best, best_len = over, #prefix
            end
         end
         apply(best)
         local escort_quality = quality
         local types = entry.types
         if not types then
            local escort_tier = biter_index + entry.tier_offset
            if escort_tier > #wave_group then
               escort_tier = #wave_group
               if not final then escort_quality = entry.top_quality end
            end
            types = wave_group[math.max(1, escort_tier)] or {}
         end
         local exclude = entry.exclude or escort_cfg.exclude or {}
         if #exclude > 0 then
            local kept = {}
            for _, name in ipairs(types) do
               local skip = false
               for _, pattern in ipairs(exclude) do
                  if name:find(pattern, 1, true) then skip = true break end
               end
               if not skip then kept[#kept + 1] = name end
            end
            types = kept
         end
         if not prototypes.quality[escort_quality] then escort_quality = "normal" end
         local min = entry.count[1] or 0
         return {
            types = types,
            count = math.random(min, math.max(min, entry.count[2] or min)),
            quality = escort_quality,
         }
      end
      local zone = storage.warptorio.warp_zone
      for _=1,boss_count do
          local biter_type = pick_boss()
          if not biter_type then break end
          local escort = escort_for(biter_type)
          if string.match(biter_type, "demolisher") then
            -- Demolishers can't join a unit group; the escort comes in a
            -- separate group from the same spot.
            local angle = math.random()*2*math.pi
            boss_system.create_angry_boss(biter_type,1,zone,quality,nil,angle)
            boss_system.create_angry_biters(nil,0,zone,escort.quality,nil,false,{angle = angle, range = 125, escort = escort})
          else
            boss_system.create_angry_biters(biter_type,1,zone,quality,nil,true,{escort = escort})
          end
      end
   end
   events.raise(shared.events.boss_spawned, {
      index = storage.warptorio.wave_index,
      count = boss_count,
      quality = quality,
      surface = storage.warptorio.warp_zone,
   })
   return boss_count
end

local function check_wave()
    if not storage.warporio then storage.warporio = {} end
    if not storage.warporio.index then storage.warporio.index = 0 end
    if not game.forces["player"].technologies["warp-ground-platform-1"].researched
       and game.forces["player"].technologies[warp_settings.trigger_wave].researched == false
       and storage.warporio.index == 0 then
    storage.warptorio.wave_time = warp_settings.time.grace_period
  end
  local limit = storage.warptorio.wave_time

  if technology_check() and limit > warp_settings.biter.min then
     storage.warptorio.wave_time = warp_settings.biter.min
  end
  
  if not game.surfaces[storage.warptorio.warp_zone] then
     game.print("ERROR: Surface not found | "..storage.warptorio.warp_zone)
     return
  end
  
  local biter_index = 1
  local evolution = game.forces["enemy"].get_evolution_factor(storage.warptorio.warp_zone)
  for i,v in ipairs(warp_settings.biter.tresholds) do
    if v < evolution then
      biter_index = i
      if game.forces["enemy"].technologies["warp-weapons-"..biter_index] then
        if storage.warporio.index > 50 and warp_settings.dmg_research then
          game.forces["enemy"].technologies["warp-weapons-"..biter_index].researched = true
        else
          game.forces["enemy"].technologies["warp-weapons-"..biter_index].researched = false
        end
      end
    end
  end

  local spawn_boss = boss_system.spawn_boss_check()
  local quality = choose_quality(storage.warporio.index)  
  
  if limit <= 0 then
     local wave_index = storage.warptorio.wave_index+1
     local amount = warp_settings.biter.wave_amount*math.floor((wave_index)*warp_settings.biter.wave_increase)
     -- boss_flood_ratio of the regular flood still spawns on a boss wave
     -- (0 = the boss wave replaces the flood, the original behaviour).
     local flood_amount = amount
     if spawn_boss then
        local ratio = warp_settings.biter.boss_flood_ratio or 0
        flood_amount = ratio > 0 and math.max(warp_settings.biter.boss_flood_min or 3, math.floor(amount * ratio)) or 0
        -- At the alive-boss cap a boss wave spawns nothing at all: no bosses,
        -- no escorts (spawned per boss) and no flood share.
        local cap = warp_settings.biter.boss_alive_cap
        if cap and boss_system.alive_boss_count() >= cap then flood_amount = 0 end
     end
    for i=1,flood_amount do
      if technology_check() then break end
      local biter_group = warp_settings.biter.entity_type["default"]
      if storage.warptorio.surface_name and warp_settings.biter.entity_type[storage.warptorio.surface_name] then
        biter_group = warp_settings.biter.entity_type[storage.warptorio.surface_name]
      end

      --game.print("Spawning index "..biter_index.. " at evolution" .. evolution)
      local biter_type = biter_group[biter_index][math.random(1,#biter_group[biter_index])]
      local angry_amount = math.random(warp_settings.biter.amount/2,warp_settings.biter.amount)

      --game.print("Sending gifts "..warp_settings.biter.quality[quality_index].." quality")
      

      boss_system.create_angry_biters(biter_type,angry_amount,storage.warptorio.warp_zone,quality)
    end
    if spawn_boss or technology_check() then
       local spawned = spawn_boss_wave(biter_index, quality)
       if spawn_boss and spawned > 0 then
          -- Warn once per warp; later boss waves on the same planet are silent.
          if (not technology_check()) and (not storage.warptorio.boss_spawned_warp) then
             game.print({"warptorio.boss-warning"},{volume_modifier=0})
             game.play_sound({path="boss-spawn"})
          end
          storage.warptorio.boss_spawned_warp = true
       end
    end
    storage.warptorio.wave_index = storage.warptorio.wave_index + 1
    events.raise(shared.events.wave_spawned, {
       index = storage.warptorio.wave_index,
       amount = amount,
       boss = spawn_boss,
       quality = quality,
       surface = storage.warptorio.warp_zone,
    })
    if game.forces["player"].current_research and game.forces["player"].current_research.name == shared.techs.end_win then
       if storage.warptorio.wave_index < warp_settings.biter.final_offset then
          storage.warptorio.wave_index = warp_settings.biter.final_offset
       end
    end
    storage.warptorio.wave_time = warp_settings.biter.time - (storage.warptorio.wave_index*warp_settings.biter.change)
    if technology_check() then
        storage.warptorio.wave_time = warp_settings.biter.min
    end
    if storage.warptorio.wave_time < warp_settings.biter.min then
      storage.warptorio.wave_time = warp_settings.biter.min
    end
  elseif not storage.warptorio.void and not storage.warptorio.teleporting then
    if not storage.warptorio.wave_paused then
      storage.warptorio.wave_time = storage.warptorio.wave_time - 1/60
    end
  end
end

local function clean_ground_tiles(surface_name, area)
  local surface = game.surfaces[surface_name]
  local tiles = surface.find_tiles_filtered{area = area}
  local replacement = {}
  for _, t in ipairs(tiles) do
    local base_name = t.name:match("^frozen%-(.+)$")
    if base_name then
      table.insert(replacement, {name = base_name, position = t.position})
    elseif t.name:find("^lava") then
      table.insert(replacement, {name = shared.tiles.ground, position = t.position})
    end
  end
  if #replacement > 0 then
    surface.set_tiles(replacement)
  end
end

-- Snapshot each player's saved quickbar spidertron-remote slots before the
-- clone. Positions are offset-relative so the matching clones can be found on
-- the destination afterwards.
local function capture_spidertron_selections(source, offset)
  local captured = {}
  local source_surface = game.surfaces[source]
  if not source_surface or not source_surface.valid then return captured end

  for _, player in pairs(game.players) do
    if player.connected and player.valid then
      local slots = {}
      for page = 1, 10 do
        for slot = 1, (player.quick_bar_width or 10) do
          local qbs = player.get_quick_bar_slot(page, slot)
          if qbs and qbs.type == "remote" and qbs.selection and #qbs.selection > 0 then
            local rel = {}
            local keep = {}
            local any_on_source = false
            for _, spider in ipairs(qbs.selection) do
              if spider.valid then
                if spider.surface.name == source then
                  rel[#rel + 1] = {x = spider.position.x - offset.x, y = spider.position.y - offset.y}
                  any_on_source = true
                else
                  keep[#keep + 1] = spider
                end
              end
            end
            if any_on_source then
              slots[#slots + 1] = {page = page, slot = slot, filter = qbs.filter, rel = rel, keep = keep}
            end
          end
        end
      end
      if #slots > 0 then
        captured[player.index] = slots
      end
    end
  end
  local n = 0
  for _ in pairs(captured) do n = n + 1 end
  log("[warptorio] spidertron capture on " .. source .. ": " .. n .. " player(s)")
  return captured
end

-- Re-link the spidertron remotes to the clones after the warp: clones don't keep
-- the saved selection, and the originals are gone once the old surface is
-- deleted. 1.5 tile tolerance for the clone position.
local function restore_spidertron_selections(target, captured)
  if not captured or next(captured) == nil then return end
  local surface = game.surfaces[target]
  if not surface or not surface.valid then return end
  local offset = get_surface_offset(target)

  local function find_clone(r)
    local target_pos = {x = offset.x + r.x, y = offset.y + r.y}
    local found = surface.find_entities_filtered{
      type = "spider-vehicle",
      position = target_pos,
      radius = 1.5,
    }
    if not found then return nil end
    local best, best_d = nil, math.huge
    for _, spider in ipairs(found) do
      if spider.valid then
        local d = math.abs(spider.position.x - target_pos.x) + math.abs(spider.position.y - target_pos.y)
        if d < best_d then
          best, best_d = spider, d
        end
      end
    end
    return best
  end

  for player_index, slots in pairs(captured) do
    local player = game.get_player(player_index)
    if player and player.valid and player.connected then
      -- Rewrite each saved quickbar remote slot to the clones, using the
      -- per-slot captured selection (each remote is its own squad). The filter
      -- must be written back with an explicit quality: without one the engine
      -- does not treat it as a simple filter and aborts when the slot is
      -- picked (QuickBarSlotLogic assert, SIGABRT).
      local rewritten = 0
      for _, slot_data in ipairs(slots) do
        local selection = {}
        for _, spider in ipairs(slot_data.keep or {}) do
          if spider.valid then selection[#selection + 1] = spider end
        end
        for _, r in ipairs(slot_data.rel) do
          local c = find_clone(r)
          if c then selection[#selection + 1] = c end
        end
        if #selection > 0 then
          local filter = slot_data.filter or {name = "spidertron-remote"}
          filter.quality = filter.quality or "normal"
          local ok, err = pcall(function()
            player.set_quick_bar_slot(slot_data.page, slot_data.slot, {
              type = "remote",
              filter = filter,
              selection = selection,
            })
          end)
          if ok then
            rewritten = rewritten + 1
          else
            log("[warptorio] quickbar remote rewrite failed: " .. tostring(err))
          end
        end
      end
      log("[warptorio] spidertron relink: player " .. player_index .. " slots " .. #slots .. " (" .. rewritten .. " rewritten) on " .. target)
    end
  end
end

local function teleport_ground(source, target)
  local level = storage.warptorio.ground_level or 0

  if level == 0 then return end

  local source_obj = game.surfaces[source]
  local target_obj = game.surfaces[target]
  if not source_obj or not source_obj.valid or not target_obj or not target_obj.valid then return end

  local platform = warp_settings.floor.levels[level]
  local source_offset = get_surface_offset(source)
  local dest_offset = get_surface_offset(target)
  local destination_area = translate_surface_area(target, nil, platform)

  -- Basic is generated time to set it as main surface
  --storage.warptorio.warp_zone = target

  -- Build the brush from the actual ground floor shape so the corners are not teleported.
  -- The relative shape is cached; only the absolute positions are rebuilt per surface.
  local positions = shape_positions(warp_settings.floor.shape, platform * 2)
  local source_ox = source_offset.x
  local source_oy = source_offset.y
  local source_positions = {}
  for i = 1, #positions do
    local p = positions[i]
    source_positions[i] = {p[1] + source_ox, p[2] + source_oy}
  end

  local captured_modes = train_code.capture_clone_states(game.surfaces[source], source_offset)
  local captured_spidertrons = capture_spidertron_selections(source, source_offset)

  train_code.freeze_ground_bound_trains(source)

  -- Teleport base part
  game.surfaces[source].clone_brush({
    source_offset={source_offset.x, source_offset.y},
    destination_offset={dest_offset.x, dest_offset.y},
    source_positions=source_positions,
    destination_surface=target,
    expand_map=true,
    clone_tiles=true,
    clone_entities=true,
    clear_destination_entities=true,
    clear_destination_decoratives=true,
    clone_decoratives=false,
  })

  train_code.restore_clone_states(game.surfaces[target], dest_offset, captured_modes)
  clean_ground_tiles(target, destination_area)
  -- Delete teleported(generated) characters
  local surface_player_list = game.surfaces[target].find_entities_filtered{type="character", area = destination_area}
  for i,v in ipairs(surface_player_list) do
    v.destroy({raise_destroy=true})
  end

  --Regenerate belts and power

  return captured_spidertrons
end



local function create_space_platform()
  local platform_name = "harvester"
  game.forces["player"].create_space_platform({name=platform_name,planet="nauvis",starter_pack="space-platform-starter-pack"})
  for i,v in ipairs(game.forces["player"].platforms) do
    if v.name == platform_name then
      v.apply_starter_pack()
    end
  end
end

local clear_warp_countdown

local function next_warp_zone_prepare(forced, go_home)
    --if true then return end
    storage.warptorio.teleporting = true
    clear_warp_countdown()
    if not storage.warporio then storage.warporio = {} end
    if not storage.warporio.index then storage.warporio.index = 0 end
    
    if storage.warptorio.container and storage.warptorio.container.destroy() then
       local player = game.players[1]
       if player and player.connected then
          speech_bubbles.notify(player, {"warptorio.container-removed"}, 3)
       end
       storage.warptorio.container = nil
    end

    -- fix research if someone is trying to cheat
    if game.forces["player"].technologies[shared.techs.end_prepare].saved_progress > 0 and game.forces["player"].technologies[shared.techs.end_prepare].researched == false then
      game.print({"warptorio.technology-cheater"})
      game.forces["player"].technologies[shared.techs.end_prepare].saved_progress = 0
    end

    if game.forces["player"].technologies[shared.techs.end_win].saved_progress > 0 and game.forces["player"].technologies[shared.techs.end_win].researched == false then
      game.print({"warptorio.technology-cheater"})
      game.forces["player"].technologies[shared.techs.end_win].saved_progress = 0
    end

    if technology_check() then
      game.forces["player"].research_progress = 0
    end

    storage.warporio.index = storage.warporio.index + 1
    storage.warptorio.time_passed = 0
    local name = "warpzone_"..storage.warporio.index
    local surface = nil
    if forced == "nauvis" then
       if go_home then
          surface = new_random_surface("home")
       else
          storage.warptorio.previous_surface_2 = nil
          storage.warptorio.previous_surface_1 = nil
          surface = new_random_surface(name)
       end
    elseif forced == "space" then
       surface = new_random_surface("space")
       storage.warptorio.previous_surface_2 = nil
       storage.warptorio.previous_surface_1 = nil
    elseif forced then
       storage.warptorio.planet_next = forced
       storage.warptorio.previous_surface_2 = nil
       storage.warptorio.previous_surface_1 = nil
       surface = new_random_surface(name)
    else
       local num = math.random()
       if num < warp_settings.stuck_in_space_chance and not game.surfaces["space"] then
          surface = new_random_surface("space")
          storage.warptorio.previous_surface_2 = nil
          storage.warptorio.previous_surface_1 = nil
       elseif num > 1-warp_settings.going_home_chance and
          storage.warptorio.surface_name ~= "nauvis" and
          storage.warptorio.warp_next ~= "nauvis" and
          storage.warptorio.void ~= true then
          surface = new_random_surface("home")
          storage.warptorio.previous_surface_2 = nil
          storage.warptorio.previous_surface_1 = nil
       else
          surface = new_random_surface(name)
       end
    end
    prepare_surface_spawn(surface, name, not storage.warptorio.void)
    storage.warptorio.previous_surface_wave = storage.warptorio.wave_index
    storage.warptorio.previous_surface_time = storage.warptorio.wave_time
    events.raise(shared.events.warp_started, {
       from_surface = storage.warptorio.surface_name,
       target = surface and surface.name,
       planet = storage.warptorio.planet_next,
       index = storage.warporio.index,
       forced = forced,
    })
end

local function next_warp_zone_finish()
   local name = storage.warptorio.warp_next
   --local name = storage.warptorio.space
   local surface = game.surfaces[name]
   local keep_time = false
   --game.print((storage.warptorio.previous_surface_2 or "none") .. " | " .. storage.warptorio.surface_name )
   if storage.warptorio.previous_surface_2 == storage.warptorio.surface_name and
      storage.warptorio.surface_name ~= "nauvis" and
      storage.warptorio.surface_name ~= nil then
      keep_time = true
      game.print({"warptorio.hopping-surfaces"},{color={1,0.25,0.25}})
   end
   storage.warptorio.previous_surface_2 = storage.warptorio.previous_surface_1
   storage.warptorio.previous_surface_1 = storage.warptorio.surface_name
    surface.force_generate_chunk_requests()
    --game.print("New warpzone created")
    local source = nil
    if storage.warptorio.force_direct then
       source = storage.warptorio.warp_zone
    elseif storage.warptorio.factory_level >= warp_settings.space.trigger_factory_level and
       warp_settings.space.transition then
       source = "warp-space-transition"
    else
       source = storage.warptorio.warp_zone
    end
    if source == nil then
       game.print("ERORR:Source planet is nil. Something went wrong")
       source = storage.warptorio.warp_zone
    end
    --storage.warptorio.warp_next = name
    remove_resources(source)
    if warp_settings.reset_recipe then
       remove_recipes(source)
    end
    local source_surface_obj = game.surfaces[source]
    if source_surface_obj and source_surface_obj.valid then
       for _, c in pairs(source_surface_obj.find_entities_filtered{name=shared.container}) do
          if c.valid then c.destroy() end
       end
    end
    storage.warptorio.container = nil
    local captured_spidertrons = teleport_ground(source,name)
    --player_teleport.teleport_players(source,name,true)
    if storage.warptorio.factory_level > 0 then
       player_teleport.teleport_players(source,"factory",true)
    else
       player_teleport.teleport_players(source,name)
    end
    restore_spidertron_selections(name, captured_spidertrons)
    if storage.warptorio.factory_level > 0 then
      refresh_power_and_teleport(name)
    end
    -- New floor is live; release trains frozen for the clone.
    train_code.resume_ground_bound_trains()
    
    storage.warptorio.wave_index = 0
    storage.warptorio.wave_time = warp_settings.biter.time
    -- Fresh warp: allow the next boss alert.
    storage.warptorio.boss_spawned_warp = nil
    if keep_time then
       storage.warptorio.wave_index = storage.warptorio.previous_surface_wave or 0
       storage.warptorio.wave_time = storage.warptorio.previous_surface_time or warp_settings.biter.time
    end
    local extra_time = false
    for i,v in ipairs(warp_settings.biter.extra_time_planet) do
      if v == storage.warptorio.surface_name then
        extra_time = true
      end
    end
    if extra_time then storage.warptorio.wave_time = storage.warptorio.wave_time + warp_settings.biter.extra_time_amount end
    create_void_platform(source,true)
    if storage.warptorio.old_surface and game.surfaces[storage.warptorio.old_surface] and game.surfaces[storage.warptorio.old_surface].valid then
      compat_repair_turret.destroy_before_clear(game.surfaces[storage.warptorio.old_surface])
      game.delete_surface(storage.warptorio.old_surface)
    end
    storage.warptorio.old_surface = storage.warptorio.warp_zone
    if storage.warptorio.surface_name == "aquilo" then
      storage.warptorio.warp_out = warp_settings.time.warp_out
    else
      storage.warptorio.warp_out = warp_settings.time.warp_out+storage.warporio.index*warp_settings.time.add_per_jump
    end

    local players = game.players
    for i,v in pairs(players) do
      for _, inv_id in pairs({defines.inventory.character_main, defines.inventory.character_trash}) do
        local inventory = v.get_inventory(inv_id)
        if inventory then
          for j = 1, #inventory do
            local stack = inventory[j]
            if stack.valid_for_read and stack.name == shared.container then
              stack.clear()
            end
          end
        end
      end
    end
    pollution_settings()
    game.forces["enemy"].set_evolution_factor(get_evolution_factor(),name)
    
    if script.active_mods["rso-mod"] then
       remote.call("RSO", "resetGeneration", surface)
    end

    storage.warptorio.warp_zone = surface.name
    local spawn = get_surface_offset(surface.name)
    game.forces.player.set_spawn_position({x=spawn.x,y=spawn.y+2}, surface)

    if game.forces.player.technologies["warp-biochamber-platform-1"].researched then
       update_belt_biochamber()
    end
    update_belt()
    if storage.warptorio.factory_level > 0 then
       refresh_power_and_teleport()
    end
    minimap.chart(name)
   if storage.warptorio.factory_level >= warp_settings.space.trigger_factory_level and
      warp_settings.space.transition then
      game.play_sound({path="warp-end"})
    else
      game.play_sound({path="warp-start"})
    end
   storage.warptorio.teleporting = false
   clear_transition_asteroids()
   platform_code.on_warp(source,name)
   warp_constant_combinator.rescan()
   events.raise(shared.events.warp_finished, {
      surface = name,
      previous_surface = storage.warptorio.previous_surface_1,
      planet = storage.warptorio.planet_next,
      index = storage.warporio.index,
      factory_level = storage.warptorio.factory_level,
   })
end

local function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

local function getPointAndVector(centerX, centerY, distance)
    local angle = math.random() * 2 * math.pi
    local px = centerX + distance * math.cos(angle)
    local py = centerY + distance * math.sin(angle)
    local vectorBackX = centerX - px
    local vectorBackY = centerY - py
    return {position={x=px, y=py}, movement={x=vectorBackX, y=vectorBackY}}
end

local function next_warp_zone_space()
   local source = storage.warptorio.warp_zone
   local dest = "warp-space-transition"

   if not game.surfaces[dest] then
      local surface = game.create_surface(dest,space_gen_settings)
      surface.always_day = true
      surface.request_to_generate_chunks({0,0}, 10)
      surface.force_generate_chunk_requests()
   end

   create_void_platform(dest,true,"empty-space")

   local space_source_surface = game.surfaces[source]
   if space_source_surface and space_source_surface.valid then
      for _, c in pairs(space_source_surface.find_entities_filtered{name=shared.container}) do
         if c.valid then c.destroy() end
      end
   end
   storage.warptorio.container = nil
   local captured_spidertrons = teleport_ground(source,dest)
   -- Cloning the ground floor invalidates the combinators standing on it, so pick up
   -- the clones straight away. Without this they stop updating for the whole
   -- transition, which is exactly when signal-J / signal-D are worth reading.
   warp_constant_combinator.rescan()
   player_teleport.teleport_players(source,"factory",true)
   restore_spidertron_selections(dest, captured_spidertrons)
   --set_hidden_tiles(dest,"empty-space")
   create_void_platform(source,true)

   local save = storage.warptorio.warp_zone
   storage.warptorio.warp_zone = dest
   refresh_power_and_teleport(dest)
   train_code.resume_ground_bound_trains()
   update_belt()
   storage.warptorio.warp_zone = save

   --[[
   local text = {"warptorio.teleport-text"}
   rendering.draw_text{
      surface="factory",
      text=text,scale=2,
      target={x=0,y=0},
      color={1,0,0},
      time_to_live=storage.warptorio.transition_timer
      }
   ]]
   game.play_sound({path="warp-start"})
end

local function next_warp_zone_transition()
   if storage.warptorio.transition_timer < 60 then
      return
   end
   local dest = "warp-space-transition"
   if storage.warptorio.transition_timer % (60*warp_settings.space.transition_spawn_timer) == 0 then
      create_asteroids(warp_settings.space.transition_spawn_amount,dest)
   end
   --[[local rand = math.random(0,warp_settings.space.asteroid_chance)
   local dest = storage.warptorio.space
   local level = storage.warptorio.ground_level
   local size = warp_settings.floor.levels[level]
   if rand < 2 then
        local evolution = game.forces["enemy"].get_evolution_factor(storage.warptorio.warp_zone)
        for i,v in ipairs(warp_settings.biter.tresholds) do
           if v < evolution then
              local x = math.random(-size,size)
              local index = math.random(1,#warp_settings.space.asteroids[i])
              local asteroid = warp_settings.space.asteroids[i][index]
              game.surfaces[dest].create_entity{name=asteroid,position={x,-size*1.5},force="enemy"}
           end
        end
      end]]
end

local function force_warp(destination, go_home)
   if destination and destination ~= "nauvis" and destination ~= "void" and destination ~= "space"
      and not game.planets[destination] then
      game.print("ERORR:Unknown force warp destination: "..tostring(destination))
      return
   end
   if destination == "space" and game.surfaces["space"] and game.surfaces["space"].valid then
      game.print("ERORR:Cannot warp to space: space surface already exists")
      return
   end
   storage.warptorio.warp_out = 0
   storage.warptorio.transition_timer = 0
   storage.warptorio.force_direct = true
   storage.warptorio.clicks_to_teleport = {}
   next_warp_zone_prepare(destination, go_home)
   storage.warptorio.transition_timer = -1
   next_warp_zone_finish()
   storage.warptorio.force_direct = nil
end

local function next_warp_zone()
   if storage.warptorio.game_over then return end
   log("[warpcheat] next_warp_zone called")
   storage.warptorio.clicks_to_teleport = {}
   next_warp_zone_prepare()
   if storage.warptorio.factory_level >= warp_settings.space.trigger_factory_level and
      warp_settings.space.transition then
      storage.warptorio.transition_timer = math.floor(
         60*warp_settings.space.time_per_warp*storage.warporio.index)
      next_warp_zone_space()
      return
   end
   storage.warptorio.transition_timer = warp_settings.space.base_time
end

function clear_warp_countdown()
   local renders = storage.warptorio.warp_countdown_renders
   if renders then
      for _, render in pairs(renders) do
         if render and render.valid then render.destroy() end
      end
   end
   storage.warptorio.warp_countdown_renders = {}
   storage.warptorio.warp_countdown_end = nil
   storage.warptorio.warp_countdown_shown = nil
end

-- Hooks the vote result: once enough players have voted, give everyone a few
-- seconds of warning before the warp actually starts.
local function start_warp_countdown()
   if storage.warptorio.teleporting or storage.warptorio.warp_countdown_end then return end
   storage.warptorio.warp_countdown_end = game.tick + warp_settings.time.warp_countdown_seconds * 60
   storage.warptorio.warp_countdown_shown = nil
   game.print({"warptorio.warp-countdown-started", warp_settings.time.warp_countdown_seconds})
end

local function update_warp_countdown()
   local end_tick = storage.warptorio.warp_countdown_end
   if not end_tick then return end
   if storage.warptorio.teleporting then
      clear_warp_countdown()
      return
   end
   local remaining = end_tick - game.tick
   if remaining <= 0 then
      clear_warp_countdown()
      next_warp_zone()
      return
   end
   local seconds = math.ceil(remaining / 60)
   if seconds == storage.warptorio.warp_countdown_shown then return end
   storage.warptorio.warp_countdown_shown = seconds

   local floors = {"factory"}
   local ground_surface = game.surfaces[storage.warptorio.warp_zone]
   if ground_surface and ground_surface.valid then
      floors[#floors+1] = ground_surface.name
   end
   local garden_surface = game.surfaces["garden"]
   if garden_surface and garden_surface.valid then
      floors[#floors+1] = "garden"
   end

   local renders = storage.warptorio.warp_countdown_renders
   if not renders then
      renders = {}
      storage.warptorio.warp_countdown_renders = renders
   end
   local active = {}
   local text = {"warptorio.warp-countdown", seconds}
   for _, surface_name in ipairs(floors) do
      local render = renders[surface_name]
      if render and render.valid then
         render.text = text
      else
         render = rendering.draw_text{
            surface = surface_name,
            text = text,
            target = translate_surface_position(surface_name, {x = 0, y = 0}),
            scale = 3,
            color = {1, 0.65, 0.2},
            alignment = "center",
         }
         renders[surface_name] = render
      end
      active[surface_name] = true
   end
   for surface_name, render in pairs(renders) do
      if not active[surface_name] and render and render.valid then
         render.destroy()
         renders[surface_name] = nil
      end
   end
end

--[[local function get_surfaces(trigger,index)
   local surfaces = {}
   if index > 1 and not game.forces.player.technologies[trigger].researched then
      return surfaces
   end
   if #warp_settings.surfaces[index].triggers == 0 then
      for i,v in ipairs(warp_settings.surfaces[index].names) do
         if game.forces.player.technologies["planet-discovery-"..v] and
            game.forces.player.technologies["planet-discovery-"..v].researched == false then
            game.forces.player.technologies["planet-discovery-"..v].researched = true
         end
      end
      return warp_settings.surfaces[index].names
   end
   for i,v in ipairs(warp_settings.surfaces[index].triggers) do
      if game.forces.player.technologies[v].researched then
         table.insert(surfaces,warp_settings.surfaces[index].names[i])
      end
   end
   return surfaces
end

local function get_all_surfaces()
   local t = {
      "none",warp_settings.trigger_research,warp_settings.trigger_space,warp_settings.trigger_end}
   local surfaces = {}
   for i,v in ipairs(t) do
      for _,name in ipairs(get_surfaces(v,i)) do
         if game.forces.player.is_space_location_unlocked(name) then
            table.insert(surfaces,name)
         end
      end
   end
   return surfaces
   end]]

local function roll_planet()
   local surfaces = {}

  -- Insert extra nauvis to improve chances
  table.insert(surfaces,"nauvis")

  -- Block other planets if we do not have blue science researched
  if game.forces["player"].technologies[warp_settings.trigger_research].researched then
    -- unlock planet science so we can do something there
    --[[for i,v in pairs(game.players[1].force.technologies) do
      local parts = mysplit(i,"-")
      if #parts == 3 and parts[1] == "planet" and parts[2] == "discovery" then
        v.researched = true
      end
       end]]
    for i,v in pairs(game.planets) do
       if game.forces.player.is_space_location_unlocked(i) and i ~= storage.warptorio.surface_name and not (i:match('.*%-factory%-floor') or i:match('factory%s-travel%s-surface')) then
          table.insert(surfaces,i)
       end
    end
  end

  local surface_name = surfaces[math.random(1,#surfaces)]

  if surface_name == "nauvis" and storage.warptorio.void ~= true then
    local r = math.random()
    if r > 0.75 then
      surface_name = "void"
    end
  end

  if game.forces["player"].technologies[shared.techs.end_prepare].researched then
     local r = math.random()
     if storage.warptorio.travel_to_edge then
        storage.warptorio.travel_to_edge = false
     elseif r < warp_settings.space.edge_chance then
        storage.warptorio.travel_to_edge = true
     end
  end
  
  storage.warptorio.planet_next = surface_name
  if game.forces["player"].technologies[warp_settings.trigger_research].researched then
     local sound = defines.print_sound.always
       if warp_settings.next_planet_text then
         local planet = storage.warptorio.planet_next
         if planet == "void" then
           game.print({"warptorio.next-planet-void"}, {volume_modifier=0})
         else
           game.print({"warptorio.next-planet", planet}, {volume_modifier=0})
         end
       end
     if warp_settings.next_planet_sound then
        game.play_sound({path="planet-change",volume_modifier=0.5})
     end
  end
  events.raise(shared.events.planet_chosen, {
     planet = surface_name,
     index = storage.warporio.index,
  })

end

local function battery_check(index)
   return storage.warptorio.power[index] and storage.warptorio.power[index].valid
end

local function on_tick_power()
  if storage.warptorio.power then
     if battery_check(2) and battery_check(1) then
      local ave = average(storage.warptorio.power[2].energy,storage.warptorio.power[1].energy)
      if battery_check(3) then
        ave = (storage.warptorio.power[1].energy + storage.warptorio.power[2].energy + storage.warptorio.power[3].energy)/3
      end
      storage.warptorio.power[1].energy = ave
      storage.warptorio.power[2].energy = ave
      if battery_check(3) then
        storage.warptorio.power[3].energy = ave
      end
    end
  end
end

local function update_nauvis_timer()
   if warp_settings.nauvis_timer <= 0 then return end
   if not storage.warporio or (storage.warporio.index or 0) > 0 then return end
   if storage.warptorio.warp_zone ~= "nauvis" then
      if storage.warptorio.nauvis_timer_render and storage.warptorio.nauvis_timer_render.valid then
         storage.warptorio.nauvis_timer_render.destroy()
      end
      storage.warptorio.nauvis_timer_render = nil
      storage.warptorio.nauvis_force_warp_warned = nil
      return
   end
   if platform_animation.is_active() then
      return
   end

   if not storage.warptorio.nauvis_timer_remaining then
      storage.warptorio.nauvis_timer_remaining = warp_settings.nauvis_timer
   end

   storage.warptorio.nauvis_timer_remaining = storage.warptorio.nauvis_timer_remaining - 1
   local remaining = storage.warptorio.nauvis_timer_remaining

   if remaining <= 60 * 60 and not storage.warptorio.nauvis_force_warp_warned then
      storage.warptorio.nauvis_force_warp_warned = true
      game.print({"warptorio.nauvis-force-warp-warning"})
   end

   local color
   if remaining <= 60 * 60 then
      color = {1, 0, 0}
   elseif remaining <= 60 * 60 * 5 then
      color = {1, 0.5, 0}
   else
      color = {1, 1, 0}
   end

   if remaining % 60 == 0 or not (storage.warptorio.nauvis_timer_render and storage.warptorio.nauvis_timer_render.valid) then
      local secs = math.max(math.ceil(remaining / 60), 0)
      local text = string.format("%d:%02d", math.floor(secs / 60), secs % 60)
      if storage.warptorio.nauvis_timer_render and storage.warptorio.nauvis_timer_render.valid then
         storage.warptorio.nauvis_timer_render.text = text
         storage.warptorio.nauvis_timer_render.color = color
      else
         storage.warptorio.nauvis_timer_render = rendering.draw_text{
            surface = "nauvis",
            text = text,
            scale = 4,
            target = {x=0, y=-6},
            color = color,
            alignment = "center",
         }
      end
   end

   if remaining <= 0 then
      if storage.warptorio.nauvis_timer_render and storage.warptorio.nauvis_timer_render.valid then
         storage.warptorio.nauvis_timer_render.destroy()
      end
      storage.warptorio.nauvis_timer_render = nil
      storage.warptorio.nauvis_timer_remaining = nil
      storage.warptorio.nauvis_force_warp_warned = nil
      if not storage.warptorio.warp_countdown_end then
         next_warp_zone()
      end
   end
end

local function trigger_game_over()
if storage.warptorio.game_over then return end
    storage.warptorio.game_over = true
    game.print({"warptorio.capacitor-destroyed"})
    game.set_lose_ending_info{title={"warptorio.lose-screen-title"}, message={"warptorio.lose-screen-text"}}
    game.set_game_state{game_finished=true, player_won=false, can_continue=true}
    events.raise(shared.events.game_over, {
       surface = storage.warptorio.warp_zone,
       index = storage.warporio.index,
    })
end
script.on_event(defines.events.on_tick, function(event)
if not storage.warporio then
     on_init_or_load()
     return
  end
if storage.warptorio.game_over then return end
  if storage.warptorio.power and storage.warptorio.power[1] and not storage.warptorio.power[1].valid and not storage.warptorio.teleporting then
     trigger_game_over()
     return
  end
  if storage.warptorio.welcome_dialog_tick then
     local player = game.players[1]
     if player and player.connected then
        local playing = player.controller_type == defines.controllers.character
        if playing and event.tick >= storage.warptorio.welcome_dialog_tick then
           storage.warptorio.welcome_dialog_tick = nil
           if game.is_multiplayer() then
              player.print({"warptorio.start-welcome", warp_settings.trigger_wave})
           else
              game.show_message_dialog{text = {"warptorio.start-welcome", warp_settings.trigger_wave}}
           end
        end
     end
  end
  if event.tick % 60 == 0 then
    train_code.retry_pending_warps()
  end
  if event.tick % 10 == 0 then
    boss_system.update()
  end
  train_code.on_tick(event.tick)
  for i,v in ipairs(warp_settings.blocked_planets) do
    if v == storage.warptorio.surface_name and technology_check() then
      game.forces["player"].research_progress = 0
    end
  end
  if storage.warptorio.teleporting then
    if storage.warptorio.paused_research == nil and research_pause.ground_research_active() then
      research_pause.pause()
    end
    if technology_check() then
      game.forces["player"].research_progress = 0
    end
  elseif storage.warptorio.paused_research ~= nil then
    research_pause.resume()
  end
  if not storage.warptorio.transition_timer then storage.warptorio.transition_timer = -1 end
  gui_state.update_all_labels()
  update_nauvis_timer()
  platform_code.on_tick()
  power_tick.flush_pending_reconnect()
  on_tick_power()
  platform_animation.on_tick()
  storage.warptorio.platform_animation_active = platform_animation.is_active()
  update_warp_countdown()

  if storage.warptorio.transition_timer > 0 then
     storage.warptorio.transition_timer = storage.warptorio.transition_timer - 1
     next_warp_zone_transition()
     -- Drain the destination's pending chunk generation a couple ticks before
     -- landing so the finish tick's force_generate_chunk_requests has nothing left.
     -- next_warp_zone_transition early-returns below 60, so this can't live there.
     if storage.warptorio.transition_timer == 2 then
        local dest_surface = game.surfaces[storage.warptorio.warp_next]
        if dest_surface and dest_surface.valid then
           dest_surface.force_generate_chunk_requests()
        end
     end
     --return
  elseif storage.warptorio.transition_timer == 0 then
     next_warp_zone_finish()
     storage.warptorio.transition_timer = -1
     --return
  elseif storage.warptorio.transition_timer > -warp_settings.time.extra_transition_time*60 then
     storage.warptorio.transition_timer = storage.warptorio.transition_timer - 1
  end
  if storage.warptorio.ground_level > 0 or
      storage.warporio.index > 0 then
    if not technology_check() and not storage.warptorio.platform_animation_active then
      storage.warptorio.time_passed = storage.warptorio.time_passed + 1/60
    end
    if storage.warptorio.warp_out > 0 then
      if not storage.warptorio.platform_animation_active then
        storage.warptorio.warp_out = storage.warptorio.warp_out - 1/60
      end
    else
      storage.warptorio.warp_out = 0
    end
  end
  local in_transition_period = storage.warptorio.transition_timer > -warp_settings.time.extra_transition_time*60
  if not storage.warptorio.planet_timer then storage.warptorio.planet_timer = 0
  elseif storage.warptorio.warp_out <= 0 and not in_transition_period and not storage.warptorio.platform_animation_active then
    storage.warptorio.planet_timer = storage.warptorio.planet_timer + 1/60

    if storage.warptorio.planet_timer > warp_settings.planet_timer or storage.warptorio.planet_next == nil
        or (storage.warptorio.planet_next == storage.warptorio.warp_zone and storage.warptorio.planet_next ~= "nauvis") then
      storage.warptorio.planet_timer = 0
      roll_planet()
    end
  else
    if storage.warptorio.warp_out > 0 then
      storage.warptorio.planet_timer = warp_settings.planet_timer
    end
  end
  local time_limit = warp_settings.time.round + (warp_settings.time.round*storage.warptorio.time_level)
  if storage.warptorio.time_limit_warned and storage.warptorio.time_passed < time_limit - 60 then
    storage.warptorio.time_limit_warned = nil
  end
  if not storage.warptorio.time_limit_warned and storage.warptorio.time_passed >= time_limit - 60 then
    storage.warptorio.time_limit_warned = true
    game.print({"warptorio.time-limit-warning"})
  end
  if not storage.warptorio.warp_countdown_end and storage.warptorio.time_passed > time_limit then
    next_warp_zone()
  end
  if game.surfaces[storage.warptorio.warp_zone] and
     storage.warptorio.time_passed > warp_settings.polution.time and
     storage.warptorio.warp_zone ~= "nauvis" then
    local pollution_target = translate_surface_position(storage.warptorio.warp_zone, {x=0, y=0})
    game.surfaces[storage.warptorio.warp_zone].pollute(pollution_target, warp_settings.polution.amount)
  end
  --if storage.warptorio.surface_name ~= nil and storage.warptorio.warp_zone ~= "nauvis" then
  --  local factor = storage.warptorio.time_passed/warp_settings.time.limit
  --  factor = factor > 1 and 1 or factor
  --  game.forces["enemy"].set_evolution_factor(factor*100,storage.warptorio.warp_zone)
  --end
  check_wave()
  warp_constant_combinator.refresh()
  --local tran_timer = (warp_settings.time.extra_transition_time*60)-1
  --if storage.warptorio.teleporting or storage.warptorio.transition_timer > -tran_timer then
  --   return
  --end
  local players = game.players
  local dest = storage.warptorio.warp_zone
  if storage.warptorio.teleporting then
     dest = "warp-space-transition"
  end
   for i,v in pairs(players) do
      minimap.sync(v)
   end
   if minimap_needs_reposition then
      minimap_needs_reposition = false
   end
  for i,v in pairs(players) do
    -- If player steps into teleport zone, teleport them
    if v.is_player() and v.connected and v.character and v.physical_controller_type == defines.controllers.character then
      local warp_zone = dest
      for _, pad in pairs(warp_settings.teleporters) do
        if not pad.biochamber or storage.warptorio.biochamber_level then
          local source = pad.surface == "$warp_zone" and warp_zone or pad.surface
          local destination = pad.destination == "$warp_zone" and warp_zone or pad.destination
          player_teleport.check_teleport(v,
            {x = pad.position.x, y = pad.position.y, surface = source},
            destination,
            pad.box)
        end
      end
    end
  end
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)

    if event.player_index == 1 and not storage.warptorio.start_message_shown then
       storage.warptorio.start_message_shown = true
       storage.warptorio.welcome_dialog_tick = game.tick + 60
    end

    gui_state.warp_gui(player)
    --local warp_gui = screen_element.add{type="label", name="greeting", caption="Hi"}
	  --[[screen_element.add{type = "label", name = "time_passed_label", caption = {"time-passed-label", "-"}}
	  screen_element.add{type = "label", name = "number_of_warps_label", caption = {"number-of-warps-label", "-"}}
    screen_element.add{type = "label", name = "number_of_waves_time", caption = {"number-of-waves-time", "-"}}
    screen_element.add{type = "label", name = "number_of_waves_amount", caption = {"number-of-waves-amount", "-"}}
    screen_element.add{type = "label", name = "time_to_warp", caption = {"time_to_warp", "-"}}
       screen_element.add{type = "button", name="warp_planet", caption={"warptorio.button-warp"}}]]
    --screen_element.add{type = "button", name="warp_planet", caption={"button-warp"}}

    
end)

script.on_event(defines.events.on_gui_click, function(event)
    if minimap.on_click(event) then return end
    if not storage.warptorio.clicks_to_teleport then
       storage.warptorio.clicks_to_teleport = {}
    end
local element_name = (event.element and event.element.valid) and event.element.name or nil
    if warpcheat then warpcheat.handle_click(event) end
    if element_name == "warp_planet" then
        if storage.warptorio.game_over then
           game.print({"warptorio.capacitor-destroyed"})
           return
        end
        if storage.warptorio.teleporting then
           speech_bubbles.notify(game.players[event.player_index], {"warptorio.warp_in_progress"}, 3)
           return
        end
       if storage.warptorio.ground_level == 0 then
          local capacitor = storage.warptorio.power and storage.warptorio.power[1]
          local target = (capacitor and capacitor.valid) and capacitor or nil
          local player = game.players[event.player_index]
          if not target and player and player.character and player.character.valid then
             target = player.character
          end
          if target then
             speech_bubbles.speak(target, {"warptorio.warp-not-available"}, 5)
          else
             game.print({"warptorio.warp-not-available"})
          end
          return
       end
if storage.warptorio.warp_out > 0 then
           speech_bubbles.notify(game.players[event.player_index], {"warptorio.cooling-down"}, 3)
           return
        end
        if technology_check() then
           speech_bubbles.notify(game.players[event.player_index], {"warptorio.technology-check"}, 4)
           return
        end
        if platform_animation.is_active() then
           speech_bubbles.notify(game.players[event.player_index], {"warptorio.platform-animation-in-progress"}, 4)
           return
        end

       local player = game.players[event.player_index]
       if player and player.admin and event.shift then
          if not storage.warptorio.admin_shift then
             storage.warptorio.admin_shift = {}
          end
          local last = storage.warptorio.admin_shift[event.player_index]
          if not last or (game.tick - last) > 60 then
             storage.warptorio.admin_shift[event.player_index] = game.tick
             return
          end
          storage.warptorio.admin_shift[event.player_index] = nil
          next_warp_zone()
          return
       end

       local result, arg1, arg2 = warp_vote.process_vote(event.player_index)
       if result == "afk" then
          game.print({"warptorio.afk-player-warp",arg1},{color={1,0,0}})
          return
       elseif result == "too_young" then
          game.print({"warptorio.new-player-warp",arg1},{color={1,0,0}})
          return
       elseif result == "already_voted" then
          speech_bubbles.notify(player, {"warptorio.already-voted"}, 3)
          return
       elseif result == "need_votes" then
           game.print({"warptorio.player-warp",arg1,arg2},{color={1,1,0}})
           return
        end

       start_warp_countdown()

    end
end)

local function update_time(e)
    --game.print("Time on planet extended")

    local e_level = mysplit(e,"-")
    local level = tonumber(e_level[#e_level])
   storage.warptorio.time_level = level
end

local function update_power(e)
    local e_level = mysplit(e,"-")
    local level = tonumber(e_level[#e_level])
    local new_name = shared.power[level+1]
    if not new_name then return end
    storage.warptorio.power_name = new_name
    power_tick.upgrade_power_capacitors(new_name)
end

local function build_entity(e)
   warp_constant_combinator.register(e.entity)
   if e.entity.type == "roboport" then
      local surface = e.entity.surface.name
      if (surface == "factory" and warp_settings.block_roboport_factory) or
         (surface == "garden" and warp_settings.block_roboport_garden) then
         if e.player_index then
            game.players[e.player_index].insert({name=e.entity.name, count=1, quality=e.entity.quality.name})
         end
         e.entity.destroy()
         if e.player_index then
            local player = game.players[e.player_index]
            if player.character and player.character.valid then
               speech_bubbles.speak(player.character, {"warptorio.roboport-blocked"}, 4)
            else
               player.print({"warptorio.roboport-blocked"},{color={1,0,0}})
            end
         end
         return
      end
   end
   if e.entity.name == shared.container then
       if storage.warptorio.container and storage.warptorio.container.valid then
          speech_bubbles.notify(e.player_index and game.players[e.player_index], {"warptorio.container-placed-error"}, 4, {1,0,0})
          e.entity.destroy()
          return
       else
          speech_bubbles.notify(e.player_index and game.players[e.player_index], {"warptorio.container-placed"}, 4)
       end
       storage.warptorio.container = e.entity
    end
    if e.entity.name == "warp-asteroid-chest" then
       if storage.warptorio.collector_chest and storage.warptorio.collector_chest.valid then
          speech_bubbles.notify(e.player_index and game.players[e.player_index], {"warptorio.collector-placed-error"}, 4, {1,0,0})
          e.entity.destroy()
          return
       elseif e.entity.surface.name ~= "factory" and e.entity.surface.name ~= "garden" then
          speech_bubbles.notify(e.player_index and game.players[e.player_index], {"warptorio.placed-error-surface"}, 4, {1,0,0})
          e.entity.destroy()
          return
       else
          speech_bubbles.notify(e.player_index and game.players[e.player_index], {"warptorio.collector-placed"}, 4)
          storage.warptorio.collector_chest = e.entity
       end
    end
    if e.entity.name == "biolab" then
       -- Base limit, raised by each level of the infinite biolab-limit research.
       local tech = game.forces.player.technologies[warp_settings.ground.biolab_research]
       local levels = tech.level-1
       local limit = warp_settings.ground.biolab_limit + warp_settings.ground.biolab_increase * levels
       -- Count includes the biolab that was just built, so going over rejects the new one.
       local count = #e.entity.surface.find_entities_filtered{name="biolab"}
       if count > limit then
          if e.player_index then
             game.players[e.player_index].insert({name=e.entity.name, count=1, quality=e.entity.quality.name})
          end
          e.entity.destroy()
          if e.player_index then
             game.players[e.player_index].print({"warptorio.biolab-limit-reached", limit},{color={1,0,0}})
          end
          return
       end
    end
end

local techs = {
   {
      name = warp_settings.techs.ground,
      func = update_ground_platform
   },
   {
      name = warp_settings.techs.factory,
      func = update_factory_platform
   },
   {
      name = warp_settings.techs.biochamber,
      func = update_biochamber_platform
   },
   {
      name = warp_settings.techs.reactor,
      func = update_reactor_platform
   },
   {
      name = warp_settings.techs.container_left,
      func = function ()
         --game.print("Container will be added after the teleport")
         storage.warptorio.container_left_enabled = true             
      end
   },
   {
      name = warp_settings.techs.power,
      func = update_power
   },
   {
      name = warp_settings.techs.time,
      func = update_time
   },
   {
      name = warp_settings.techs.belt,
      func = update_belt
   },
   {
      name = warp_settings.techs.win,
      func = function ()
         events.raise(shared.events.game_win, {
            index = storage.warporio.index,
            factory_level = storage.warptorio.factory_level,
         })
         game.set_win_ending_info{title={"warptorio.end-screen-title"}, message={"warptorio.end-screen-text"}}
         game.set_game_state{game_finished=true,player_won=true,can_continue=true}
      end
   },
    {
       name = "warptorio%-platform%-repair",
       func = function (name)
          update_ground_platform()
       end
    },   
}

script.on_event(defines.events["warptorio-warp-finished"], function()
  if storage.warptorio.pending_ground_platform_update == nil then
    return
  end
  local pending = storage.warptorio.pending_ground_platform_update
  storage.warptorio.pending_ground_platform_update = nil
  update_ground_platform(pending == true and nil or pending)
end)

script.on_event(defines.events.on_research_finished, function(e)
     platform_code.on_research(e)
     for _,v in ipairs(techs) do
        if string.find(e.research.name, v.name) then
           v.func(e.research.name)
           return
        end
     end
end)


script.on_event(defines.events.on_lua_shortcut, function(e)
    if e.prototype_name == shared.shortcut_teleport then
      --player_teleport.check_teleport(game.players[e.player_index],{x=-1,y=-2,surface=storage.warptorio.warp_zone},"factory")
      if storage.warptorio.factory_level > 0 then
         local player = game.players[e.player_index]
         if player_teleport.get_rideable_vehicle(player) then
            speech_bubbles.notify(player, {"warptorio.teleport-in-vehicle"}, 4)
         else
            local player_pos = game.surfaces["factory"].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
            local from_surface = player.character and player.character.surface or nil
            local from_position = player.character and player.character.position or nil
            player_teleport.teleport_body(player, player_pos, "factory")
            player_teleport.play_teleport_boom(game.surfaces["factory"], player_pos, player.index)
            player_teleport.teleport_effect(from_surface, from_position)
            player_teleport.teleport_effect(game.surfaces["factory"], player_pos)
         end
      else
         speech_bubbles.notify(game.players[e.player_index], {"warptorio.teleport-not-available"}, 4)
      end
    end
    if minimap.on_shortcut(e) then return end
end)

script.on_event(defines.events.on_player_respawned, function(event)
        --if game.players[event.player_index].character.surface ~= storage.warptorio.warp_zone then
  local spawn_center = translate_surface_position(storage.warptorio.warp_zone, {x=0, y=2.0})
  local surface = game.surfaces[storage.warptorio.warp_zone]
  local player_pos = surface and surface.find_non_colliding_position("character", spawn_center, 0, 0.5, false) or spawn_center
  player_teleport.teleport_body(game.players[event.player_index], player_pos, storage.warptorio.warp_zone)
  player_teleport.play_teleport_boom(surface, player_pos, event.player_index)
  player_teleport.teleport_effect(surface, player_pos)
        --end
end)

script.on_event(defines.events.on_built_entity, function(e)
  build_entity(e)
end)

script.on_event(defines.events.on_robot_built_entity, function(e)
  build_entity(e)
end)

script.on_event(defines.events.on_player_mined_entity, function(e)
    if e.entity.name == shared.container then
       speech_bubbles.notify(game.players[e.player_index], {"warptorio.container-removed"}, 3)
       storage.warptorio.container = nil
    end
    warp_constant_combinator.unregister(e.entity)
end)

script.on_event(defines.events.on_robot_mined_entity, function(e)
    if e.entity.name == shared.container then
       local player = game.players[1]
       if player and player.connected then
          speech_bubbles.notify(player, {"warptorio.container-removed"}, 3)
       end
       storage.warptorio.container = nil
    end
    warp_constant_combinator.unregister(e.entity)
end)

floor_garden.setup()

script.on_event(defines.events.on_research_started, function(e)
    local name = e.research.name
    research_pause.on_research_started(e.research)
    if string.match(name, "warp") then
      if string.match(name, "end") then
        for i,v in ipairs(warp_settings.blocked_planets) do
          if v == storage.warptorio.surface_name then
             game.print({"warptorio.research-wrong-planet"},{color={1,0,0}})
          end
        end
      end
    end
end)

script.on_event(defines.events.on_entity_spawned, function(event)
	replace_common(event.entity)
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
  if event.effect_id == "asteroid" then
     if event.source_entity then
        local name = event.source_entity.name
        local pos = event.source_entity.position
        if not pos then return end
        local tile = "empty-space"
        local explosion_size = 15
        local amount = 1
        if string.match(name, "small") then
           explosion_size = 5
        end
        if string.match(name, "medium") then
           explosion_size = 8
        end
        if string.match(name, "big") then
           explosion_size = 12
        end
        local tiles = generate_ellipse(explosion_size, explosion_size, tile,pos.x,pos.y)
        local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
        local size = warp_settings.floor.levels[level]
        local types = {"carbonic","metallic","oxide"}
        for _,i in ipairs(types) do
           if string.match(name, i) then
              if storage.warptorio.collector_chest then
                 local item = i.."-asteroid-chunk"
                 local container = storage.warptorio.collector_chest
                 if container and container.valid then
                    if container.can_insert({name=item, count=amount}) then
                       container.insert({name=item, count=amount})
                    end
                 end
              end
              break
           end
        end
        if pos.x < -(size+explosion_size) or pos.x > size+explosion_size or
           pos.y < -(size+explosion_size) or pos.y > size+explosion_size then
           return
        end
        game.surfaces[event.surface_index].set_tiles(tiles)
        game.surfaces[event.surface_index].create_entity{
           name="vulcanus-cliff-collapse",
           position=pos,}
     end
  end
end)

script.on_event(defines.events.on_player_joined_game, function(e)
  if e.player_index == 1 and game.forces["player"].technologies["automation"].researched == false then
     rendering.draw_text{
        surface="nauvis",
        text={"warptorio.help-text-1",warp_settings.trigger_wave},
        target={x=0, y=-3},
        color={0.6,1,0.6},
        scale=1.6,
        alignment="center",
        use_rich_text=true,
        time_to_live=60*5*60
     }
  end
  if e.player_index ~= 1 then
     if game.forces["player"].technologies["warp-factory-platform-1"].researched then
        local player_pos = game.surfaces["factory"].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
        player_teleport.teleport_body(game.players[e.player_index],  player_pos, "factory")
     elseif game.surfaces[storage.warptorio.warp_zone] then
        local spawn_center = translate_surface_position(storage.warptorio.warp_zone, {x=0, y=0})
        local surface = game.surfaces[storage.warptorio.warp_zone]
        local player_pos = surface.find_non_colliding_position("character", spawn_center, 0, 0.5, false) or spawn_center
player_teleport.teleport_body(game.players[e.player_index],  player_pos, storage.warptorio.warp_zone)
     end
   end
end)

script.on_event(defines.events.on_player_left_game, function(e)
   warp_vote.cleanup_player(e.player_index)
end)

script.on_configuration_changed(function()
  on_init_or_load()
  warp_constant_combinator.rescan()
end)

script.on_event(defines.events.script_raised_built, function(e)
  build_entity(e)
end)

script.on_event(defines.events.script_raised_revive, function(e)
  build_entity(e)
end)

local function is_protected_warp_entity(entity)
    if entity.name == shared.container then return true end
    if not storage.warptorio or not storage.warptorio.power then return false end
    if not storage.warptorio.power_unit_number then
        storage.warptorio.power_unit_number = {}
        for i, power_entity in pairs(storage.warptorio.power) do
            if power_entity and power_entity.valid then
                storage.warptorio.power_unit_number[i] = power_entity.unit_number
            end
        end
    end
    if entity.unit_number then
        for _, unit_number in pairs(storage.warptorio.power_unit_number) do
            if unit_number == entity.unit_number then return true end
        end
    end
    for _, power_entity in pairs(storage.warptorio.power) do
        if power_entity == entity then return true end
    end
    return false
end

script.on_event(defines.events.on_entity_damaged, function(e)
    if boss_system.on_damaged(e) then return end
    if e.force ~= game.forces.player then return end
    if e.entity.force ~= game.forces.player then return end
    if not is_protected_warp_entity(e.entity) then return end
    local ok, max_health = pcall(function() return e.entity.prototype.max_health end)
    if ok and max_health then
        e.entity.health = max_health
    else
        e.entity.health = e.entity.health + e.final_damage_amount
    end
end)

script.on_event(defines.events.on_entity_died, function(e)
    warp_constant_combinator.unregister(e.entity)
    if storage.warptorio and storage.warptorio.power_unit_number and e.entity.unit_number == storage.warptorio.power_unit_number[1] then
        trigger_game_over()
    end
    boss_system.on_boss_died(e.entity)
end)

script.on_event(defines.events.script_raised_destroy, function(e)
    warp_constant_combinator.unregister(e.entity)
    boss_system.unregister(e.entity)
end)


commands.add_command("warptorio-set-warp-amount", "Set the current warp count (debug). Usage: /warptorio-set-warp-amount <number>", function(cmd)
  if not game.players[cmd.player_index].admin then
    game.players[cmd.player_index].print("Only admins can use this command.")
    return
  end
  local value = tonumber(cmd.parameter)
  if not value or value < 0 or math.floor(value) ~= value then
    game.players[cmd.player_index].print("Usage: /warptorio-set-warp-amount <non-negative integer>")
    return
  end
  if not storage.warporio then storage.warporio = {} end
  storage.warporio.index = value
  gui_state.update_label("amount", value)
  game.players[cmd.player_index].print("Warp amount set to " .. value)
end)

commands.add_command("warptorio-spawn-random-platform", "Spawn random platform", function(cmd)
  if not game.players[cmd.player_index].admin then
    game.players[cmd.player_index].print("Only admins can use this command.")
    return
  end
  platform_code.spawn_random()
end)

remote.add_interface("warptorio",
  {
     edit_planet_variants = function(variant,planet,map_gen_settings)
        if not map_gens.variant_list[variant] then
           table.insert(map_gens.variant_list,variant)
        end
        map_gens.planets[planet.."_"..variant] = map_gen_settings
     end,
     save_ground_platform_design = platform_code.save,
     spawn_ground_platform_design = platform_code.spawn,
     add_ground_platform_design = platform_code.add,
     list_ground_platform_design = platform_code.list,
     spawn_random_ground_platform_design = platform_code.spawn_random,
     -- Event names this mod raises via script.raise_event; subscribe with
     -- script.on_event(defines.events[name], handler). Values are also listed
     -- in shared.events in the mod source.
     get_events = function()
        local names = {}
        for _, name in pairs(shared.events) do
           names[#names + 1] = name
        end
        return names
     end,
  }
)
if warpcheat then
warpcheat.init({
  next_warp_zone = next_warp_zone,
  force_warp = force_warp,
  update_label = gui_state.update_label,
  teleport_body = player_teleport.teleport_body,
  translate_surface_position = translate_surface_position,
  update_ground_platform = update_ground_platform,
  map_variants = map_gens.variant_list,
  clean_ground_platform = function()
    local level = storage.warptorio.ground_level or 0
    local platform = warp_settings.floor.levels[level]
    if not platform then return false end
    clean_ground_tiles(storage.warptorio.warp_zone,
      translate_surface_area(storage.warptorio.warp_zone, nil, platform))
    return true
  end,
  platform_code = platform_code,
  teleporter_visualize = teleporter_visualize,
  spawn_boss_wave = function()
    if not storage.warptorio or not storage.warptorio.warp_zone then return 0 end
    if not game.surfaces[storage.warptorio.warp_zone] then return 0 end
    local biter_index = 1
    local evolution = game.forces["enemy"].get_evolution_factor(storage.warptorio.warp_zone)
    for i, v in ipairs(warp_settings.biter.tresholds) do
      if v < evolution then biter_index = i end
    end
    return spawn_boss_wave(biter_index, choose_quality(storage.warporio.index or 0))
  end,
})
end

minimap.init({
  translate_surface_position = translate_surface_position,
  minimap_needs_reposition = function() return minimap_needs_reposition end,
})

teleporter_visualize.init({
  get_warp_zone = function() return storage.warptorio.warp_zone end,
  translate_surface_position = translate_surface_position,
  teleporters = warp_settings.teleporters,
})

commands.add_command("warptorio-visualize-teleporters", "Toggle teleporter zone visualization (admin only)", function(cmd)
  if not cmd.player_index then return end
  local player = game.players[cmd.player_index]
  if not player.admin then
    player.print("Only admins can use this command.")
    return
  end
  teleporter_visualize.toggle(player)
end)
