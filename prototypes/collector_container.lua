-- by sevenno07
local cargo_chest_item = table.deepcopy(data.raw["item"]["cargo-bay"])
cargo_chest_item.order = "c[cargo-bay]b"
cargo_chest_item.name = "warp-asteroid-chest"
cargo_chest_item.place_result = "warp-asteroid-chest"
data:extend({cargo_chest_item})

local cargo_chest_recipe = table.deepcopy(data.raw["recipe"]["cargo-bay"])
cargo_chest_recipe.name = "warp-asteroid-chest"
cargo_chest_recipe.results = {{type="item", name="warp-asteroid-chest", amount=1}}
data:extend({cargo_chest_recipe})

local cargo_chest_entity = table.deepcopy(data.raw["container"]["steel-chest"])
cargo_chest_entity.name= "warp-asteroid-chest"
cargo_chest_entity.icon = "__space-age__/graphics/icons/cargo-bay.png"
cargo_chest_entity.minable = {mining_time = 1, result = "warp-asteroid-chest"}
cargo_chest_entity.max_health = 1000
cargo_chest_entity.inventory_size = 20
cargo_chest_entity.collision_box = {{-1.9, -1.9}, {1.9, 1.9}}
cargo_chest_entity.selection_box = {{-2, -2}, {2, 2}}
cargo_chest_entity.corpse = "cargo-bay-remnants"
cargo_chest_entity.dying_explosion = "electric-furnace-explosion"
cargo_chest_entity.picture =
  {
    layers =
    {
      {
        filename = "__warptorio-space-age__/graphics/entities/cargo-chest.png",
        priority = "extra-high",
        width = 512,
        height = 384,
        shift = util.by_pixel(32, 0),
        scale = 0.5
      },
      {
        filename = "__warptorio-space-age__/graphics/entities/cargo-chest-shadow.png",
        priority = "extra-high",
        width = 512,
        height = 384,
        shift = util.by_pixel(32, 0),
        draw_as_shadow = true,
        scale = 0.5
      },
      {
        filename = "__warptorio-space-age__/graphics/entities/cargo-chest-glow.png",
        priority = "extra-high",
        width = 512,
        height = 384,
        shift = util.by_pixel(32, 0),
        draw_as_glow = true,
        blend_mode = "additive",
        scale = 0.5
      }
    }
  }
data:extend({cargo_chest_entity})
