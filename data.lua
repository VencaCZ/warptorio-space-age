local shared = require("shared")
require("research")
require("tips")
require("prototypes/entities")
require("prototypes/containers")
require("prototypes/collector_container")
require("prototypes/warp_constant_combinator")
require("prototypes/speech_bubble")

local function is_shadow(sprite)
  if sprite.draw_as_shadow then return true end
  if sprite.filename and string.find(sprite.filename, "shadow", 1, true) then return true end
  if sprite.filenames then
    for _, fn in ipairs(sprite.filenames) do
      if type(fn) == "string" and string.find(fn, "shadow", 1, true) then
        return true
      end
    end
  end
  return false
end

local function looks_like_sprite(t)
  if type(t) ~= "table" then return false end
  -- Common “sprite definition” indicators in Factorio prototypes:
  return t.filename ~= nil
      or t.filenames ~= nil
      or t.stripes ~= nil
      or t.layers ~= nil
      or t.hr_version ~= nil
end

local function tint_any_graphics(root, tint, visited)
  if type(root) ~= "table" then return end
  visited = visited or {}
  if visited[root] then return end
  visited[root] = true

  -- If this table is (or contains) a sprite definition, tint it and its known sub-shapes.
  if looks_like_sprite(root) then
    if not is_shadow(root) then
      -- You can add extra guards here if you only want to tint certain sprites.
      root.tint = tint
    end

    if root.layers then
      for _, layer in pairs(root.layers) do
        tint_any_graphics(layer, tint, visited)
      end
    end

    if root.hr_version then
      tint_any_graphics(root.hr_version, tint, visited)
    end
  end

  -- Walk everything else too (this is what makes it catch belt_animation_set, etc.)
  for _, v in pairs(root) do
    if type(v) == "table" then
      tint_any_graphics(v, tint, visited)
    end
  end
end

--shortcut
local shortcut = {
  type="shortcut",
  name=shared.shortcut_teleport,
  action="lua",
  icon="__warptorio-space-age__/graphics/home.png",
  small_icon="__warptorio-space-age__/graphics/home.png"
}
data:extend{shortcut}

--shortcut to toggle ground minimap
local minimap_shortcut = {
  type="shortcut",
  name=shared.shortcut_minimap_toggle,
  action="lua",
  toggleable=true,
  icon="__warptorio-space-age__/graphics/map.png",
  small_icon="__warptorio-space-age__/graphics/map.png"
}
data:extend{minimap_shortcut}

-- asteroid collectors

local collector = data.raw["asteroid-collector"]["asteroid-collector"]
collector.surface_conditions = nil
collector.tile_buildability_rules = nil

local thruster = data.raw["thruster"]["thruster"]
thruster.surface_conditions = nil
thruster.tile_buildability_rules = nil

--crusher

local crusher = data.raw["assembling-machine"]["crusher"]
crusher.surface_conditions = nil
crusher.tile_buildability_rules = nil

-- Asteroids
for _, i in pairs(data.raw["asteroid"]) do
    table.insert(
        i.dying_trigger_effect,
        {
            type = "script",
            effect_id = "asteroid"
        }
    )
end
--[[
for _,i_original in pairs(data.raw["asteroid-chunk"]) do
   if not string.match(i_original.name, "parameter") then
      local i = table.deepcopy(i_original)
      i.subgroup = "space-environment"
      i.type = "asteroid"
      i.is_military_target = false
      i.flags = {
        "placeable-enemy",
        "placeable-off-grid",
        "not-repairable",
        "not-on-map"
      }
      i.collision_mask = {
        layers = {
          object = true
        },
        not_colliding_with_itself = true
      }
      data:extend{i}
   end
end
]]--

