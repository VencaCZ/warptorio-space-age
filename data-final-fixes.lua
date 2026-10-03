

-- fixes for krastorio 2 spaced out
if mods["Krastorio2-spaced-out"] then
   local labs = data.raw.lab["kr-singularity-lab"]
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
   local tech_card = data.raw["recipe"]["kr-singularity-tech-card"]
   tech_card.surface_conditions = nil
end

-- teleport arrival sound
data:extend{{
   type = "sound",
   name = "warptorio-teleport",
   filename = "__warptorio-space-age__/sounds/teleport.ogg",
   volume = 1.0,
   audible_distance_modifier = 2,
}}

for _, prototypes in pairs(data.raw) do
   if prototypes["fulgoran-ruin-attractor"] then
      prototypes["fulgoran-ruin-attractor"].alert_when_damaged = false
   end
end

-- Bosses get private, enlarged prototypes so they read as big red dots on the
-- map (chart dots scale with the entity's collision box, same trick Space Age
-- uses for pentapods/worms). The set is driven by the boss pools in
-- internal_settings so vanilla AND 3rd-party bosses (maf-boss-*, ...) get one,
-- and new pools need no data-stage code. Spawning is script-driven, so they
-- copy only needs to exist when the base entity does.
local boss_box_scale = 1.5
local warp_cfg = require("internal_settings")
local boss_min_box = warp_cfg.biter.boss_min_box or 1
-- Uniformly scale a bounding box by boss_box_scale, but never leave it smaller
-- than boss_min_box in either axis: small-biter bosses (collision ~0.4) must
-- keep up with pentapod bosses or they render as biter-sized map dots.
local function boss_box(v)
  local hx = math.max(math.abs(v[1][1]) or 0, math.abs(v[2][1]) or 0)
  local hy = math.max(math.abs(v[1][2]) or 0, math.abs(v[2][2]) or 0)
  local f = boss_box_scale
  local m = math.max(hx, hy)
  if m > 0 then
    local floor = boss_min_box / m
    if floor > f then f = floor end
  end
  return {{v[1][1] * f, v[1][2] * f}, {v[2][1] * f, v[2][2] * f}}
end
-- Entity types that get boss copies. "unit" copies are also enlarged;
-- pentapods (spider-unit) already read as big map dots, so their copies only
-- get the boss health. Demolishers (segmented-unit) stay untouched.
local enemy_types = {"unit", "spider-unit"}

local want_boss = {}
do
  local biter = warp_cfg.biter
  local boss_cfg = biter.entity_type or {}
  -- The boss pool lives under entity_type.boss (sibling of the per-planet
  -- wave tables), not biter.boss.
  for _, tier in ipairs(boss_cfg.boss or {}) do
    for _, name in ipairs(tier) do want_boss[name] = true end
  end
  for _, name in ipairs(biter.boss_extra or {}) do want_boss[name] = true end
  -- Boss tiers expanded per mod at runtime don't exist at data stage, so for
  -- modded bosses (maf-boss-*) seed the set from the boss_planet /
  -- boss_rare_planets prefixes by matching live entity names.
  local prefixes = {}
  for p in pairs(boss_cfg.boss_planet or {}) do prefixes[p] = true end
  for p in pairs(boss_cfg.boss_rare_planets or {}) do prefixes[p] = true end
  for _, type_name in ipairs(enemy_types) do
    local prototypes = data.raw[type_name] or {}
    for name in pairs(prototypes) do
      for p in pairs(prefixes) do
        if name:sub(1, #p) == p then want_boss[name] = true end
      end
    end
  end
end

for _, type_name in ipairs(enemy_types) do
   local prototypes = data.raw[type_name] or {}
   for name, base in pairs(prototypes) do
      if want_boss[name] then
         local boss = table.deepcopy(base)
         boss.name = name .. "-warptorio-boss"
         -- Reuse the base unit's locale instead of an entry per boss copy.
         boss.localised_name = base.localised_name or {"entity-name." .. name}
         boss.localised_description = base.localised_description
            or {"?", {"entity-description." .. name}, ""}
         if type_name == "unit" then
            if boss.collision_box then
               boss.collision_box = boss_box(boss.collision_box)
            end
            if boss.selection_box then
               boss.selection_box = boss_box(boss.selection_box)
            end
         end
         -- One boss life = the copy's full health bar; the lives themselves
         -- are revives handled at runtime (boss_system.on_damaged).
         local biter_cfg = warp_cfg.biter
         if (biter_cfg.boss_lives_types or {})[type_name] and (biter_cfg.boss_lives or 0) > 0 then
            boss.max_health = biter_cfg.boss_life_health
         end
         boss.map_generator_bounding_box = nil
         data:extend{boss}
      end
   end
end
