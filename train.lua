local warp_settings = require("internal_settings")

local train_code = {}
-- Trains parked at a warp station waiting on a transient blocker (busy teleporting,
-- track occupied, no free destination stop). Keyed by train.id.
train_code.pending_warps = train_code.pending_warps or {}

-- Only nag the player if a train has been stuck for a while 
local RETRY_WARN_AFTER = 60 * 30

local function get_surface_offset(surface_name)
   local ZERO_OFFSET = { x = 0, y = 0 }
   if storage.warptorio and storage.warptorio.surface_positions then
      return storage.warptorio.surface_positions[surface_name] or ZERO_OFFSET
   end
   return ZERO_OFFSET
end

function train_code.get_ground_surface()
   return storage.warptorio.teleporting and "warp-space-transition" or storage.warptorio.warp_zone
end

-- Resolves which surface a train should warp to, given the surface+station it's
-- currently sitting at. Single source of truth shared by the event handler and
-- the retry poller, so they can never disagree about routing.
function train_code.resolve_train_destination(surface_name, station_name)
   local ground_surface = train_code.get_ground_surface()

   local train_decision = {
      { surface = "factory",      station = warp_settings.train.ground_station,  destination = ground_surface },
      { surface = ground_surface, station = warp_settings.train.factory_station, destination = "factory" },
   }

   if game.forces["player"].technologies[warp_settings.train.garden_research].researched then
      table.insert(train_decision, { surface = "garden",        station = warp_settings.train.ground_station,  destination = ground_surface })
      table.insert(train_decision, { surface = "garden",        station = warp_settings.train.factory_station, destination = "factory" })
      table.insert(train_decision, { surface = ground_surface,  station = warp_settings.train.garden_station,  destination = "garden" })
      table.insert(train_decision, { surface = "factory",       station = warp_settings.train.garden_station,  destination = "garden" })
   end

   for _, d in ipairs(train_decision) do
      if d.surface == surface_name and d.station == station_name then
         return d.destination
      end
   end
   return nil
end