-- promethium
local promethium = data.raw["recipe"]["promethium-science-pack"]
promethium.surface_conditions = nil
local chunk = table.deepcopy(data.raw["recipe"]["fluoroketone"])
chunk.ingredients = {
  {
    amount = 1000,
    name = "lava",
    type = "fluid"
  },
  {
    amount = 250,
    name = "ammonia",
    type = "fluid"
  },
  {
    amount = 10,
    name = "uranium-235",
    type = "item"
  },
  {
    amount = 200,
    name = "holmium-solution",
    type = "fluid"
  }
}
chunk.results = {
  {
    amount = 5,
    name = "promethium-asteroid-chunk",
    type = "item"
  }
}
chunk.name = "warp-promethium"
data:extend{chunk}


local tile_platform = table.deepcopy(data.raw["tile"][settings.startup["warptorio_factory-tile"].value])
tile_platform.minable_properties = {
  minable = false
}
tile_platform.name = shared.tiles.factory

local function set_destructable(tile,name)
   if tile.max_health then
      return
   end
   tile.max_health = 50
   tile.weight = 200
   tile.dying_explosion = "space-platform-foundation-explosion"
   tile.default_cover_tile = "empty-space"
   tile.is_foundation = true
   if tile.frozen_variant then
      set_destructable(data.raw["tile"][tile.frozen_variant])
   end
   if tile.thawed_variant then
      set_destructable(data.raw["tile"][tile.thawed_variant])
   end
   tile.minable_properties = {
      minable = false,
   }
   tile.name = name or tile.name
end

local foundation = data.raw["tile"]["space-platform-foundation"]
local tile_world = table.deepcopy(data.raw["tile"][settings.startup["warptorio_ground-tile"].value])
set_destructable(tile_world,shared.tiles.ground)

local function copy_build_animations(target, source)
  if not source then return end
  target.build_animations = target.build_animations or source.build_animations
  target.build_animations_background = target.build_animations_background or source.build_animations_background
  target.built_animation_frame = target.built_animation_frame or source.built_animation_frame
end

if foundation then
  copy_build_animations(tile_world, foundation)

  if tile_world.frozen_variant then
    local frozen = data.raw["tile"][tile_world.frozen_variant]
    if frozen then
      copy_build_animations(frozen, foundation)
    end
  end
  if tile_world.thawed_variant then
    local thawed = data.raw["tile"][tile_world.thawed_variant]
    if thawed then
      copy_build_animations(thawed, foundation)
    end
  end

  if foundation.build_animations then
    for _, dir in ipairs({"north", "south", "east", "west"}) do
      local anim = foundation.build_animations[dir]
      if anim and anim.layers then
        data:extend{{
          type = "explosion",
          name = shared.platform_build_anim .. "-" .. dir,
          flags = {"not-on-map"},
          animations = {{layers = util.table.deepcopy(anim.layers)}},
          sound = nil,
        }}
      end
    end
  end
end
data:extend{tile_platform,tile_world}

