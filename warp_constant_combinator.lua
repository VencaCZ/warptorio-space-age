local warp_settings = require("internal_settings")

local warp_constant_combinator = {}

local COMBINATOR_NAME = "warp-constant-combinator"

local function ensure_storage()
  storage.warptorio = storage.warptorio or {}
  storage.warptorio.constant_combinators = storage.warptorio.constant_combinators or {}
  return storage.warptorio.constant_combinators
end

local function get_warp_amount()
  if storage.warporio and storage.warporio.index then
    return storage.warporio.index
  end
  return 0
end

local function set_parameters(section, parameters)
   for _,param in ipairs(parameters) do
      param.signal.quality="normal"
      section.set_slot(
         param.index,
         {
            value = param.signal,
            min=param.count,
            max=param.count
         }
      )
   end
end

local function get_planet_signal(planet_name)
  if not planet_name then
    return nil
  end
  if not game.planets[planet_name] then
    return nil
  end
  return {type = "space-location", name = planet_name}
end

local function update_entity(entity, remaining_time, wave_index, wave_time, warp_amount)
  if not entity.valid then
    return false
  end

  local control_behavior = entity.get_or_create_control_behavior()

  local section = control_behavior.get_section(1)

  entity.combinator_description = [[
  signal-T - Remaining time
  signal-W - Wave index
  signal-V - Wave time
  signal-A - Warp amount
  planet-signal - Value 1 current planet
  planet-signal - Value 2 next planet
  ]]
  
  if not section then
     control_behavior.add_section()
     section = control_behavior.get_section(1)
  end

  if not section.is_manual then
     for _,sec in ipairs(control_behavior.sections) do
        if sec.is_manual then
           section = sec
           break
        end
     end
  end
  
  local parameters = {
    {index = 1, signal = {type = "virtual", name = "signal-T"}, count = math.floor(remaining_time)},
    {index = 2, signal = {type = "virtual", name = "signal-W"}, count = wave_index},
    {index = 3, signal = {type = "virtual", name = "signal-V"}, count = math.floor(wave_time)},
    {index = 4, signal = {type = "virtual", name = "signal-A"}, count = warp_amount},
  }

  local current_planet_signal = get_planet_signal(storage.warptorio.surface_name)
  local next_planet_signal = get_planet_signal(storage.warptorio.planet_next)
  if current_planet_signal then
     local count = 1
     -- Basically just handling nauvis
     if current_planet_signal == next_planet_signal then
        count = 3
     end
     table.insert(parameters, {index = #parameters + 1, signal = current_planet_signal, count = count})
  end

  if next_planet_signal then
    table.insert(parameters, {index = #parameters + 1, signal = next_planet_signal, count = 2})
  end

  set_parameters(section, parameters)
  return true
end

function warp_constant_combinator.register(entity)
  if not entity or not entity.valid or entity.name ~= COMBINATOR_NAME then
    return
  end

  local entities = ensure_storage()
  if entity.unit_number then
    entities[entity.unit_number] = entity
  end
end

function warp_constant_combinator.unregister(entity)
  if not entity or not entity.unit_number or not storage.warptorio or not storage.warptorio.constant_combinators then
    return
  end

  storage.warptorio.constant_combinators[entity.unit_number] = nil
end

function warp_constant_combinator.init()
  ensure_storage()
end

function warp_constant_combinator.rescan()
  local entities = ensure_storage()
  for key in pairs(entities) do
    entities[key] = nil
  end

  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered({name = COMBINATOR_NAME})
    for _, entity in ipairs(found) do
      warp_constant_combinator.register(entity)
    end
  end
end

function warp_constant_combinator.refresh()
  local entities = ensure_storage()
  local time_limit = warp_settings.time.round + (warp_settings.time.round * storage.warptorio.time_level)
  local remaining_time = math.max(0, time_limit - storage.warptorio.time_passed)
  local wave_index = storage.warptorio.wave_index or 0
  local wave_time = math.max(0, storage.warptorio.wave_time or 0)
  local warp_amount = get_warp_amount()

  for unit_number, entity in pairs(entities) do
    local ok = update_entity(entity, remaining_time, wave_index, wave_time, warp_amount)
    if not ok then
      entities[unit_number] = nil
    end
  end
end

return warp_constant_combinator
