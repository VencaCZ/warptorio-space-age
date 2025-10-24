--script.generate_event_name("on_warp")

local warp_settings = require("internal_settings")
local map_gens = require("map_gens")

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
                table.insert(tiles, create_tile("warp_tile_platform", x, y))
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
    local r_sqrt3_half = radius * sqrt3 / 2
    local offset_x = offset_x or 0
    local offset_y = offset_y or 0
    for y = -radius * sqrt3 / 2, radius * sqrt3 / 2 do
        for x = -radius, radius do
            if math.abs(y) <= r_sqrt3_half and
               math.abs(x) <= radius and
               sqrt3 * math.abs(x) + math.abs(y) <= 2 * radius then
                table.insert(tiles, create_tile(tile, x+offset_x, y+offset_y))
            end
        end
    end
    return tiles
end

-- Function to generate an ellipse
local function generate_ellipse(width, height,tile,offset_x,offset_y)
    local tiles = {}
    local half_width = math.floor(width / 2)
    local half_height = math.floor(height / 2)
    local offset_x = offset_x or 0
    local offset_y = offset_y or 0
    

    -- Iterate over integer coordinates to keep the shape centred on the tile grid.
    local min_y = math.ceil(-r_sqrt3_half)
    local max_y = math.floor(r_sqrt3_half)
    local min_x = -radius
    local max_x = radius - 1

    for y = min_y, max_y do
        local abs_y = math.abs(y)
        for x = min_x, max_x do
            local abs_x = math.abs(x)
            if abs_y <= r_sqrt3_half and
               abs_x <= radius and
               sqrt3 * abs_x + abs_y <= 2 * radius then
               table.insert(tiles, create_tile(tile, x+offset_x, y+offset_y))
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
  local x, y = translate_surface_coordinates(pos.surface, pos.x, pos.y)
  local exist = game.surfaces[pos.surface].find_entity(
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

local function remove_resources(surface)
  if storage.warptorio.ground_level == 0 then return end
  local level = storage.warptorio.ground_level
  local platform = warp_settings.floor.levels[level]

  local area = translate_surface_area(surface, nil, platform)
  local resources = game.surfaces[surface].find_entities_filtered{area = area, type = "resource"}
  for i,v in ipairs(resources) do
    v.destroy()
  end
end

local function remove_recipes(surface)
  if storage.warptorio.ground_level == 0 then return end
  local level = storage.warptorio.ground_level
  local platform = warp_settings.floor.levels[level]

  local area = translate_surface_area(surface, nil, platform)
  local entities = game.surfaces[surface].find_entities_filtered{area = area, type = "assembling-machine"}
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

    storage.warptorio = storage.warptorio or {}
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
    ensure_surface_positions()
    ensure_surface_offset(storage.warptorio.warp_zone)
    starter_chest()
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
  game.forces.player.set_spawn_position({x=spawn_offset.x,y=spawn_offset.y}, game.surfaces[storage.warptorio.warp_zone])
  local tiles = generate_surface_rectangle("nauvis", warp_settings.floor.levels[1]*2,warp_settings.floor.levels[1]*2,"hazard-concrete-left")
  game.surfaces["nauvis"].set_tiles(tiles)
end)