local function add_cluster_offsets(source, count, distance, angle_offset, t)
  for i = 0, count - 1 do
    local a = 2 * math.pi * (i + angle_offset) / count
    local tt = table.deepcopy(t)
    local x0 = distance * math.sin(a) * 0.75
    local x1 = distance * math.sin(a)
    local y0 = distance * math.cos(a) * 0.75
    local y1 = distance * math.cos(a)
    tt.offset_deviation = {{math.min(x0, x1), math.min(y0, y1)},
                           {math.max(x0, x1), math.max(y0, y1)}}
    source[#source + 1] = tt
  end
  return source
end

local function make_empty_animation(frame_count)
  return {
    filename = "__core__/graphics/empty.png",
    priority = "high",
    width = 1,
    height = 1,
    frame_count = 1,
    repeat_count = frame_count,
  }
end

local blue_light = {r=0.6, g=0.7, b=1.0}

local function make_ring_particle(name, filename, width, height, shift)
  return {
    type = "optimized-particle",
    name = name,
    life_time = 100,
    vertical_acceleration = 0,
    fade_away_duration = 60,
    render_layer = "object",
    pictures = {
      filename = filename,
      priority = "high",
      flags = {"smoke"},
      line_length = 8,
      width = width,
      height = height,
      frame_count = 32,
      animation_speed = 0.5,
      variation_count = 1,
      shift = shift,
      scale = 1.5 / 8,
      tint = {0.5, 0.5, 0.5, 1.0},
      blend_mode = "additive-soft",
    },
    shadows = {
      filename = filename,
      priority = "high",
      flags = {"smoke"},
      line_length = 8,
      width = width,
      height = height,
      frame_count = 32,
      animation_speed = 0.5,
      variation_count = 1,
      shift = shift,
      scale = 1.5 / 8,
      tint = {0, 0, 0, 0.5},
    },
  }
end

local function make_ring_particles()
  return {
    make_ring_particle(
      shared.teleport_ring_1,
      "__warptorio-space-age__/graphics/effects/teleport-ring-1.png",
      132, 136, util.by_pixel(-0.5, 0)),
    make_ring_particle(
      shared.teleport_ring_2,
      "__warptorio-space-age__/graphics/effects/teleport-ring-2.png",
      110, 128, util.by_pixel(0, 3)),
  }
end

local function make_teleport_ring_effect()
  return {
    type = "direct",
    action_delivery = {
      type = "instant",
      source_effects = add_cluster_offsets(
        add_cluster_offsets(
          {},
          8, 0.125, 0,
          {
            type = "create-particle",
            particle_name = shared.teleport_ring_1,
            repeat_count = 1,
            initial_height = 0.125,
            frame_speed = 1,
            frame_speed_variation = 0.25,
            tail_length = 12,
            tail_width = 8,
            speed_from_center = 0.015,
            speed_from_center_deviation = 0,
          }
        ),
        8, 0.125, 0.5,
        {
          type = "create-particle",
          particle_name = shared.teleport_ring_2,
          repeat_count = 1,
          initial_height = 0.125,
          frame_speed = 1,
          frame_speed_variation = 0.25,
          tail_length = 12,
          tail_width = 8,
          speed_from_center = 0.015,
          speed_from_center_deviation = 0,
        }
      ),
    },
  }
end

local rings = make_ring_particles()

data:extend({
  rings[1],
  rings[2],
  {
    type = "optimized-particle",
    name = shared.teleport_spark_particle,
    life_time = 20,
    fade_away_duration = 8,
    render_layer = "wires-above",
    render_layer_when_on_ground = "corpse",
    pictures = {
      sheet = {
        filename = "__base__/graphics/particle/pole-sparks/pole-sparks.png",
        draw_as_glow = true,
        line_length = 12,
        width = 6,
        height = 6,
        frame_count = 12,
        variation_count = 3,
        animation_speed = 2,
        scale = 0.5,
        shift = util.by_pixel(0, 0)
      }
    },
    movement_modifier_when_on_ground = 0,
  },
  {
    type = "explosion",
    name = shared.teleport_explosion,
    localised_name = {"entity-name.medium-explosion"},
    icon = "__base__/graphics/item-group/effects.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map"},
    hidden = true,
    subgroup = "explosions",
    render_layer = "higher-object-above",
    animations = {{
      filename = "__warptorio-space-age__/graphics/effects/teleport-explosion-1.png",
      priority = "high",
      width = 124,
      height = 224,
      frame_count = 30,
      line_length = 6,
      shift = util.by_pixel(-1, -20),
      draw_as_glow = true,
      animation_speed = 1,
      scale = 0.5,
    }, {
      filename = "__warptorio-space-age__/graphics/effects/teleport-explosion-2.png",
      priority = "high",
      width = 154,
      height = 212,
      frame_count = 41,
      line_length = 6,
      shift = util.by_pixel(-13, -18),
      draw_as_glow = true,
      animation_speed = 1,
      scale = 0.5,
    }, {
      filename = "__warptorio-space-age__/graphics/effects/teleport-explosion-3.png",
      priority = "high",
      width = 126,
      height = 236,
      frame_count = 39,
      line_length = 6,
      shift = util.by_pixel(0.5, -19),
      draw_as_glow = true,
      animation_speed = 1,
      scale = 0.5,
    }},
    light = {intensity = 0.8, size = 10, color = blue_light},
    sound = nil,
    created_effect = make_teleport_ring_effect(),
  },
  {
    type = "sound",
    name = shared.teleport_boom_sound,
    category = "explosion",
    aggregation = {max_count = 1, remove = true},
    audible_distance_modifier = 2,
    variations = {
      {filename = "__base__/sound/fight/nuclear-explosion-1.ogg", volume = 0.25},
      {filename = "__base__/sound/fight/nuclear-explosion-2.ogg", volume = 0.25},
      {filename = "__base__/sound/fight/nuclear-explosion-3.ogg", volume = 0.25},
    },
  },
  {
    type = "explosion",
    name = shared.teleport_spark_effect,
    localised_name = {"entity-name.small-explosion"},
    icon = "__base__/graphics/item-group/effects.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map"},
    hidden = true,
    subgroup = "explosions",
    light = {intensity = 0.25, size = 4, color = blue_light},
    animations = make_empty_animation(),
    sound = nil,
    created_effect = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          {
            type = "create-particle",
            particle_name = shared.teleport_spark_particle,
            repeat_count = 4,
            repeat_count_deviation = 2,
            initial_height = 0.75,
            initial_vertical_speed = 1.0 / 32,
            initial_vertical_speed_deviation = 1.0 / 128,
            tail_width = 4,
            tail_length = 10,
            frame_speed = 1,
            frame_speed_deviation = 0.25,
            speed_from_center = 0.0125,
            speed_from_center_deviation = 0.005,
            offset_deviation = {{-0.125, -0.125}, {0.125, 0.125}},
          },
        },
      },
    },
  },
})