function train_code.queue_retry(train, station_name, reason_msg)
   local pending = train_code.pending_warps[train.id]
   if not pending then
      train_code.pending_warps[train.id] = { station_name = station_name, queued_at = game.tick, warned = false }
      --game.print({"warptorio.train-queued-retry", train.id, station_name})
      return
   end
   if not pending.warned and game.tick - pending.queued_at >= RETRY_WARN_AFTER then
      game.print(reason_msg, {color={1,0.6,0}})
      pending.warned = true
   end
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
      if target_station.direction == defines.direction.east or target_station.direction == defines.direction.west then
         -- Swap width and height for east/west facing stations
         box = {
            left_top = { x = box.left_top.y, y = box.left_top.x },
            right_bottom = { x = box.right_bottom.y, y = box.right_bottom.x }
         }
      end
      local area = {
         { new_pos.x + box.left_top.x,     new_pos.y + box.left_top.y },
         { new_pos.x + box.right_bottom.x, new_pos.y + box.right_bottom.y }
      }

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

      local blockers = surface.find_entities_filtered {
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
               goto skip
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

         ::skip::
      end
   end

   return true
end

function train_code.warp_array(array, destination, target_station, source_station)
   local new_train = nil
   for i, v in ipairs(array) do
      -- Subtract current station position from the train position
      -- Add target station position to get new position
      local new_pos = {
         x = v.position.x - source_station.position.x + target_station.position.x,
         y = v.position.y -
             source_station.position.y + target_station.position.y
      }
      local new_entity = v.clone({ position = new_pos, surface = destination })
      if new_entity then
         new_entity.train.manual_mode = false
         new_entity.copy_settings(v)
         new_entity.train.manual_mode = false
         v.destroy()
         new_train = new_entity.train
      else
         game.print({ "warptorio.train-warp-error" }, { color = { 1, 0, 0 } })
      end
   end
   return new_train
end

function train_code.get_free_warp_station(destination, station_name, direction)
   local stations = game.train_manager.get_train_stops(
      {
         station_name = station_name,
         surface = destination,
         is_full = false,
         is_disabled = false,
         is_connected_to_rail = true
      }
   )
   local valid_dir = true
   local station_no_train = nil

   for _, station in ipairs(stations) do
      if not station.get_stopped_train() then
         station_no_train = station
         if station.direction == direction then
            return station
         end
      end
   end
   if station_no_train then
      return station_no_train
   end
   if not valid_dir then
      game.print({ "warptorio.train-warp-direction-error" }, { color = { 1, 0, 0 } })
   end
   return nil
end

function train_code.train_has_passengers(train)
   if #train.passengers > 0 then
      --game.print({"warptorio.train-has-passengers", train.id, #train.passengers})
      game.print({ "warptorio.train-warp-passenger-error" }, { color = { 1, 0, 0 } })
      return true
   end
   return false
end

function train_code.is_station_out_of_bounds(station)
   local surface_name = station.surface.name
   local pos = station.position
   local radius
   local center = { x = 0, y = 0 }

   -- Factory and garden are fixed internal floors at the origin, always valid
   if surface_name == "factory" or surface_name == "garden" then return false end

   center = get_surface_offset(surface_name)
   if storage.warptorio and storage.warptorio.ground_size then
      --game.print("Ground size: " .. storage.warptorio.ground_size)
      radius = storage.warptorio.ground_size / 2
    else
       game.print("Warning: ground_size missing, using fallback", { color = { 1, 0.6, 0 } })
       radius = 100
    end
   --game.print("Range Check - Center: {x=" .. center.x .. ", y=" .. center.y .. "}, Radius: " .. radius .. ", Station Pos: {x=" .. pos.x .. ", y=" .. pos.y .. "}")
   --game.print("Range Check - Delta: {dx=" .. (pos.x - center.x) .. ", dy=" .. (pos.y - center.y) .. "}")
   if math.abs(pos.x - center.x) > radius or math.abs(pos.y - center.y) > radius then
      game.print({ "warptorio.train-warp-station-range-error" }, { color = { 1, 0, 0 } })
      return true
   end
   return false
end

-- destination is the surface name the train should warp to. The caller decides it based on
-- which warp station the train stopped at (ground floor, garden floor, or factory).
function train_code.warp_trains(train, station_name, destination)
   if not game.forces["player"].technologies["warp-train"].researched then return end
   if not train or not train.valid or not train.id then return end

   local ground_surface = storage.warptorio.teleporting and "warp-space-transition" or storage.warptorio.warp_zone
   if storage.warptorio.teleporting and destination == ground_surface then
      train_code.queue_retry(train, station_name, {"warptorio.train-warp-waiting-busy"})
      return
   end

   local stations = game.train_manager.get_train_stops({station_name=station_name})
   for _, v in ipairs(stations) do
      local tmp_train = v.get_stopped_train()
      --game.print({"warptorio.debug.train-id", train.id, "station", v.backer_name})
      local valid = tmp_train and tmp_train.valid and tmp_train.id == train.id and train.state == defines.train_state.wait_station

      if valid then
         local target_station = train_code.get_free_warp_station(destination, v.backer_name, v.direction)
         if target_station
            and not train_code.is_station_out_of_bounds(v)
            and not train_code.is_station_out_of_bounds(target_station)
            and not train_code.train_has_passengers(train)
            and train_code.is_train_footprint_clear(train, game.surfaces[destination], v, target_station)
         then
            train_code.pending_warps[train.id] = nil
            --game.print({"warptorio.train-warping", train.id, destination, v.backer_name, target_station.backer_name})
            train_code.warp_single_train(train, destination, target_station, v)
            return
         else
            if not target_station then
               --game.print({"warptorio.train-warp-waiting-no-destination", station_name})
               train_code.queue_retry(train, station_name, {"warptorio.train-warp-waiting-no-destination", station_name})
            else
               --game.print({"warptorio.train-warp-waiting-blocked", station_name})
               train_code.queue_retry(train, station_name, {"warptorio.train-warp-waiting-blocked"})
            end
         end
      end
   end
end

   -- Called periodically (see control.lua on_tick) to re-attempt warps for trains that
-- are still sitting at a warp station waiting on a transient blocker.
function train_code.retry_pending_warps()
   if not next(train_code.pending_warps) then return end
   for train_id, pending in pairs(train_code.pending_warps) do
      local station_name = pending.station_name
      local stations = game.train_manager.get_train_stops({station_name=station_name})
      local found = false
      for _, v in ipairs(stations) do
         local t = v.get_stopped_train()
         if t and t.valid and t.id == train_id and t.state == defines.train_state.wait_station then
            found = true
            local destination = train_code.resolve_train_destination(v.surface.name, station_name)
            if destination then
               train_code.warp_trains(t, station_name, destination)
            end
            break
         end
      end
      if not found then
         -- Train moved off, was destroyed, or is no longer waiting there — stop tracking it.
         train_code.pending_warps[train_id] = nil
      end
   end
end

function train_code.warp_single_train(train, destination, target_station, source_station)
   --game.print({"warptorio.train-warping", train.id, destination})

   local old_speed = train.speed
   local old_state = train.state
   local schedule = train.get_schedule()
   local schedule_records = schedule.get_records()
   local schedule_index = train.schedule.current
   local new_train = train_code.warp_array(train.carriages, destination, target_station, source_station)
   if not new_train then
      --game.print({ "warptorio.train-warp-error" }, { color = { 1, 0, 0 } })
      game.print({"warptorio.train-warp-error", train.id, destination})
      return
   end

   --game.print({"warptorio.train-warped", train.id, destination})

   -- Restore schedule and switch back to automatic.
   local new_train_schedule = new_train.get_schedule()
   new_train_schedule.set_records(schedule_records)
   new_train.manual_mode = false
   new_train.go_to_station(schedule_index)

   if new_train.valid and old_speed and old_speed ~= 0 then
      local same_facing = source_station.direction == target_station.direction
      new_train.speed = same_facing and old_speed or -old_speed
   end
end

return train_code
