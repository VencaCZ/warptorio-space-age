-- Boss spawning, boss tracking and boss loot drops.
-- Owns the full boss lifecycle: spawn check, spawn, registry of spawned
-- bosses (unit_number -> quality) and loot spilled on death.
local M = {}

local warp_settings = require("internal_settings")
local shared = require("shared")
local events = require("modules.events")

local deps = {}

local function ensure_boss_registry()
  if not storage.warptorio.bosses then storage.warptorio.bosses = {} end
  return storage.warptorio.bosses
end

local function boss_tag_force()
  return game.forces.player
end

-- Map (chart) tags chase boss units so they read as boss-sized skull markers
-- instead of the tiny red dots normal enemies get.
local function update_boss_tag(entity, boss)
  if boss and boss.tag and boss.tag.valid then
    boss.tag.position = {x = entity.position.x, y = entity.position.y}
    return
  end
  if entity and entity.valid then
    local ok, tag = pcall(function()
      return boss_tag_force().add_chart_tag(entity.surface, {
        position = {x = entity.position.x, y = entity.position.y},
        icon = {type = "virtual", name = "signal-skull"},
      })
    end)
    if ok and tag then boss.tag = tag end
  end
end

local function destroy_boss_tag(boss)
  if boss and boss.tag and boss.tag.valid then
    boss.tag.destroy()
    boss.tag = nil
  end
end

local HEALTH_BAR_LENGTH = 15

-- Biter Battles style lives: a boss copy has boss_life_health max health
-- (data-final-fixes) and spawns with ceil(boss_lives * evolution) lives.
-- Whenever its health hits 0 with lives left, on_damaged refills it and
-- spends a life; the bar above it shows the lives left.
local function lives_at_evolution(entity)
  local ok, evo = pcall(function() return game.forces.enemy.get_evolution_factor(entity.surface) end)
  if not ok then evo = 0 end
  return math.max(1, math.ceil(warp_settings.biter.boss_lives * evo))
end

local function update_health_bar(entity, boss)
  local cfg = warp_settings.biter
  local ratio = boss.lives / boss.lives_total
  if cfg.boss_health_bar then
    if not (boss.bar and boss.bar.valid) then
      boss.bar = rendering.draw_sprite{
        sprite = "virtual-signal/signal-white",
        x_scale = 0.55 * HEALTH_BAR_LENGTH,
        y_scale = 0.55,
        render_layer = "light-effect",
        target = {entity = entity, offset = {0, -2.5}},
        surface = entity.surface,
      }
    end
    boss.bar.x_scale = 0.55 * HEALTH_BAR_LENGTH * ratio
    boss.bar.color = {math.floor(255 - 255 * ratio), math.floor(200 * ratio), 0}
  end
  if cfg.boss_label and not (boss.text and boss.text.valid) then
      boss.text = rendering.draw_text{
        text = {"warptorio.boss-label"},
        surface = entity.surface,
        target = {entity = entity, offset = {0, -3.2}},
        scale = 1.5,
        alignment = "center",
        color = {1, 1, 1},
      }
  end
end

-- previous = {lives, lives_total, health} carries a boss over a quality
-- replacement.
local function register_boss_entity(entity, quality, previous)
  if not entity or not entity.valid then return end
  local boss = ensure_boss_registry()[entity.unit_number]
  if not boss then
    boss = {}
    ensure_boss_registry()[entity.unit_number] = boss
  end
  boss.quality = quality
  -- Keep the entity itself: game.get_entity_by_unit_number returns nil for
  -- units without the get-by-unit-number prototype flag (biters, pentapods).
  boss.entity = entity
  local cfg = warp_settings.biter
  if (cfg.boss_lives_types or {})[entity.type] and (cfg.boss_lives or 0) > 0 then
    if previous and previous.lives then
      boss.lives, boss.lives_total = previous.lives, previous.lives_total
      if previous.health and previous.health > 0 then
        entity.health = math.min(entity.max_health, previous.health)
      end
    else
      boss.lives = lives_at_evolution(entity)
      boss.lives_total = boss.lives
      entity.health = entity.max_health
    end
    update_health_bar(entity, boss)
  end
  update_boss_tag(entity, boss)
  return boss
end