--[[for name,element in pairs(data.raw["tile"]) do
   if string.find(name,"concrete") then
      set_destructable(data.raw["tile"][name],name)
   end
   end]]

local belt_speeds = shared.belt.speeds
local belt_color = {
  {1,1,0.5},
  {1,0.5,0.5},
  {0.5,0.5,1},
  {0.5,1,0.5}
}
for i,v in ipairs(belt_speeds) do
  local belt = table.deepcopy(data.raw["linked-belt"]["linked-belt"])
  belt.speed = v/480
  belt.minable_properties = {
    minable = false
  }
  belt.name = shared.belt.prefix..v
  tint_any_graphics(belt, belt_color[i])
  --belt.pictures.layers[1].tint = belt_color[i]
  data:extend{belt}
end

local acc = table.deepcopy(data.raw["accumulator"]["accumulator"])
acc.name = shared.power[1]
acc.collision_box = {{-0.5, -0.5}, {0.5, 0.5}}
acc.minable_properties = {
  minable = false
}
acc.energy_source = -- energy source of accumulator
{
  type = "electric",
  buffer_capacity = "1GJ",
  usage_priority = "tertiary",
  input_flow_limit = "1TW",
  output_flow_limit = "1TW"
}
data:extend{acc}

local acc = table.deepcopy(data.raw["accumulator"]["accumulator"])
acc.name = shared.power[2]
acc.collision_box = {{-0.5, -0.5}, {0.5, 0.5}}
acc.minable_properties = {
  minable = false
}
acc.energy_source = -- energy source of accumulator
{
  type = "electric",
  buffer_capacity = "5GJ",
  usage_priority = "tertiary",
  input_flow_limit = "1TW",
  output_flow_limit = "1TW"
}
data:extend{acc}

local acc = table.deepcopy(data.raw["accumulator"]["accumulator"])
acc.name = shared.power[3]
acc.collision_box = {{-0.5, -0.5}, {0.5, 0.5}}
acc.minable_properties = {
  minable = false
}
acc.energy_source = -- energy source of accumulator
{
  type = "electric",
  buffer_capacity = "25GJ",
  usage_priority = "tertiary",
  input_flow_limit = "1TW",
  output_flow_limit = "1TW"
}
data:extend{acc}

-- change space science so it can be made anywhere

local space_science = data.raw.recipe["space-science-pack"]
space_science.energy_required = 60
space_science.surface_conditions = nil

-- Change mining drills, so they have more modules with quality

local drill = data.raw["mining-drill"]["big-mining-drill"]
drill.quality_affects_module_slots = true

-- make wagons bigger and enable quality

