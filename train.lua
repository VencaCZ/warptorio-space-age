local train_code = {}

local zero_offset = {x=0, y=0}

local function get_surface_offset(surface_name)
  if storage.warptorio and storage.warptorio.surface_positions then
    return storage.warptorio.surface_positions[surface_name] or zero_offset
  end
  return zero_offset
end

-- Returns true if the full train footprint is clear on the destination surface
-- destination_surface MUST be a LuaSurface
function train_code.is_train_footprint_clear(train, destination_surface, source_station, target_station)
   local surface = destination_surface

   for i, carriage in ipairs(train.carriages) do
      local new_pos = {
         x = carriage.position.x - source_station.position.x + target_station.position.x,
         y = carriage.position.y - source_station.position.y + target_station.position.y
      }

      local box = carriage.prototype.collision_box
      local area = {
         { new_pos.x + box.left_top.x,     new_pos.y + box.left_top.y },
         { new_pos.x + box.right_bottom.x, new_pos.y + box.right_bottom.y }
      }
      if target_station.direction == defines.direction.east or target_station.direction == defines.direction.west then
         -- Swap width and height for east/west facing stations
         box = {
            left_top = {x = box.left_top.y, y = box.left_top.x},
            right_bottom = {x = box.right_bottom.y, y = box.right_bottom.x}
         }
      end

      -- Debug: visualize the checked area
      --[[
      rendering.draw_rectangle{
         color = {r=1, g=0, b=0, a=0.25},
         filled = true,
         left_top = area[1],
         right_bottom = area[2],
         surface = surface,
         time_to_live = 120
      }
      ]]

      local blockers = surface.find_entities_filtered{
         area = area,
         collision_mask = { "object", "player", "train" }
      }

      for _, ent in pairs(blockers) do
         if ent.valid then
            -- Explicit allow-list (important)
            if ent.name == "entity-ghost"
               or ent.type == "train-stop"
               or ent.type == "straight-rail"
               or ent.type == "curved-rail"
            then
               goto continue
            end

            -- debug: blocker found
            -- Could be removed if not wanted
            --game.print({
            --   "",
            --   "[Train warp blocked] Carriage #", i,
            --   " Entity=", ent.name,
            --   " Type=", ent.type,
            --   " Pos=(", math.floor(ent.position.x), ",", math.floor(ent.position.y), ")"
            --}, {color={1,0.2,0.2}})

            return false
         end

         ::continue::
      end
   end

   return true
end

function train_code.warp_array(array, destination, target_station, source_station)
   for i,v in ipairs(array) do
      -- Subtract current station position from the train position
      -- Add target station position to get new position
      local new_pos = {x = v.position.x - source_station.position.x + target_station.position.x, y = v.position.y - source_station.position.y + target_station.position.y}
      local new_entity = v.clone({position=new_pos, surface=destination})
      if new_entity then
         new_entity.copy_settings(v)
         v.destroy()
      else
         game.print({"warptorio.train-warp-error"},{color={1,0,0}})
      end
   end
end

function train_code.get_free_warp_station(destination, station_name, direction)
   local stations = game.train_manager.get_train_stops(
      {
         station_name=station_name,
         surface=destination,
         is_full=false,
         is_disabled=false,
         is_connected_to_rail=true
      }
   )
   local valid_dir = true

   for _, station in ipairs(stations) do
      if not station.get_stopped_train() then
         if station.direction == direction then
            return station
         end
         valid_dir = false
      end
   end
   if not valid_dir then
      game.print({"warptorio.train-warp-direction-error"}, {color={1,0,0}})
      return nil
   end
   return nil
end

function train_code.train_has_passengers(train)
   if #train.passengers > 0 then
      game.print({"warptorio.train-warp-passenger-error"}, {color={1,0,0}})
      return true
   end
   return false
end

function train_code.is_station_out_of_bounds(station)
    local surface_name = station.surface.name
    local pos = station.position
    local radius
    local center = {x=0, y=0}

    -- Factory is always valid
    if surface_name == "factory" then return false end

    center = get_surface_offset(surface_name)
    if storage.warptorio and storage.warptorio.ground_size then
      --game.print("Ground size: " .. storage.warptorio.ground_size)
      radius = storage.warptorio.ground_size / 2
    else
      radius = 100 -- Fallback for ground_size
    end
    --game.print("Range Check - Center: {x=" .. center.x .. ", y=" .. center.y .. "}, Radius: " .. radius .. ", Station Pos: {x=" .. pos.x .. ", y=" .. pos.y .. "}")
    --game.print("Range Check - Delta: {dx=" .. (pos.x - center.x) .. ", dy=" .. (pos.y - center.y) .. "}")
    if math.abs(pos.x - center.x) > radius or math.abs(pos.y - center.y) > radius then
      game.print({"warptorio.train-warp-station-range-error"}, {color={1,0,0}})
      return true
    end
    return false
end

function train_code.warp_trains(train, station_name)
   if not game.forces["player"].technologies["warp-train"].researched then return end
   if not train then return end
   
   -- We could remove the WarpStation filter to warp all trains, but for now we keep it like this.
   -- Because we don't keep the train schedule after warping you need the other stop on the line to be named the same.
   local stations = game.train_manager.get_train_stops({station_name=station_name})
   for i,v in ipairs(stations) do
      local tmp_train = v.get_stopped_train()
      if not tmp_train then goto next_train_in_loop end
      if not tmp_train.id == train.id then goto next_train_in_loop end

      local at_station = train.state == defines.train_state.wait_station
      if not at_station then goto next_train_in_loop end
      
      local destination = v.surface.name == "factory" and storage.warptorio.warp_zone or "factory"
      local target_station = train_code.get_free_warp_station(destination, v.backer_name, v.direction)
      if not target_station then
         game.print({"warptorio.train-warp-no-destination", station_name}, {color={1,0,0}})
         goto next_train_in_loop
      end
      
      -- Warp is possible, now check for conditions that would abort it and show an error.
      if train_code.is_station_out_of_bounds(v) then goto next_train_in_loop end
      if train_code.is_station_out_of_bounds(target_station) then goto next_train_in_loop end
      if train_code.train_has_passengers(train) then goto next_train_in_loop end

      -- Check that target area is free.
      local dest_surface = game.surfaces[destination]
      if not train_code.is_train_footprint_clear(train, dest_surface, v, target_station) then
         game.print({"warptorio.train-warp-track-blocked"}, {color={1,0,0}})
         goto next_train_in_loop
      end

      local manual = train.manual_mode
      -- All checks passed, do the warp
      game.print({"warptorio.train-warp",destination})
      local schedule = train.schedule
      train_code.warp_array(train.carriages,destination,target_station,v)
      --Now we have to get destination train and switch it to automatic
      local t2 = game.train_manager.get_trains({surface=destination})
      for a,b in ipairs(t2) do
         --schedule.current = schedule.current + 1
         --if #schedule.records < schedule.current then
         --   schedule.current = 1
         --end
         if not b.schedule then
            b.schedule = schedule
         end
         b.manual_mode = manual
      end
      
      ::next_train_in_loop::
   end
end

return train_code
