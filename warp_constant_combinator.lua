local warp_settings = require("internal_settings")

local warp_constant_combinator = {}

local COMBINATOR_NAME = "warp-constant-combinator"

-- Slots 1-6 are the fixed virtual signals (T, W, V, A, J, D); the two planet signals
-- follow them at slots that never move, so each always means the same thing.
local SLOT_CURRENT_PLANET = 7
local SLOT_NEXT_PLANET = 8

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

-- The platform counts as "in transition" from next_warp_zone_prepare() until
-- next_warp_zone_finish() lands it on the new planet. transition_timer runs down to
-- 0 across that window and then goes negative for the post-warp grace period, so
-- teleporting is what gates both signals. Returns (in_transition, seconds_left).
local function get_transition_state()
  if not storage.warptorio or not storage.warptorio.teleporting then
    return 0, 0
  end
  local ticks = storage.warptorio.transition_timer or 0
  return 1, math.max(0, math.ceil(ticks / 60))
end

-- A param with no signal clears its slot. Slots are sticky once written, so a signal
-- that stops applying has to be cleared explicitly or the old value sits there forever.
local function set_parameters(section, parameters)
   for _,param in ipairs(parameters) do
      if param.signal then
         param.signal.quality="normal"
         section.set_slot(
            param.index,
            {
               value = param.signal,
               min=param.count,
               max=param.count
            }
         )
      else
         section.clear_slot(param.index)
      end
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

local function update_entity(entity, state)
  if not entity.valid then
    return false
  end

  local control_behavior = entity.get_or_create_control_behavior()

  local section = control_behavior.get_section(1)

  entity.combinator_description = [[
  signal-T - Remaining time before forced warp
  signal-W - Wave count
  signal-V - Remaining time before next enemy wave
  signal-A - Warp count
  signal-J - 1 while the platform is warping between planets
  signal-D - Seconds remaining of the warp transition
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
    {index = 1, signal = {type = "virtual", name = "signal-T"}, count = math.floor(state.remaining_time)},
    {index = 2, signal = {type = "virtual", name = "signal-W"}, count = state.wave_index},
    {index = 3, signal = {type = "virtual", name = "signal-V"}, count = math.floor(state.wave_time)},
    {index = 4, signal = {type = "virtual", name = "signal-A"}, count = state.warp_amount},
    {index = 5, signal = {type = "virtual", name = "signal-J"}, count = state.in_transition},
    {index = 6, signal = {type = "virtual", name = "signal-D"}, count = state.transition_time},
  }

  -- Fixed slots. Indexing off #parameters let the next planet slide into the current
  -- planet's slot whenever the current one had no signal (void, or mid-transition),
  -- which both changed what a slot meant and stranded the old value in the slot below.
  local current_name = storage.warptorio.surface_name
  local next_name = storage.warptorio.planet_next
  local current_planet_signal = get_planet_signal(current_name)
  local next_planet_signal = get_planet_signal(next_name)

  if current_planet_signal and current_name == next_name then
     -- Staying put (nauvis): one signal carries both roles, so 1 + 2. Comparing the
     -- signal tables here never matched — get_planet_signal builds a fresh table per
     -- call, so it was reference equality against a different table every time.
     table.insert(parameters, {index = SLOT_CURRENT_PLANET, signal = current_planet_signal, count = 3})
     table.insert(parameters, {index = SLOT_NEXT_PLANET})
  else
     table.insert(parameters, {index = SLOT_CURRENT_PLANET, signal = current_planet_signal, count = 1})
     table.insert(parameters, {index = SLOT_NEXT_PLANET, signal = next_planet_signal, count = 2})
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
  local in_transition, transition_time = get_transition_state()

  local state = {
    remaining_time = remaining_time,
    wave_index = wave_index,
    wave_time = wave_time,
    warp_amount = warp_amount,
    in_transition = in_transition,
    transition_time = transition_time,
  }

  for unit_number, entity in pairs(entities) do
    local ok = update_entity(entity, state)
    if not ok then
      entities[unit_number] = nil
    end
  end
end

return warp_constant_combinator
