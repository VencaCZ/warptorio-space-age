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
local function generate_hexagon(radius, tile)
    local tiles = {}
    local sqrt3 = math.sqrt(3)
    local r_sqrt3_half = radius * sqrt3 / 2
    for y = -radius * sqrt3 / 2, radius * sqrt3 / 2 do
        for x = -radius, radius do
            if math.abs(y) <= r_sqrt3_half and
               math.abs(x) <= radius and
               sqrt3 * math.abs(x) + math.abs(y) <= 2 * radius then
                table.insert(tiles, create_tile(tile, x, y))
            end
        end
    end
    return tiles
end

-- Function to generate an ellipse
local function generate_ellipse(width, height,tile)
    local tiles = {}
    local half_width = math.floor(width / 2)
    local half_height = math.floor(height / 2)

    for y = -half_height, half_height do
        for x = -half_width, half_width do
            local normalized_x = x / half_width
            local normalized_y = y / half_height
            if (normalized_x * normalized_x) + (normalized_y * normalized_y) <= 1 then
                table.insert(tiles, create_tile(tile, x, y))
            end
        end
    end

    return tiles
end

local my_map_gen_settings = {
		default_enable_all_autoplace_controls = false,
		property_expression_names = {cliffiness = 0},
		autoplace_settings = {tile = {settings = { ["out-of-map"] = {frequency="normal", size="normal", richness="normal"} }}},
		starting_area = "none",
}

local starter_items=warp_settings.starter_items

local function get_or_create(name,pos)
  local exist = game.surfaces[pos.surface].find_entity(
    name,
    {
      pos.x + (pos.x > 0 and -0.5 or 0.5),
      pos.y + 0.5
    }
  )
  if exist ~= nil then
    return exist
  end
  --game.print("Could not find entity "..(pos.x + (pos.x > 0 and -0.5 or 0.5)).."|"..pos.y + (pos.y > 0 and -0.5 or 0.5))
  local test = game.surfaces[pos.surface].can_place_entity{name=name, position = {pos.x,pos.y}}
  if not test then
    --game.print("Could not place entity. Making some space for"..name)
    for i,v in pairs(game.surfaces[pos.surface].find_entities({{pos.x, pos.y}, {pos.x+1, pos.y+1}})) do
      v.destroy()
    end
  end
  return game.surfaces[pos.surface].create_entity({name=name, position = {pos.x,pos.y}, direction = pos.dir, force=game.forces.player})
end

local function remove_resources(surface)
  if storage.warptorio.ground_level == 0 then return end
  local level = storage.warptorio.ground_level
  local platform = warp_settings.floor.levels[level]

	local minx = -platform
	local maxx = platform
	local miny = -platform
	local maxy = platform

  local resources = game.surfaces[surface].find_entities_filtered{area = {{minx, miny}, {maxx, maxy}}, type = "resource"}
  for i,v in ipairs(resources) do
    v.destroy()
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
    storage.warptorio.power_level = storage.warptorio.power_levle or 0
    storage.warptorio.time_passed = storage.warptorio.time_passed or 0
    storage.warptorio.time_level = storage.warptorio.time_level or 0
    storage.warptorio.wave_time = storage.warptorio.wave_time or 0
    storage.warptorio.wave_index = storage.warptorio.wave_index or 0
    storage.warptorio.warp_out = storage.warptorio.warp_out or 0
    storage.warptorio.surface_name = storage.warptorio.surface_name or "nauvis"
    storage.warptorio.planet_timer = storage.warptorio.planet_timer or 0
    storage.warptorio.planet_next = storage.warptorio.planet_next or nil
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
	game.forces.player.set_spawn_position({x=0,y=0}, game.surfaces[storage.warptorio.warp_zone])
  local tiles = generate_rectangle(warp_settings.floor.levels[1]*2,warp_settings.floor.levels[1]*2,"hazard-concrete-left")
  game.surfaces["nauvis"].set_tiles(tiles)
end)

script.on_load(function()
  --on_init_or_load()
end)

