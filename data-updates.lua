-- make sure that every water tile is walkable for enemies and player

for name,element in pairs(data.raw["tile"]) do
   local masks = element.collision_mask.layers
   if masks.water_tile and masks.player then
      masks.player = nil
      element.walking_speed_modifier = 0.4
   end
end
