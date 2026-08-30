-- fixes for krastorio 2 spaced out
if mods["Krastorio2-spaced-out"] then
  local labs = data.raw.lab["kr-singularity-lab"]
  labs.surface_conditions = {
    {
      min = 1100,
      property = "pressure",
    },
    {
      min = 11,
      property = "gravity",
    },
  }
  local tech_card = data.raw["recipe"]["kr-singularity-tech-card"]
  tech_card.surface_conditions = nil
end