script.on_event(defines.events.on_force_created, function(e)
	e.force.set_spawn_position({x=0,y=0}, game.surfaces["nauvis"])
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
  local entities = game.surfaces[surface].find_entities_filtered{area = bounding_box, name = name}
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

	local minx = params.x
	local maxx = params.x + size
	local miny = params.y
	local maxy = params.y + size

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


  local surface_name = storage.warptorio.planet_next ~= "void" and storage.warptorio.planet_next or "nauvis"
  if name == "garden" then 
    surface_name = "nauvis"
  end
  storage.warptorio.surface_name = storage.warptorio.planet_next
  local map_gen = nil
  map_gen = game.planets[surface_name].prototype.map_gen_settings

  if storage.warptorio.planet_next == "void" or name == "garden" then
      map_gen = my_map_gen_settings
      storage.warptorio.void = true
  else
    storage.warptorio.void = false
  end
  map_gen.seed = math.random(0,math.pow(2,16))

  -- edit map gen
  map_gen.peaceful_mode = false
  map_gen.no_enemies_mode = false
  local ms = nil

  --game.print("Generating surface:"..surface_name)
  if storage.warptorio.planet_next == "void" or name == "garden" then
     ms = map_gen
  else
     local ms_i = map_gens.variant_list[math.random(1,#map_gens.variant_list)]
     ms = map_gens.functions.generate(surface_name,ms_i,map_gen)
     game.print({"warptorio.map-gen-"..ms_i})
  end

  
  if surface_name == "nauvis" then
    return game.create_surface(name,ms)
  else
    -- clear planets and reconect surfaces
    if game.planets[storage.warptorio.surface_name].surface and storage.warptorio.surface_name ~= surface_name then
      game.planets[storage.warptorio.surface_name].surface.clear()
      game.delete_surface(game.planets[storage.warptorio.surface_name].surface.name)
    end

    if game.planets[storage.warptorio.surface_name].prototype.entities_require_heating or game.planets[storage.warptorio.surface_name].surface ~= nil then
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

    local tiles = generate_rectangle(platform * 2*multiplier, platform * 2*multiplier, tile)

    game.surfaces[surface].set_tiles(tiles)

    if delete_entities then
       -- Remove bots from old surface
       local entities = game.surfaces[surface].find_entities_filtered{
          area = {{-platform, -platform}, {platform, platform}}, force = "player"}
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

    for y = -half_height, math.ceil(height / 2)-1 do
       for x = -half_width, math.ceil(width / 2)-1 do
          game.surfaces[surface].set_hidden_tile({x,y},nil)
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

  local tiles = generate_rectangle(platform*2,platform*2,"warp_tile_world")
  game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
  storage.warptorio.ground_level = level
  storage.warptorio.ground_size = platform*2

  if level == 1 then
      local tiles = generate_rectangle(2,6,"hazard-concrete-left")
      game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
  end

  if not storage.warptorio.container_left_enabled then
      local tiles = generate_rectangle(2,2,"hazard-concrete-left",-2)
      game.surfaces[storage.warptorio.warp_zone].set_tiles(tiles)
  end

  if storage.warptorio.factory_level > 0 then
    refresh_power_and_teleport()
  end
end

local function create_angry_biters(biter_type,number,surface,quality,target)
  local target = target or {x=0,y=0}
  local quality = quality or "normal"
  if storage.warptorio.void then return end
	local surface_player_list = {}

  -- Create attack force for platform
	local angle = math.random(0,2*math.pi)
  local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
	local dist = warp_settings.floor.levels[level]
  local range = 300
	local x = math.cos(angle)*(dist+target.x+range)
	local y = math.sin(angle)*(dist+target.y+range)

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
      x=0,
      y=0
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
      local angry_bitter = game.surfaces[surface].create_entity({position=pos,name=biter_type,quality=warp_settings.biter.quality[quality_index]})
      --angry_bitter.autopilot_destination = k.position
		end
    -- Send double the amount just in case there are some units around that did not go yet
		game.surfaces[surface].set_multi_command{command={type=defines.command.attack_area, destination=k.position,radius=warp_settings.biter.radius}, unit_count=number*2}
	end]]

  -- Create attack force for platform
  local angle = math.random(0,2*math.pi)
  local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
  local dist = warp_settings.floor.levels[level]
  local range = 125

	for j = 1,number do
	  local x = math.cos(angle)*(dist+target.x+range)
	  local y = math.sin(angle)*(dist+target.y+range)
		pos = game.surfaces[surface].find_non_colliding_position(biter_type, {x,y}, 0, 2, false)

		local angry_bitter = game.surfaces[surface].create_entity{name = biter_type, position = pos,quality=quality }
    --angry_bitter.autopilot_destination = k.position
	end

  game.surfaces[surface].set_multi_command{
    command={
      type=defines.command.go_to_location,
      destination={
        x=math.cos(angle)*(dist+target.x),
        y=math.sin(angle)*(dist+target.y+range)
      }
    },
    unit_count=range
  }
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
        table.insert(names,"warp-platform-belt-"..v)
      end
    end

    for i,v in ipairs(names) do
      delete_items({{-1,-5},{1,-4}},name,"factory")
      delete_items({{-1,-5},{1,-4}},name,storage.warptorio.warp_zone)
      delete_items({{-1,4},{1,5}},name,"factory")
      delete_items({{-1,4},{1,5}},name,storage.warptorio.warp_zone)
    end

    belt_pair({x=0,y=-5,dir=defines.direction.south,surface=storage.warptorio.warp_zone},{x=0,y=-5,dir=defines.direction.south,surface="factory"},speed[level])
    belt_pair({x=-1,y=-5,dir=defines.direction.south,surface=storage.warptorio.warp_zone},{x=-1,y=-5,dir=defines.direction.south,surface="factory"},speed[level])
    belt_pair({x=0,y=4,dir=defines.direction.north,surface="factory"},{x=0,y=4,dir=defines.direction.north,surface=storage.warptorio.warp_zone},speed[level])
    belt_pair({x=-1,y=4,dir=defines.direction.north,surface="factory"},{x=-1,y=4,defines.direction.north,surface=storage.warptorio.warp_zone},speed[level])


    storage.warptorio.belt_level = level
end

local function check_teleport(player,location,destination)
  if storage.warptorio.factory_level == 0 then return end
  if player.surface.name ~= location.surface then return end
  if player.position.x > location.x-0.1 and
     player.position.x < location.x+2.0 and
     player.position.y > location.y-0.1 and
     player.position.y < location.y+2.1 then
  		local player_pos = game.surfaces[destination].find_non_colliding_position("character", {location.x,location.y}, 0, 0.5, false)
	  	player.teleport(player_pos, destination)
  end
end

function sec_to_time(time_base)
    local minutes = math.floor(time_base / 60)
    local seconds = time_base % 60
    return string.format("%02d:%02d",minutes,seconds)
end

local function warp_gui(player)
   local screen_element = player.gui.top
   if not storage.warptorio.gui then storage.warptorio.gui = {} end

   -- clear old gui if it exists
   local elements = {
      "time_passed_label",
      "number_of_warps_label",
      "number_of_waves_time",
      "number_of_waves_amount",
      "time_to_warp",
      "warp_planet"
   }
   for _,v in ipairs(elements) do
      if screen_element[v] then screen_element[v].destroy() end
   end
   
   local warp_frame_data = warp_settings.gui.data
   
   local warpFrame = screen_element.add{type = "frame", name=warp_settings.gui.holder,direction="horizontal"}
   --local dragger = warpFrame.add{type="empty-widget", style="draggable_space"}
   --dragger.style.size = {128, 24}
   --dragger.drag_target = frame
   for _,v in ipairs(warp_frame_data) do
      local frame = warpFrame.add{type = "frame",style="warptorio_frame", name=v.name,direction="vertical"}
      frame.add{type = "label", style="bold_label", name = "WarpLabel", caption = v.label}
      frame.add{type = "line", name = "WarpLine"}
      frame.add{type = "label", name = "WarpValue", caption = "  "..v.value.."  "}
   end
   
   local frame = warpFrame.add{type = "frame",style="entity_frame", name="buttons",direction="vertical"}
   frame.add{type = "button", name="warp_planet", style="red_button", caption={"warptorio.button-warp"}}
   --frame.add{type = "button", name="go_home", style="green_button", caption="Home"}
end

function update_label(label_name,text,is_label)
   local is_label = is_label or false
   local gui_parent = warp_settings.gui.holder
   
   for k, v in pairs(game.players) do
      if not v.gui.top[gui_parent] then
         warp_gui(v)
      end
      local vl = warp_settings.gui.value
      local ll = warp_settings.gui.label
      if not is_label then
         v.gui.top[gui_parent][label_name][vl].caption = text
      else
         v.gui.top[gui_parent][label_name][ll].caption = text
      end
   end
end

local function update_all_labels()

  local time_limit = warp_settings.time.round + (warp_settings.time.round*storage.warptorio.time_level)
  local time_passed = sec_to_time(time_limit-storage.warptorio.time_passed)
  update_label("time", time_passed)
  local index = 0
  if storage.warporio and storage.warporio.index then
    index = storage.warporio.index
  end
  update_label("amount",index)
  update_label("wave-time",sec_to_time(storage.warptorio.wave_time))
  update_label("wave-amount",storage.warptorio.wave_index)
  --TODO update label as well
  if storage.warptorio.transition_timer > 60 then
     update_label("warpout-time",sec_to_time(math.floor(storage.warptorio.transition_timer/60)))
  else
     update_label("warpout-time",sec_to_time(storage.warptorio.warp_out))
  end
  if storage.warptorio.planet_next and
     game.forces["player"].technologies[warp_settings.trigger_research].researched then
     update_label("next-planet",storage.warptorio.planet_next)
  else
     update_label("next-planet",{"warptorio.gui-unknown-planet"})
  end
end

local function technology_check()
  if not game.forces["player"].current_research then return false end
  if game.forces["player"].current_research.name == "warp-end-prepare" or game.forces["player"].current_research.name == "warp-end-win" then
    return true
  end
  return false
end

local function spawn_boss_check()
   if storage.warptorio.wave_index % 10 == 0 then
      return true
   end
   if storage.warptorio.wave_index > warp_settings.biter.wave_change_max then
      return true
   end
   if storage.warptorio.wave_index > warp_settings.biter.wave_change_index then
      local rand = math.random()
      if rand > warp_settings.biter.wave_change_chance then return true end
   end
   return false
end

local function replace_with_high_quality(old_entity, strquality)
	
	local name = old_entity.name
	local surface = old_entity.surface
	local position = old_entity.position
	local force = old_entity.force
	old_entity.destroy()
	local new_entity = surface.create_entity{
		name = name,
		position = position,
		force = force,
		quality = strquality
	}

end

local function choose_quality(index)
   local step = index-warp_settings.biter.quality_start
   step = math.ceil(step/warp_settings.biter.quality_step)
   if step < 1 then step = 1 end
   if step > #warp_settings.biter.quality then
      step = #warp_settings.biter.quality
   end
   return warp_settings.biter.quality[step]
end

local function replace_common(entity)
   if not entity.force.name == "enemy" then return end
   if storage.warporio.index < warp_settings.biter.quality_start then return end
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

local function check_wave()
    if not storage.warporio then storage.warporio = {} end
    if not storage.warporio.index then storage.warporio.index = 0 end
  if not game.forces["player"].technologies["warp-ground-platform-1"].researched and game.forces["player"].technologies[warp_settings.trigger_wave].researched == false then
    storage.warptorio.wave_time = warp_settings.time.grace_period
  end
  local limit = storage.warptorio.wave_time

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

  local spawn_boss = spawn_boss_check()
  local quality = choose_quality(storage.warporio.index)  
  
  if limit <= 0 then
    local amount = warp_settings.biter.wave_amount*math.floor((storage.warptorio.wave_index+1)*warp_settings.biter.wave_increase)
    for i=1,amount do
      if technology_check() or spawn_boss then break end
      local biter_group = warp_settings.biter.entity_type["default"]
      if storage.warptorio.surface_name and warp_settings.biter.entity_type[storage.warptorio.surface_name] then
        biter_group = warp_settings.biter.entity_type[storage.warptorio.surface_name]
      end

      --game.print("Spawning index "..biter_index.. " at evolution" .. evolution)
      local biter_type = biter_group[biter_index][math.random(1,#biter_group[biter_index])]
      local angry_amount = math.random(warp_settings.biter.amount/2,warp_settings.biter.amount)

      --game.print("Sending gifts "..warp_settings.biter.quality[quality_index].." quality")
      

      create_angry_biters(biter_type,angry_amount,storage.warptorio.warp_zone,quality)
    end
    if (spawn_boss and storage.warptorio.surface_name ~= "aquilo") or technology_check() then
      if storage.warptorio.wave_index == 10 and (not technology_check()) then game.print({"warptorio.boss-warning"}) end
      local max = math.ceil(storage.warptorio.wave_index/10)
      local max = max < warp_settings.biter.max_bosses and max or warp_settings.biter.max_bosses
      for _=1,max do
          local biter_group = warp_settings.biter.entity_type["boss"][biter_index]
          local biter_type = biter_group[math.random(1,#biter_group)]
          if string.match(biter_type, "demolisher") then
            create_angry_boss(biter_type,math.random(1,max),storage.warptorio.warp_zone,quality)
          else
            create_angry_biters(biter_type,math.random(1,max),storage.warptorio.warp_zone,quality)
          end
          if not technology_check() then break end
      end
    end
    storage.warptorio.wave_index = storage.warptorio.wave_index + 1
    storage.warptorio.wave_time = warp_settings.biter.time - (storage.warptorio.wave_index*warp_settings.biter.change)
    if technology_check() then
        storage.warptorio.wave_time = warp_settings.biter.min
    end
    if storage.warptorio.wave_time < warp_settings.biter.min then
      storage.warptorio.wave_time = warp_settings.biter.min
    end
  elseif not storage.warptorio.void then
    storage.warptorio.wave_time = storage.warptorio.wave_time - 1/60
  end
end

local function teleport_ground(source, target)
  local level = storage.warptorio.ground_level or 0

  if level == 0 then return end

  local platform = warp_settings.floor.levels[level]

	local minx = -platform
	local maxx = platform
	local miny = -platform
	local maxy = platform

  -- Basic is generated time to set it as main surface
  --storage.warptorio.warp_zone = target

  -- Teleport base part
  game.surfaces[source].clone_area({
    source_area={{minx, miny}, {maxx, maxy}},
    destination_area={{minx, miny}, {maxx, maxy}},
    destination_surface=target,
    expand_map=true,
    clone_tiles=true,
    clear_destination_entities=true,
    clear_destination_decoratives=true,
    clone_decoratives=false,
  })

  -- Delete teleported(generated) characters
	local surface_player_list = game.surfaces[target].find_entities_filtered{type="character"}
  for i,v in ipairs(surface_player_list) do
    v.destroy()
  end

  --Regenerate belts and power


end

local function teleport_players(source,destination,factory)

  local level = storage.warptorio.ground_level or 0
  local platform = warp_settings.floor.levels[level]

	local minx = -platform
	local maxx = platform
	local miny = -platform
	local maxy = platform
  
  for i,v in pairs(game.players) do
    -- Add players to the list
    if v.is_player() and v.connected and v.character and v.character.surface.name == source then
       local pos = v.character.position
       if factory then
          pos = game.surfaces[storage.warptorio.warp_zone].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
       end
       if pos.x >= minx and pos.x <=maxx and pos.y >= miny and pos.y <= maxy then
          v.teleport(pos,destination)
       else
          local pos = game.surfaces[destination].find_non_colliding_position(v.character, {0,0}, 0, platform, false)
          if factory then
             pos = game.surfaces[storage.warptorio.warp_zone].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
          end
          v.teleport(pos,destination)
       end
    end
  end
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


local function next_warp_zone_prepare()
    --if true then return end
    storage.warptorio.teleporting = true
    if not storage.warporio then storage.warporio = {} end
    if not storage.warporio.index then storage.warporio.index = 0 end
    
    if storage.warptorio.container and storage.warptorio.container.destroy() then
       game.print({"warptorio.container-removed"})
       storage.warptorio.container = nil
    end

    -- fix research if someone is trying to cheat
    if game.forces["player"].technologies["warp-end-prepare"].saved_progress > 0 and game.forces["player"].technologies["warp-end-prepare"].researched == false then
      game.print({"warptorio.technology-cheater"})
      game.forces["player"].technologies["warp-end-prepare"].saved_progress = 0
    end

    if game.forces["player"].technologies["warp-end-win"].saved_progress > 0 and game.forces["player"].technologies["warp-end-win"].researched == false then
      game.print({"warptorio.technology-cheater"})
      game.forces["player"].technologies["warp-end-win"].saved_progress = 0
    end

    if technology_check() then
      game.forces["player"].research_progress = 0
    end

    storage.warporio.index = storage.warporio.index + 1
    storage.warptorio.time_passed = 0
    local name = "warpzone_"..storage.warporio.index
    local surface = new_random_surface(name)
    local size = 10
    surface.request_to_generate_chunks({0,0}, size)
    storage.warptorio.warp_next = name
    storage.warptorio.previous_surface_wave = storage.warptorio.wave_index
    storage.warptorio.previous_surface_time = storage.warptorio.wave_time
end

local function next_warp_zone_finish()
   local name = storage.warptorio.warp_next
   --local name = storage.warptorio.space
   local surface = game.surfaces[name]
   local keep_time = false
   game.print((storage.warptorio.previous_surface_2 or "none") .. " | " .. storage.warptorio.surface_name )
   if storage.warptorio.previous_surface_2 == storage.warptorio.surface_name then
      keep_time = true
      game.print({"warptorio.hopping-surfaces"},{color={1,0.25,0.25}})
   end
   storage.warptorio.previous_surface_2 = storage.warptorio.previous_surface_1
   storage.warptorio.previous_surface_1 = storage.warptorio.surface_name
    surface.force_generate_chunk_requests()
    --game.print("New warpzone created")
    create_void_platform(name)
    local source = nil
    if storage.warptorio.factory_level >= warp_settings.space.trigger_factory_level and
       warp_settings.space.transition then
       source = storage.warptorio.space
    else
       source = storage.warptorio.warp_zone
    end
    if source == nil then
       game.print("ERORR:Source planet is nil. Something went wrong")
       source = storage.warptorio.warp_zone
    end
    --storage.warptorio.warp_next = name
    remove_resources(source)
    teleport_ground(source,name)
    teleport_players(source,name)
    if storage.warptorio.factory_level > 0 then
      refresh_power_and_teleport()
    end
    
    storage.warptorio.wave_index = 0
    storage.warptorio.wave_time = warp_settings.biter.time
    if keep_time then
       storage.warptorio.wave_index = storage.warptorio.previous_surface_wave or 0
       storage.warptorio.wave_time = storage.warptorio.previous_surface_time or warp_settings.biter.time
    end
    -- This is no longer needed
    --[[local extra_time = false
    for i,v in ipairs(warp_settings.biter.extra_time_planet) do
      if v == storage.warptorio.surface_name then
        extra_time = true
      end
       end]]
    if extra_time then storage.warptorio.wave_time = storage.warptorio.wave_time + warp_settings.biter.extra_time_amount end
    create_void_platform(source,true)
    if storage.warptorio.old_surface and game.surfaces[storage.warptorio.old_surface] and game.surfaces[storage.warptorio.old_surface].valid then
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
      local inventory = v.get_inventory(defines.inventory.character_main)
      if inventory then
        local container = inventory.find_item_stack("warp_2x2-container")
        while container do
          container.clear()
          container = inventory.find_item_stack("warp_2x2-container")
        end
      end
    end
    pollution_settings()
    game.forces["enemy"].set_evolution_factor(storage.warporio.index/warp_settings.polution.jumps,name)
    
    if script.active_mods["rso-mod"] then
       remote.call("RSO", "resetGeneration", surface)
    end

    storage.warptorio.warp_zone = surface.name

    update_belt()
    if storage.warptorio.factory_level > 0 then
      refresh_power_and_teleport()
    end
   if storage.warptorio.factory_level >= warp_settings.space.trigger_factory_level and
      warp_settings.space.transition then
      game.play_sound({path="warp-end"})
    else
      game.play_sound({path="warp-start"})
    end

   storage.warptorio.teleporting = false
   create_void_platform(source,true,"empty-space")
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
   local dest = storage.warptorio.space or "none"

   if not game.surfaces[dest] then
       local sf = game.forces.player.create_space_platform{
          name="warp_transition",planet="nauvis",starter_pack="space-platform-starter-pack"}
       sf.apply_starter_pack()
       storage.warptorio.space = sf.surface.name
       create_void_platform(sf.surface.name,false,"empty-space")
       dest = storage.warptorio.space
   end

   if game.surfaces[dest].platform then
      local surface_name = storage.warptorio.planet_next ~= "void" and storage.warptorio.planet_next or "nauvis"
      game.print("Setting transition location to:"..surface_name)
      local prototypes = prototypes.space_connection
      local names = {}
      for key,value in pairs(prototypes) do
         table.insert(names,key)
      end
      names = shuffle(names)
      local connection = nil
      local allow_aquilo = true
      if surface_name == "aquilo" then
         allow_aquilo = false
      end
      for i=#names,1,-1 do
         local v = names[i]
         if string.find(v,"system") then
            --game.print("Found:"..v)
            table.remove(names,i)
         end
      end
      for _,v in ipairs(names) do
         if string.find(v,"solar-system-edge") then
         end
         if string.find(v,surface_name) and
            not (string.find(v,"aquilo") and allow_aquilo) then
            connection = v
            break
         end
      end
      if storage.warptorio.travel_to_edge then
         connection = "solar-system-edge-shattered-planet"
         storage.warptorio.travel_to_edge = false
      end
      local sf = game.surfaces[dest].platform
      sf.space_location = surface_name
      if connection then
         game.print("Connection found:"..connection)
         sf.space_connection = connection
         sf.distance = 0.5
         sf.speed = 1
         sf.paused = false
         -- TODO: Extra Asteroids will be in next update
         --[[local asteroids = prototypes[connection].asteroid_spawn_definitions
         for _,v in ipairs(asteroids) do
            game.print(v.asteroid)
            local pos = getPointAndVector(0,0, 100)
            sf.create_asteroid_chunks({{
                  name = v.asteroid,
                  position = pos.position,
                  movement = pos.movement                  
            }})
            end]]
      end
   end

   create_void_platform(dest,true,"empty-space",1.5)
   
   teleport_ground(source,dest)
   teleport_players(source,"factory",true)
   --set_hidden_tiles(dest,"empty-space")
   create_void_platform(source,true)

   local save = storage.warptorio.warp_zone
   storage.warptorio.warp_zone = dest
   refresh_power_and_teleport(dest)
   update_belt()
   storage.warptorio.warp_zone = save
   
   local text = {"warptorio.teleport-text"}
   rendering.draw_text{
      surface="factory",
      text=text,scale=2,
      target={x=0,y=0},
      color={1,0,0},
      time_to_live=storage.warptorio.transition_timer
   }
   game.play_sound({path="warp-start"})
end

local function next_warp_zone_transition()
   if storage.warptorio.transition_timer < 60 then
      return
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

local function next_warp_zone()
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
       if game.forces.player.is_space_location_unlocked(i) then
          table.insert(surfaces,i)
       end
    end
  end

  local surface_name = surfaces[math.random(1,#surfaces)]
  while storage.warptorio.surface_name == surface_name and surface_name ~= "nauvis" do
    surface_name = surfaces[math.random(1,#surfaces)]
  end

  if surface_name == "nauvis" and storage.warptorio.void ~= true then
    local r = math.random()
    if r > 0.75 then
      surface_name = "void"
    end
  end

  if game.forces["player"].technologies["warp-end-prepare"].researched then
     local r = math.random()
     if storage.warptorio.travel_to_edge then
        storage.warptorio.travel_to_edge = false
     elseif r < warp_settings.space.edge_chance then
        storage.warptorio.travel_to_edge = true
        game.print({"warptorio.next-edge"},{color={1,0,0}})
     end
  end
  
  storage.warptorio.planet_next = surface_name
  if game.forces["player"].technologies[warp_settings.trigger_research].researched then
     local sound = defines.print_sound.always
     if not warp_settings.next_planet_sound then
        sound = defines.print_sound.never
     end
     game.print({"warptorio.next-planet",storage.warptorio.planet_next},{sound=sound})
  end
end

local function on_tick_power()
  if storage.warptorio.power then
    if storage.warptorio.power[2].valid and storage.warptorio.power[1].valid then
      local ave = average(storage.warptorio.power[2].energy,storage.warptorio.power[1].energy)
      if storage.warptorio.power[3] then
        ave = (storage.warptorio.power[1].energy + storage.warptorio.power[2].energy + storage.warptorio.power[3].energy)/3
      end
      storage.warptorio.power[1].energy = ave
      storage.warptorio.power[2].energy = ave
      if storage.warptorio.power[3] then
        storage.warptorio.power[3].energy = ave
      end
    end
  end
end

local function warp_array(array,destination)
   for i,v in ipairs(array) do
      local new_entity = v.clone({position=v.position, surface=destination})
      if new_entity then
         new_entity.copy_settings(v)
         v.destroy()
      else
         game.print({"warptorio.train-warp-error"},{color={1,0,0}})
      end
   end
end

local function warp_trains()
   if not game.forces["player"].technologies["warp-train"].researched then return end
   local stations = game.train_manager.get_train_stops({station_name="WarpStation"})
   for i,v in ipairs(stations) do
      local train = v.get_stopped_train()
      if train then
         game.print("Train stoped at warp station")
         game.print(v.surface.name)
         local at_station = train.state == defines.train_state.wait_station
         local wagons = train.carriages
         local destination = v.surface.name == "factory" and storage.warptorio.warp_zone or "factory"
         if at_station then
            game.print({"warptorio.train-warp",destination})
            warp_array(wagons,destination)
         end
      end
   end
end

script.on_event(defines.events.on_tick, function(event)
   if storage.warptorio and storage.warporio then
      local dest = storage.warptorio.space or "none"
      if game.surfaces[dest] and game.surfaces[dest].platform then
         local sf = game.surfaces[dest].platform
         sf.speed = storage.warporio.index*warp_settings.space.speed_per_warp
         sf.paused = false
      end
   end
   warp_trains()
  for i,v in ipairs(warp_settings.blocked_planets) do
    if v == storage.warptorio.surface_name and technology_check() then
      game.forces["player"].research_progress = 0
    end
  end
  if not storage.warptorio.transition_timer then storage.warptorio.transition_timer = -1 end
  update_all_labels()

  on_tick_power()
  
  if storage.warptorio.transition_timer > 0 then
     storage.warptorio.transition_timer = storage.warptorio.transition_timer - 1
     next_warp_zone_transition()
     return
  elseif storage.warptorio.transition_timer == 0 then
     next_warp_zone_finish()
     storage.warptorio.transition_timer = -1
     return
  elseif storage.warptorio.transition_timer > -warp_settings.time.extra_transition_time*60 then
     storage.warptorio.transition_timer = storage.warptorio.transition_timer - 1
  end
  if storage.warptorio.ground_level > 0 then
    if not technology_check() then
      storage.warptorio.time_passed = storage.warptorio.time_passed + 1/60
    end
    if storage.warptorio.warp_out > 0 then
      storage.warptorio.warp_out = storage.warptorio.warp_out - 1/60
    else
      storage.warptorio.warp_out = 0
    end
  end
  if not storage.warptorio.planet_timer then storage.warptorio.planet_timer = 0
  elseif storage.warptorio.warp_out <= 0 then
    storage.warptorio.planet_timer = storage.warptorio.planet_timer + 1/60
    if storage.warptorio.planet_timer > warp_settings.planet_timer or storage.warptorio.planet_next == nil
        or (storage.warptorio.planet_next == storage.warptorio.warp_zone and storage.warptorio.planet_next ~= "nauvis") then
      storage.warptorio.planet_timer = 0
      roll_planet()
    end
  else
    storage.warptorio.planet_timer = warp_settings.planet_timer
  end
  local time_limit = warp_settings.time.round + (warp_settings.time.round*storage.warptorio.time_level)
  if storage.warptorio.time_passed > time_limit then
    next_warp_zone()
  end
  if game.surfaces[storage.warptorio.warp_zone] and
     storage.warptorio.time_passed > warp_settings.polution.time and
     storage.warptorio.warp_zone ~= "nauvis" then
    game.surfaces[storage.warptorio.warp_zone].pollute({0,0}, warp_settings.polution.amount)
  end
  --if storage.warptorio.surface_name ~= nil and storage.warptorio.warp_zone ~= "nauvis" then
  --  local factor = storage.warptorio.time_passed/warp_settings.time.limit
  --  factor = factor > 1 and 1 or factor
  --  game.forces["enemy"].set_evolution_factor(factor*100,storage.warptorio.warp_zone)
  --end
  check_wave()
  local tran_timer = (warp_settings.time.extra_transition_time*60)-1
  if storage.warptorio.teleporting or storage.warptorio.transition_timer > -tran_timer then
     return
  end
  local players = game.players
  for i,v in pairs(players) do
    -- If player steps into teleport zone, teleport them
    if v.is_player() and v.connected and v.controller_type == defines.controllers.character then
      check_teleport(v,{x=-1,y=-2,surface=storage.warptorio.warp_zone},"factory")
      check_teleport(v,{x=-1,y=2,surface="factory"},storage.warptorio.warp_zone)
      if storage.warptorio.biochamber_level then
        check_teleport(v,{y=-1,x=2,surface="garden"},"factory")
        check_teleport(v,{y=-1,x=-2,surface="factory"},"garden")
        check_teleport(v,{y=-1,x=3,surface="garden"},"factory")
        check_teleport(v,{y=-1,x=-3,surface="factory"},"garden")
      end
    end
  end
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)

    warp_gui(player)
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
    if not storage.warptorio.clicks_to_teleport then
       storage.warptorio.clicks_to_teleport = {}
    end
    if event.element.name == "warp_planet" then
       local amount = #game.forces["player"].connected_players
       if amount > 1 then
          local add = true
          for i,v in ipairs(storage.warptorio.clicks_to_teleport) do
             if v == event.player_index then
                add = false
             end
          end
          if add then
             table.insert(storage.warptorio.clicks_to_teleport,event.player_index)
             local name = game.get_player(event.player_index).name
             local ratio = #storage.warptorio.clicks_to_teleport/amount
             if ratio < warp_settings.time.clicks_to_teleport then
                local amount = math.ceil(amount*warp_settings.time.clicks_to_teleport)
                local n = amount - #storage.warptorio.clicks_to_teleport
                game.print({"warptorio.player-warp",name,n},{color={1,1,0}})
                return
             end
          end
       end
       
       if storage.warptorio.ground_level == 0 then
          game.print({"warptorio.warp-not-available"})
          return
       end
       if storage.warptorio.warp_out > 0 then
          game.print({"warptorio.cooling-down"})
          return
        end
       if technology_check() then
          game.print({"warptorio.technology-check"})
          return
       end
       
       next_warp_zone()
    end
end)

local function update_time(e)
    --game.print("Time on planet extended")

    local e_level = mysplit(e,"-")
    level = tonumber(e_level[#e_level])
   storage.warptorio.time_level = level
end

local function update_power(e)
    --game.print("Time on planet extended")

    local e_level = mysplit(e,"-")
    level = tonumber(e_level[#e_level])
    storage.warptorio.power_name = "warp-power-"..(level+1)
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
      name = warp_settings.techs.container_left,
      func = function ()
         game.print("Container will be added after the teleport")
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
         game.set_win_ending_info{title={"warptorio.end-screen-title"}, message={"warptorio.end-screen-text"}}
         game.set_game_state{game_finished=true,player_won=true,can_continue=true}
      end
   },
   {
      name = "warptorio%-platform%-repair",
      func = function ()
         game.print("test")
         update_ground_platform()
      end
   },   
}

script.on_event(defines.events.on_research_finished, function(e)
    for _,v in ipairs(techs) do
       if string.find(e.research.name, v.name) then
          game.print(e.research.name)
          v.func(e.research.name)
          return
       end
    end
end)

script.on_event(defines.events.on_lua_shortcut, function(e)
    if e.prototype_name == "warptorio-teleport" then
      --check_teleport(game.players[e.player_index],{x=-1,y=-2,surface=storage.warptorio.warp_zone},"factory")
      if storage.warptorio.factory_level > 0 then
         local player_pos = game.surfaces["factory"].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
         game.players[e.player_index].teleport(player_pos, "factory")
      else
        game.print({"warptorio.warp-not-available"})
      end
    end
end)

script.on_event(defines.events.on_player_respawned, function(event)
	--if game.players[event.player_index].character.surface ~= storage.warptorio.warp_zone then
		local player_pos = game.surfaces[storage.warptorio.warp_zone].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
		game.players[event.player_index].teleport(player_pos, storage.warptorio.warp_zone)
	--end
end)

script.on_event(defines.events.on_built_entity, function(e)
    if e.entity.name == "warp_2x2-container" then
       if storage.warptorio.container then
          game.print({"warptorio.container-placed-error"},{color={1,0,0}})
          e.entity.destroy()
          return
       else
          game.print({"warptorio.container-placed"})
       end
       storage.warptorio.container = e.entity
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(e)
    if e.entity.name == "warp_2x2-container" then
       game.print({"warptorio.container-removed"})
       storage.warptorio.container = nil
    end
end)

script.on_event(defines.events.on_robot_mined_entity, function(e)
    if e.entity.name == "warp_2x2-container" then
       game.print({"warptorio.container-removed"})
       storage.warptorio.container = nil
    end
end)

script.on_event(defines.events.on_research_started, function(e)
    if string.match(e.research.name, "warp") then
      if string.match(e.research.name, "end") then
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

script.on_event(defines.events.on_player_joined_game, function(e)
  if e.player_index == 1 and game.forces["player"].technologies["automation"].researched == false then
     game.print({"warptorio.help-text-1",warp_settings.trigger_wave})
     rendering.draw_text{
        surface="nauvis",
        text={"warptorio.help-text-1",warp_settings.trigger_wave},scale=2,
        target={x=0,y=0},
        color={0,1,0},
        time_to_live=60*10
     }
  end
  if e.player_index ~= 1 then
     if game.forces["player"].technologies["warp-factory-platform-1"].researched then
        local player_pos = game.surfaces["factory"].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
        game.players[e.player_index].teleport(player_pos, "factory")
     elseif game.surfaces[storage.warptorio.warp_zone] then
        local player_pos = game.surfaces[storage.warptorio.warp_zone].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
        game.players[e.player_index].teleport(player_pos, storage.warptorio.warp_zone)
     end
  end
end)


remote.add_interface("warptorio",
  {
     edit_planet_variants = function(variant,planet,map_gen_settings)
        if not map_gens.variant_list[variant] then
           table.insert(map_gens.variant_list,variant)
        end
        map_gens.planets[planet.."_"..variant] = map_gen_settings
     end
  }
)
