data:extend({
  {
    type = "tips-and-tricks-item-category",
    name = "warptorio",
    order = "a",
  },
  {
    type = "tips-and-tricks-item",
    name = "warptorio",
    category = "warptorio",
    order = "a",
    starting_status = "unlocked",
    is_title = true,
  },
  {
    type = "tips-and-tricks-item",
    name = "warptorio-warp-trains",
    tag = "[entity=locomotive]",
    order = "z[warptorio]-b[warp-trains]",
    category = "warptorio",
    trigger = {
      type = "research",
      technology = "warp-train"
    },
    is_title = false,
    indent = 1,
    simulation = nil,
  },
  {
    type = "tips-and-tricks-item",
    name = "warptorio-evolution-scaling",
    tag = "[entity=big-biter]",
    order = "z[warptorio]-c[evolution-scaling]",
    category = "warptorio",
    trigger = {
      type = "research",
      technology = "warp-ground-platform-3"
    },
    is_title = false,
    indent = 1,
    simulation = nil,
  }

})
