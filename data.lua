	require("research")
require("prototypes/entities")
require("prototypes/containers")
require("prototypes/collector_container")
--shortcut
local shortcut = {
  type="shortcut",
  name="warptorio-teleport",
  action="lua",
  icon="__warptorio-space-age__/graphics/home.png",
  small_icon="__warptorio-space-age__/graphics/home.png"
}
data:extend{shortcut}

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
tile_platform.name = "warp_tile_platform"

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
set_destructable(tile_world,"warp_tile_world")
data:extend{tile_platform,tile_world}

--[[for name,element in pairs(data.raw["tile"]) do
   if string.find(name,"concrete") then
      set_destructable(data.raw["tile"][name],name)
   end
   end]]

local belt_speeds = {15,30,45,60}
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
  belt.name = "warp-platform-belt-"..v
  --belt.pictures.layers[1].tint = belt_color[i]
  data:extend{belt}
end

local acc = table.deepcopy(data.raw["accumulator"]["accumulator"])
acc.name = "warp-power"
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
acc.name = "warp-power-2"
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
acc.name = "warp-power-3"
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

data.raw["recipe"]["space-science-pack"] = {
   allow_productivity = true,
   enabled = false,
   energy_required = 60,
   icon = "__base__/graphics/icons/space-science-pack.png",
   ingredients = {
      {
         amount = 2,
         name = "iron-plate",
         type = "item"
      },
      {
         amount = 1,
         name = "carbon",
         type = "item"
      },
      {
         amount = 1,
         name = "ice",
         type = "item"
      }
   },
   main_product = "space-science-pack",
   name = "space-science-pack",
   results = {
      {
         amount = 5,
         name = "space-science-pack",
         type = "item"
      }
   },
   surface_conditions = {
      {
         max = 10,
         min = 0,
         property = "gravity"
      }
   },
   type = "recipe"
}

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
      name = "warp-start",
      filename = "__warptorio-space-age__/sounds/warp_start.wav",
      category = "environment",
}}

data:extend{{
      type = "sound",
      name = "warp-end",
      filename = "__warptorio-space-age__/sounds/warp_end.wav",
      category = "environment",
}}
data:extend{{
      type = "sound",
      name = "planet-change",
      filename = "__warptorio-space-age__/sounds/planet_change.wav",
      category = "environment",
} }
data:extend{{
      type = "sound",
      name = "boss-spawn",
      filename = "__warptorio-space-age__/sounds/boss_spawn.wav",
      category = "environment",
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

--change flamethrower-ammo to light oil

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