-- Called from on_entity_damaged. Like Biter Battles' boss_unit: only acts on
-- the killing hit (health 0) and refills the unit, which cancels the death.
function M.on_damaged(e)
  local entity = e.entity
  if not (entity and entity.valid and entity.unit_number) then return false end
  local bosses = storage.warptorio and storage.warptorio.bosses
  local boss = bosses and bosses[entity.unit_number]
  if not (boss and boss.lives) then return false end
  if entity.health == 0 and boss.lives > 1 then
    boss.lives = boss.lives - 1
    entity.health = entity.max_health
    update_health_bar(entity, boss)
  end
  return true
end

-- Tops the current health up to the (quality-scaled) max.
function M.scale_health(entity)
  if entity and entity.valid and entity.max_health then
    entity.health = entity.max_health
  end
end

local module_pool_cache = {}
-- tier_max is 1..5 (normal/uncommon/rare/epic/legendary); each bucket holds
-- every module whose tier is <= tier_max, so higher tiers only widen the pool.
local function get_module_pool(tier_max)
  if not module_pool_cache[tier_max] then
    local pool = {}
    for name, proto in pairs(prototypes.item) do
      if proto.type == "module" then
        local tier = tonumber(name:match("-(%d+)$")) or 1
        if tier <= tier_max then table.insert(pool, name) end
      end
    end
    module_pool_cache[tier_max] = pool
  end
  return module_pool_cache[tier_max]
end

local function get_science_pool()
  local packs = {}
  local force = game.forces.player
  for name, proto in pairs(prototypes.item) do
    if proto.type == "tool" and proto.subgroup.name == "science-pack" and name ~= "promethium-science-pack" then
      local recipe = force.recipes[name]
      if recipe and recipe.enabled then table.insert(packs, name) end
    end
  end
  return packs
end

local function drop_boss_loot(entity, quality)
  if not settings.global["warptorio_boss-loot"].value then return end
  local chance = settings.global["warptorio_boss-loot-chance"].value / 100
  if math.random() > chance then return end
  local max_count = settings.global["warptorio_boss-loot-count"].value
  if max_count < 1 then return end
  -- Loot tier keeps climbing with warp index instead of capping at rare.
  local warp_index = (storage.warporio and storage.warporio.index) or 1
  local tier_max = warp_index <= 2 and 1
    or (warp_index <= 4 and 2
    or (warp_index <= 8 and 3
    or (warp_index <= 15 and 4
    or 5)))
  local surface = entity.surface
  local pos = entity.position
  -- Guaranteed drop on a successful roll; grows slowly with progression.
  local count = math.max(1, math.min(max_count, 1 + math.floor(warp_index / 10)))
  local name
  if math.random(2) == 1 then
    local packs = get_science_pool()
    if #packs > 0 then name = packs[math.random(#packs)] end
  end
  if not name then
    local pool = get_module_pool(tier_max)
    if #pool > 0 then name = pool[math.random(#pool)] end
  end
  if name then
    surface.spill_item_stack{
      position = pos,
      stack = {name = name, count = count, quality = quality},
      enable_looted = false,
      force = "player",
      allow_belts = false,
    }
  end
end

local function boss_chance_for_wave(wave)
  local cfg = warp_settings.biter
  if wave < (cfg.boss_first_wave or 10) then return 0 end
  local every = cfg.boss_guaranteed_every or 10
  if every > 0 and wave % every == 0 then return 1 end
  if wave > cfg.wave_change_max then
    return math.min(cfg.wave_change_cap, cfg.wave_change_chance + (wave - cfg.wave_change_max) * cfg.wave_ramp)
  end
  if wave > cfg.wave_change_index then
    return cfg.wave_change_chance
  end
  return 0
end

function M.spawn_boss_check()
  -- Called before the wave counter is incremented, so the wave being spawned
  -- is counter+1 (this also keeps wave 1 from matching "% 10 == 0").
  -- boss_spawned_warp is set by check_wave after the first boss wave of a
  -- warp and cleared on the next jump; it always silences the repeat
  -- warning, and with boss_once_per_warp it also stops further boss waves.
  if warp_settings.biter.boss_once_per_warp and storage.warptorio.boss_spawned_warp then return false end
  local wave = (storage.warptorio.wave_index or 0) + 1
  return math.random() < boss_chance_for_wave(wave)
end

-- Number of bosses still alive, used to cap concurrent bosses from the calm
-- every-other-wave cadence (registry is swept once per second by M.update).
function M.alive_boss_count()
  if not storage.warptorio or not storage.warptorio.bosses then return 0 end
  local count = 0
  for _, boss in pairs(storage.warptorio.bosses) do
    if boss.entity and boss.entity.valid then count = count + 1 end
  end
  return count
end