local wagon = data.raw["cargo-wagon"]["cargo-wagon"]
wagon.quality_affects_inventory_size = true
wagon.inventory_size = 60

local wagon = data.raw["fluid-wagon"]["fluid-wagon"]
wagon.quality_affects_capacity = true
wagon.capacity = 125000

-- improve locomotive as well

local locomotive = data.raw["locomotive"]["locomotive"]
locomotive.equipment_grid = "spidertron-equipment-grid"

-- make rail supports longer

local support = data.raw["rail-support"]["rail-support"]
support.support_range = support.support_range * 3

-- sounds

data:extend{{
      type = "sound",
      name = shared.sounds.warp_start,
      filename = "__warptorio-space-age__/sounds/warp_start.wav",
      category = "environment",
}}

data:extend{{
      type = "sound",
      name = shared.sounds.warp_end,
      filename = "__warptorio-space-age__/sounds/warp_end.wav",
      category = "environment",
}}
data:extend{{
      type = "sound",
      name = shared.sounds.planet_change,
      filename = "__warptorio-space-age__/sounds/planet_change.wav",
      category = "alert",
} }
data:extend{{
      type = "sound",
      name = shared.sounds.boss_spawn,
      filename = "__warptorio-space-age__/sounds/boss_spawn.wav",
      category = "alert",
}}

-- Change bio-labs

local labs = data.raw["lab"]["biolab"]
labs.surface_conditions = {
   {
      min = 1100,
      property = "pressure"
   },
   {
      min = 11,
      property = "gravity"
   }
}

-- add gui style
local style = table.deepcopy(data.raw["gui-style"]["default"]["universe_frame"])
style.padding = 8
style.top_padding = 2
style.bottom_padding = 2
data.raw["gui-style"]["default"]["warptorio_frame"] = style

-- change flamethrower-ammo to light oil

local flamethrower_ammo = data.raw["recipe"]["flamethrower-ammo"]
flamethrower_ammo.ingredients = {
  {
    amount = 5,
    name = "steel-plate",
    type = "item"
  },
  {
    amount = 200,
    name = "light-oil",
    type = "fluid"
  },
}


-- make flametrower freeze on aquilo

local flamethrower_turret = data.raw["fluid-turret"]["flamethrower-turret"]
flamethrower_turret.heating_energy = "100kW"

local tesla_turret = data.raw["electric-turret"]["tesla-turret"]
tesla_turret.heating_energy = "100kW"

-- extra warptorio specific beacons

local beacon = data.raw["beacon"]["beacon"]

beacon.distribution_effectivity_bonus_per_quality_level = 0.25
beacon.quality_affects_module_slots = true
beacon.allowed_effects = {
   "consumption",
   "speed",
   "pollution",
   "quality"
}

-- rebalance tesla turrets
local tt = data.raw["electric-turret"]["tesla-turret"]
tt.attack_parameters.ammo_type.energy_consumption = "36MJ"
tt.energy_source.buffer_capacity = "72MJ"
local cat = data.raw["chain-active-trigger"]
cat["chain-tesla-gun-chain"].fork_chance_increase_per_quality_level = 0
cat["chain-tesla-turret-chain"].fork_chance_increase_per_quality_level = 0

-- rebalance automic bomb
-- atomic-bomb-wave: 400 -> 800
local wave = data.raw["projectile"]["atomic-bomb-wave"]
for _, eff in ipairs(wave.action[1].action_delivery.target_effects) do
  if eff.type == "damage" then eff.damage.amount = eff.damage.amount * 2 end
end

-- atomic-bomb-ground-zero-projectile: 100 -> 200
local gz = data.raw["projectile"]["atomic-bomb-ground-zero-projectile"]
for _, eff in ipairs(gz.action[1].action_delivery.target_effects) do
  if eff.type == "damage" then eff.damage.amount = eff.damage.amount * 2 end
end

-- atomic-rocket direct effect: 400 -> 800
local rocket = data.raw["projectile"]["atomic-rocket"]
for _, eff in ipairs(rocket.action.action_delivery.target_effects) do
  if eff.type == "damage" then eff.damage.amount = eff.damage.amount * 2 end