script.on_load(function()
  --on_init_or_load()
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
          table.insert(tiles, {name="warp_tile_platform", position={x,y}})
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
    storage.warptorio.power_name = storage.warptorio.power_name or "warp-power"
    local power_1 = get_or_create(storage.warptorio.power_name,{x=0,y=0,surface=dest})
    local power_2 = get_or_create(storage.warptorio.power_name,{x=0,y=0,surface="factory"})
    power_1.minable = false
    power_2.minable = false
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

    if storage.warptorio.biochamber_level then
        local power_3 = get_or_create(storage.warptorio.power_name,{x=0,y=0,surface="garden"})
        power_3.minable = false
        power_3.rotatable = false
        storage.warptorio.power[3] = power_3
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

    if storage.warptorio.container_left_enabled then
      local container = get_or_create("warp_2x2-container",{x=-2,y=0,surface=dest})
      local inventory = container.get_inventory(defines.inventory.chest)
      if inventory.get_item_count("warp_2x2-container") == 0 then
        container.insert({name="warp_2x2-container", count=1})
      end
      container.minable = false
      container.rotatable = false
    end
    if storage.warptorio.container_right_enabled then
      local container = get_or_create("warp_2x2-container",{x=2,y=0,surface=dest})
      local inventory = container.get_inventory(defines.inventory.chest)
      if inventory.get_item_count("warp_2x2-container") == 0 then
        container.insert({name="warp_2x2-container", count=1})
      end
      container.minable = false
      container.rotatable = false
    end
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
     tiles = generate_ellipse(platform.width,platform.height,"warp_tile_platform")
  elseif warp_settings.factory.shape == "hexagon" then
     tiles = generate_hexagon(platform.width/2,"warp_tile_platform")
  else
     tiles = generate_cross(platform.width,platform.height,platform.arm)
  end

	--for x=minx-1, maxx do
	--	for y=miny-1, maxy do
  --    table.insert(tiles, {name="warp_tile_platform", position={x,y}})
  --  end
	--end
  game.surfaces["factory"].set_tiles(tiles)
  storage.warptorio.factory_level = level

  if level == 1 and platform.width == 10 then
      -- This is horrible fix, but it will do for now
      local tiles = generate_rectangle((platform.width*2)-4,(platform.height*2)-4,"hazard-concrete-left")
      game.surfaces["factory"].set_tiles(tiles)
      local tiles = generate_rectangle((platform.width*2)-8,(platform.height*2)-4,"warp_tile_platform")
      game.surfaces["factory"].set_tiles(tiles)
      local tiles = generate_rectangle((platform.width*2)-4,(platform.height*2)-8,"warp_tile_platform")
      game.surfaces["factory"].set_tiles(tiles)
  elseif level == 2 then
      game.print({"warptorio.help-text-2",warp_settings.trigger_research})
  end

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
   storage.warptorio.surface_name = storage.warptorio.planet_next
   local map_gen = nil
   map_gen = game.planets[surface_name].prototype.map_gen_settings
   storage.warptorio.allow_random_spawn = true

   if storage.warptorio.planet_next == "void" or name == "garden" or name == "space" then
      map_gen = space_gen_settings -- Use space_gen_settings for space-like surfaces
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
     elseif storage.warptorio.planet_next == "void" then
        game.print({"warptorio.map-void"})
     end
   else
     local ms_i = map_gens.variant_list[math.random(1,#map_gens.variant_list)]
     storage.warptorio.current_variant = ms_i
     if ms_i == "rich" then
        storage.warptorio.allow_random_spawn = false
     end
     ms = map_gens.functions.generate(surface_name,ms_i,map_gen)
     game.print({"warptorio.map-gen-"..ms_i})
   end

   ms.seed = math.random(0,math.pow(2,32))
   storage.warptorio.warp_next = name
   --ms = space_gen_settings
  
   if surface_name == "nauvis" then
      return game.create_surface(name,ms)
   else
      -- clear planets and reconect surfaces
      if game.planets[storage.warptorio.surface_name].surface and storage.warptorio.surface_name ~= surface_name then
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

  	belt = get_or_create("warp-platform-belt-"..speed,pos1)
    belt2 = get_or_create("warp-platform-belt-"..speed,pos2)

    if belt == nil or belt2 == nil then
      --game.print("Belt link error")
      --game.print(belt)
      --game.print(belt2)
      return
    end

    belt.disconnect_linked_belts()
    belt2.disconnect_linked_belts()
    belt2.linked_belt_type = "output"
    belt.linked_belt_type = "input"
    belt.connect_linked_belts(belt2)
    belt.minable = false
    belt2.minable = false
    belt.rotatable = false
    belt2.rotatable = false
end

local function update_belt_biochamber()
    if storage.warptorio.belt_level == 0 then return end
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
        table.insert(names,"warp-platform-belt-"..v)
      end
    end

    for i,v in ipairs(names) do
      delete_items({{-5,-1},{-4,1}},name,"factory")
      delete_items({{-5,-1},{-4,1}},name,"garden")
      --delete_items({{4,-1},{5,1}},name,"factory")
      --delete_items({{4,-1},{5,1}},name,"garden")
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

  local platform = warp_settings.garden.levels[level]


	--for x=minx-1, maxx do
	--	for y=miny-1, maxy do
  --    table.insert(tiles, {name="warp_tile_platform", position={x,y}})
  --  end
	--end
	
  if not game.surfaces["garden"] then
      local surface = new_random_surface("garden")
      local size = 10   
      surface.create_global_electric_network()
      surface.always_day = true
      surface.request_to_generate_chunks({0,0}, size)
      surface.force_generate_chunk_requests()
  end
	
  local tiles = generate_rectangle(platform.width,platform.height,"warp_tile_platform",platform.offset_x,platform.offset_y)
  game.surfaces["garden"].set_tiles(tiles)
  storage.warptorio.biochamber_level = level

  for i=1,platform.yumako do
      local center_y = warp_settings.garden.yumako.y+warp_settings.garden.yumako.offset
      local center_x = warp_settings.garden.yumako.x*(i-1)
      for _,part in ipairs(warp_settings.garden.yumako.parts) do
        local x = center_x
        local y = center_y
        x = x + (part.x and part.x or 0)
        y = y + (part.y and part.y or 0)
        local tiles = generate_rectangle(part.width,part.height,part.tile,x,y)
        game.surfaces["garden"].set_tiles(tiles)
      end
  end
  for i=1,platform.jellynut do
      local center_y = warp_settings.garden.jellynut.y+warp_settings.garden.jellynut.offset
      local center_x = warp_settings.garden.jellynut.x*(i-1)
      for _,part in ipairs(warp_settings.garden.jellynut.parts) do
        local x = center_x
        local y = center_y
        x = x + (part.x and part.x or 0)
        y = y + (part.y and part.y or 0)
        local tiles = generate_rectangle(part.width,part.height,part.tile,x,y)
        game.surfaces["garden"].set_tiles(tiles)
      end
  end
  update_belt_biochamber()
  refresh_power_and_teleport()
  if level == 1 then
      local container = get_or_create("warp_2x2-container",{x=5,y=0,surface="garden"})
      container.minable = false
      container.rotatable = false
  end
end

local function create_void_platform(surface, delete_entities,tile,multiplier)
   local tile = tile or "out-of-map"
   local multiplier = multiplier or 1
    if storage.warptorio.ground_level == 0 then return end
    local level = storage.warptorio.ground_level
    local platform = warp_settings.floor.levels[level]

    local tiles = generate_surface_rectangle(surface, platform * 2*multiplier, platform * 2*multiplier, tile)

    game.surfaces[surface].set_tiles(tiles)

    if delete_entities then
       -- Remove bots from old surface
       local area = translate_surface_area(surface, nil, platform)
       local entities = game.surfaces[surface].find_entities_filtered{
          area = area, force = "player"}
       for i,v in ipairs(entities) do
          v.destroy()
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
  --game.print("Upgrading ground platform size")
  local level = storage.warptorio.ground_level

  if e then
    level = mysplit(e,"-")
    level = tonumber(level[#level])
    --storage.warptorio.wave_time = 0
    if level == 1 then
      create_void_platform(storage.warptorio.warp_zone)
    end
  end

  --if tonumber(level) == 1 then
    -- First upgrade generate base buildings
    --game.print("Spawning factory building")
    --game.surfaces["factory"].create_entity({name="space-platform-hub", position = {0,0}, force=game.forces.player})
  --end

  local platform = warp_settings.floor.levels[level]

  --remove_resources(storage.warptorio.warp_zone)

  local tiles = generate_surface_rectangle(storage.warptorio.warp_zone, platform*2,platform*2,"warp_tile_world")
  game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
  storage.warptorio.ground_level = level
  storage.warptorio.ground_size = platform*2

  if level == 1 then
      local tiles = generate_surface_rectangle(storage.warptorio.warp_zone, 2,6,"hazard-concrete-left")
      game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
  end

  if not storage.warptorio.container_left_enabled then
      local tiles = generate_surface_rectangle(storage.warptorio.warp_zone, 2,2,"hazard-concrete-left",-2)
      game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
  end

  if storage.warptorio.factory_level > 0 then
    refresh_power_and_teleport()
  end
end

local function create_asteroids(amount, surface)
   local dest = storage.warptorio.space
   local level = storage.warptorio.ground_level
   local size = warp_settings.floor.levels[level]
   local evolution = game.forces["enemy"].get_evolution_factor(storage.warptorio.warp_zone)
   for i,v in ipairs(warp_settings.space.tresholds) do
      if v < evolution then
         for _=1,amount do
            local x = math.random(-size*1.25,size*1.25)
            local index = math.random(1,#warp_settings.space.asteroids[i])
            local asteroid = warp_settings.space.asteroids[i][index]
            game.surfaces[surface].create_entity{
               name=asteroid,
               position={x,math.random(-size*5,-size*2)},
               target={0,0},
               force="enemy"}
         end
      end
   end
end

local function create_angry_biters(biter_type,number,surface,quality,target)
   local target = target or {x=0,y=0}
   if surface == "space" then
      create_asteroids(number,surface)
      return
   end
   local quality = quality or "normal"
   if storage.warptorio.void then return end
   local surface_player_list = {}
   
   -- Create attack force for platform
   local angle = math.random(0,2*math.pi)
   local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
   local dist = warp_settings.floor.levels[level]
   local range = 300
   local offset = get_surface_offset(surface)
   local center = {x = offset.x + (target.x or 0), y = offset.y + (target.y or 0)}
   local x = center.x + math.cos(angle)*(dist+range)
   local y = center.y + math.sin(angle)*(dist+range)
   
   local unit_group = game.surfaces[surface].create_unit_group({ position = {x=x,y=y}, force = "enemy" })
   
   for j = 1,number do
      
      pos = game.surfaces[surface].find_non_colliding_position(biter_type, {x,y}, 0, 2, false)
      
      local angry_bitter = game.surfaces[surface].create_entity{
         name = biter_type,
         position = pos,
         quality = quality}
      --angry_bitter.autopilot_destination = k.position
      unit_group.add_member(angry_bitter)
   end
   
   unit_group.set_command({
         type=defines.command.go_to_location,
         destination={
            x=center.x,
            y=center.y
         }
   })
   unit_group.start_moving()
end


local function create_angry_boss(biter_type,number,surface,quality,target)
  local target = target or {x=0,y=0}
  local quality = quality or "normal"
  if storage.warptorio.void then return end
        local surface_player_list = {}
  for i,v in pairs(game.players) do
    -- Add players to the list
    if v.is_player() and v.connected and v.character and v.character.surface.name == surface then
      table.insert(surface_player_list,v.character)
    end
  end
  -- If surface is floor add dummy target as well
  --if surface == storage.warptorio.warp_zone then
  --  table.insert(surface_player_list,storage.warptorio.power[1])
  --end

  -- Create attack force per player
	--[[for i, k in ipairs(surface_player_list) do
		for j = 1,number do
			local angle = math.random(0,2*math.pi)
			local dist = 150
			local x = math.cos(angle)*dist+k.position.x
			local y = math.sin(angle)*dist+k.position.y

			pos = game.surfaces[surface].find_non_colliding_position(biter_type, {x,y}, 0, 2, false)

			--local angry_bitter = game.surfaces[surface].create_entity{name = biter_type, position = pos, quality = warp_settings.biter.quality[quality_index]}--{game.surfaces[spawners_list[1].position.x+10],spawners_list[1].position.y+10}}
      local angry_bitter = game.surfaces[s