-- Vanilla and 3rd-party bosses get enlarged private prototypes (bigger
-- collision box -> bigger red dot on the map). The candidate set comes from
-- the same internal_settings pools data-final-fixes uses, so both stay in sync.
local boss_footprint_names
local function ensure_boss_footprint_names()
  if not boss_footprint_names then
    boss_footprint_names = {}
    local biter = warp_settings.biter
    local boss_cfg = biter.entity_type or {}
    for _, tier in ipairs(boss_cfg.boss or {}) do
      for _, name in ipairs(tier) do boss_footprint_names[name] = true end
    end
    for _, name in ipairs(biter.boss_extra or {}) do boss_footprint_names[name] = true end
    for name in pairs(boss_cfg.boss_planet or {}) do boss_footprint_names[name] = true end
    for name in pairs(boss_cfg.boss_rare_planets or {}) do boss_footprint_names[name] = true end
  end
  return boss_footprint_names
end
-- boss_planet / boss_rare_planets store PREFIXES (maf-boss-explosive matches
-- maf-boss-explosive-biter-1), so a name hits the footprint set on an exact
-- match OR by prefix, mirroring the data-stage want_boss seeding.
local function boss_footprint(name)
  local names = ensure_boss_footprint_names()
  if names[name] then return true end
  for prefix in pairs(names) do
    if name:sub(1, #prefix) == prefix then return true end
  end
  return false
end
local boss_prototype_cache = {}
function M.boss_prototype(name)
  local custom = boss_prototype_cache[name]
  if custom == nil then
    custom = false
    if boss_footprint(name) then
      local expanded = name .. "-warptorio-boss"
      custom = prototypes.entity[expanded] and expanded or false
    end
    boss_prototype_cache[name] = custom
  end
  return custom or name
end

-- opts (optional): angle / range override the spawn point; escort =
-- {types = {...}, count = n} adds that many regular units to the same group.
function M.create_angry_biters(biter_type,number,surface,quality,target,is_boss,opts)
   opts = opts or {}
   local target = target or {x=0,y=0}
   if surface == "space" then
      deps.create_asteroids(number,surface)
      return
   end
   local quality = quality or "normal"
   if storage.warptorio.void then return end

   -- Create attack force for platform
   local angle = opts.angle or math.random()*2*math.pi
   local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
   local dist = warp_settings.floor.levels[level]
   local range = opts.range or 300
   local offset = deps.get_surface_offset(surface)
   local center = {x = offset.x + (target.x or 0), y = offset.y + (target.y or 0)}
   local x = center.x + math.cos(angle)*(dist+range)
   local y = center.y + math.sin(angle)*(dist+range)

   local unit_group = game.surfaces[surface].create_unit_group({ position = {x=x,y=y}, force = "enemy" })

   local dx = center.x - x
   local dy = center.y - y
   local four_directions = {
      north = defines.direction.north,
      east  = defines.direction.east,
      south = defines.direction.south,
      west  = defines.direction.west,
   }
   local facing
   if math.abs(dx) > math.abs(dy) then
      facing = dx > 0 and four_directions.east or four_directions.west
   else
      facing = dy > 0 and four_directions.south or four_directions.north
   end

   for j = 1,number do

      local spawn_type = is_boss and M.boss_prototype(biter_type) or biter_type
      local pos = game.surfaces[surface].find_non_colliding_position(spawn_type, {x,y}, 0, 2, false) or {x,y}

      local angry_bitter = game.surfaces[surface].create_entity{
         name = spawn_type,
         position = pos,
         direction = facing,
         quality = quality}
      if angry_bitter and angry_bitter.valid then
         if is_boss then
            M.scale_health(angry_bitter)
            register_boss_entity(angry_bitter, quality)
         end
         unit_group.add_member(angry_bitter)
      end
   end

   if opts.escort and #opts.escort.types > 0 then
      for j = 1, opts.escort.count do
         local escort_type = opts.escort.types[math.random(#opts.escort.types)]
         local pos = game.surfaces[surface].find_non_colliding_position(escort_type, {x,y}, 0, 2, false) or {x,y}
         local escort = game.surfaces[surface].create_entity{
            name = escort_type,
            position = pos,
            direction = facing,
            quality = opts.escort.quality or quality}
         if escort and escort.valid then unit_group.add_member(escort) end
      end
   end

   unit_group.set_command({
         type=defines.command.attack_area,
         destination={
            x=center.x,
            y=center.y
         },
         radius=dist
   })
   unit_group.start_moving()
end

function M.create_angry_boss(biter_type,number,surface,quality,target,angle)
  local target = target or {x=0,y=0}
  local quality = quality or "normal"
  if storage.warptorio.void then return end

  -- Create attack force for platform
  angle = angle or math.random()*2*math.pi
  local level = storage.warptorio.ground_level > 0 and storage.warptorio.ground_level or 1
  local dist = warp_settings.floor.levels[level]
  local range = 125
  local offset = deps.get_surface_offset(surface)
  local center = {x = offset.x + (target.x or 0), y = offset.y + (target.y or 0)}
  local x = center.x + math.cos(angle)*(dist+range)
  local y = center.y + math.sin(angle)*(dist+range)
  local dx = center.x - x
  local dy = center.y - y
  local four_directions = {
     north = defines.direction.north,
     east  = defines.direction.east,
     south = defines.direction.south,
     west  = defines.direction.west,
  }
  local facing
  if math.abs(dx) > math.abs(dy) then
     facing = dx > 0 and four_directions.east or four_directions.west
  else
     facing = dy > 0 and four_directions.south or four_directions.north
  end

  local spawned = 0
  for j = 1,number do
    local spawn_type = M.boss_prototype(biter_type)
    local pos = game.surfaces[surface].find_non_colliding_position(spawn_type, {x,y}, 0, 2, false) or {x,y}
    local angry_bitter = game.surfaces[surface].create_entity{
       name = spawn_type,
       position = pos,
       direction = facing,
       quality = quality}
    if angry_bitter and angry_bitter.valid then
      M.scale_health(angry_bitter)
      register_boss_entity(angry_bitter, quality)
      spawned = spawned + 1
    end
  end

  -- Charge the platform center (not a point offset past it).
  game.surfaces[surface].set_multi_command{
    command={
      type=defines.command.attack_area,
      destination={x=center.x, y=center.y},
      radius=dist,
    },
    unit_count=spawned
  }
end

-- Register an existing entity as boss (e.g. after a quality replacement
-- recreates it under a new unit number).
function M.register(entity, quality, previous)
  register_boss_entity(entity, quality, previous)
end

-- Number of boss units currently alive on any surface. The registry is swept
-- once per second by M.update, and validity is double-checked for safety.
function M.alive_count()
  if not storage.warptorio or not storage.warptorio.bosses then return 0 end
  local count = 0
  for _, boss in pairs(storage.warptorio.bosses) do
    if boss.entity and boss.entity.valid then count = count + 1 end
  end
  return count
end

-- Move boss chart tags and sweep registry entries whose unit died without
-- firing on_entity_died. Cheap enough to call once per second, not per tick.
function M.update()
  if not storage.warptorio or not storage.warptorio.bosses then return end
  local bosses = storage.warptorio.bosses
  for unit_number, boss in pairs(bosses) do
    local entity = boss.entity
    if not entity or not entity.valid then
      destroy_boss_tag(boss)
      bosses[unit_number] = nil
    else
      update_boss_tag(entity, boss)
    end
  end
end

-- Called from the on_entity_died handler; drops loot if the entity was a boss.
function M.on_boss_died(entity)
  if not storage.warptorio or not storage.warptorio.bosses then return end
  local boss = storage.warptorio.bosses[entity.unit_number]
  if boss then
    storage.warptorio.bosses[entity.unit_number] = nil
    destroy_boss_tag(boss)
    drop_boss_loot(entity, boss.quality)
    events.raise(shared.events.boss_died, {
      unit_number = entity.unit_number,
      surface = entity.surface and entity.surface.name or nil,
      quality = boss.quality,
      index = (storage.warporio and storage.warporio.index) or 0,
    })
    -- Taking down a boss shortens the wait until the next push.
    if storage.warptorio.wave_time then
      storage.warptorio.wave_time = math.max(warp_settings.biter.min, storage.warptorio.wave_time - warp_settings.biter.boss_kill_time)
    end
  end
end

-- Called from script_raised_destroy; removes stale registry entries.
function M.unregister(entity)
  if storage.warptorio and storage.warptorio.bosses and entity and entity.unit_number then
    local boss = storage.warptorio.bosses[entity.unit_number]
    if boss then
      destroy_boss_tag(boss)
      storage.warptorio.bosses[entity.unit_number] = nil
      events.raise(shared.events.boss_died, {
        unit_number = entity.unit_number,
        surface = entity.surface and entity.surface.name or nil,
        quality = boss.quality,
        index = (storage.warporio and storage.warporio.index) or 0,
      })
    end
  end
end

function M.init(d)
  deps = d or {}
end

return M
