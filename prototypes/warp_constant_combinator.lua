local combinator_item = table.deepcopy(data.raw["item"]["constant-combinator"])
combinator_item.name = "warp-constant-combinator"
combinator_item.place_result = "warp-constant-combinator"
combinator_item.order = "[circuit-network]-[warp-constant-combinator]"

local combinator_recipe = table.deepcopy(data.raw["recipe"]["constant-combinator"])
combinator_recipe.name = "warp-constant-combinator"
combinator_recipe.enabled = false
combinator_recipe.results = {{type = "item", name = "warp-constant-combinator", amount = 1}}

local combinator_entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator_entity.name = "warp-constant-combinator"
combinator_entity.minable = {mining_time = 0.1, result = "warp-constant-combinator"}

local warp_tint = {r = 0.55, g = 0.8, b = 1, a = 1}

if combinator_item.icon then
  combinator_item.icons = {{icon = combinator_item.icon, icon_size = combinator_item.icon_size, tint = warp_tint}}
  combinator_item.icon = nil
elseif combinator_item.icons then
  for _, icon_data in pairs(combinator_item.icons) do
    icon_data.tint = warp_tint
  end
end

local function tint_sprite(sprite)
  if not sprite then return end

  if sprite.layers then
    for _, layer in pairs(sprite.layers) do
      tint_sprite(layer)
    end
  end

  if sprite.filename and not sprite.draw_as_shadow and not string.find(sprite.filename, "shadow", 1, true) then
    sprite.tint = warp_tint
  end

  if sprite.hr_version then
    tint_sprite(sprite.hr_version)
  end
end

for _, direction in pairs(combinator_entity.sprites or {}) do
  tint_sprite(direction)
end

data:extend({
  combinator_item,
  combinator_recipe,
  combinator_entity,
})