end

-- remove tile conversion from nuke explosions
for _, name in ipairs({"nuke-effects-nauvis", "nuke-effects-vulcanus"}) do
  local e = data.raw["explosion"][name]
  if e then e.created_effect = nil end
end

-- artillery-projectile: physical + explosion damage +50%
local art = data.raw["artillery-projectile"]["artillery-projectile"]
for _, eff in ipairs(art.action.action_delivery.target_effects) do
  if eff.type == "nested-result" then
    for _, sub in ipairs(eff.action.action_delivery.target_effects) do
      if sub.type == "damage" then sub.damage.amount = sub.damage.amount * 1.5 end
    end
  end
end

if mods["quality"] then
-- add new quality
data.extend({
   {
      type = "quality",
      name = shared.quality_warp,
      level = 11,
      color = {194, 54, 22},
      order = "f",
      subgroup = "qualities",
      icon = "__warptorio-space-age__/graphics/quality.png",
      beacon_power_usage_multiplier = 1,
      mining_drill_resource_drain_multiplier = 1,
      hidden_in_factoriopedia = true,
      hidden = true,
	}
})

local legendary = data.raw.quality["legendary"]
legendary.next = "warp"
legendary.next_probability = 0.01
end
--tt.energy_source.input_flow_limit = tt.energy_source.input_flow_limit * 3

--if mods["zzz-nonstandard-beacons"] then

--[[local test = table.deepcopy(data.raw["planet"]["nauvis"])
test.icon = "__warptorio-2.0__/graphics/destinations/moon.png"
test.icon_size = 128
test.name = "lost_factory"

--planet settings
test.distance = 4000000

data:extend{test}]]

--[[local warp_map_gen = require("surfaces")

local test = table.deepcopy(data.raw["planet"]["vulcanus"])
test.icon = "__warptorio-2.0__/graphics/destinations/moon.png"
test.icon_size = 128
test.name = "test"
test.map_gen_settings = warp_map_gen.test()

data:extend{test}

-- No idea how else get map_gen_settings durring run time

local base = data.raw["planet"]
local map_gen_settings = {}

for i,v in pairs(base) do
  map_gen_settings[i] = v.map_gen_settings
end


local bigpack = require("__big-data-string2__.pack")

local function set_my_data(name, data)
    return bigpack("warptorio-map-gen", serpent.dump(data))
end
-- use it like this
data:extend{set_my_data(name, map_gen_settings)}]]

-- ground minimap zoom controls
data:extend{{
   type = "custom-input",
   name = shared.input_minimap_zoom_in,
   key_sequence = "SHIFT + mouse-wheel-up",
   consuming = "game-only",
   action = "lua",
}}
data:extend{{
   type = "custom-input",
   name = shared.input_minimap_zoom_out,
   key_sequence = "SHIFT + mouse-wheel-down",
   consuming = "game-only",
   action = "lua",
}}

-- Cross-mod custom events, raised in modules/events.lua.
-- Other mods subscribe: script.on_event(defines.events["warptorio-..."], handler)
local custom_events = {}
for _, name in ipairs({
  shared.events.warp_started,
  shared.events.warp_finished,
  shared.events.planet_chosen,
  shared.events.wave_spawned,
  shared.events.boss_spawned,
  shared.events.boss_died,
  shared.events.game_over,
  shared.events.game_win,
}) do
  custom_events[#custom_events + 1] = { type = "custom-event", name = name }
end
data:extend(custom_events)

-- Hidden signal that carries the warp-distance (void) destination icon, used as
-- rich text in chat so the next-destination message shows an icon like real planets.
data:extend{{
   type = "virtual-signal",
   name = "warptorio-void-destination",
   icon = "__warptorio-space-age__/graphics/destinations/deep-space.png",
   icon_size = 256,
   localised_name = {"virtual-signal-name.warptorio-void-destination"},
   subgroup = "virtual-signal",
   order = "zz[warptorio-void]",
   hidden = true,
}}
