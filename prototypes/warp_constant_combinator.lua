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

data:extend({
  combinator_item,
  combinator_recipe,
  combinator_entity,
})
