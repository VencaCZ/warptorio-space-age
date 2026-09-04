local warp_settings = require("internal_settings")

local train_code = {}

-- Both of the tables below are cross-tick state that drives real game state: pending
-- warps decide when a train is teleported, and warp effects create rendering objects
-- that live in the save. Anything like that has to sit in storage — a module-level
-- table is rebuilt empty when a client loads the save, so a player joining mid-game
-- would start running different work from the host.

-- Trains parked at a warp station waiting on a transient blocker (busy teleporting,
-- track occupied, no free destination stop). Keyed by train.id.
local function pending_warps()
   storage.warptorio = storage.warptorio or {}
   storage.warptorio.pending_warps = storage.warptorio.pending_warps or {}
   return storage.warptorio.pending_warps
end

local function warp_effects()
   storage.warptorio = storage.warptorio or {}
   storage.warptorio.warp_effects = storage.warptorio.warp_effects or {}
   return storage.warptorio.warp_effects
end

-- Pre-freeze speeds of trains frozen for the warp, keyed by train.id.
local function frozen_train_speeds()
   storage.warptorio = storage.warptorio or {}
   storage.warptorio.frozen_train_speeds = storage.warptorio.frozen_train_speeds or {}
   return storage.warptorio.frozen_train_speeds
end

-- no need to move this to settings for now, but I will fix it later
-- PS: this should be never null as its in game setting
local trail_pallette = warp_settings.train.trail_color_setting and
   warp_settings.train.trail_palletes[warp_settings.train.trail_color_setting] or
   warp_settings.train.trail_palletes.cyan

-- Factorio 2.x uses 16 directions: north=0, east=4, south=8, west=12. +y is south.
local function direction_vector(direction)
   local angle = direction * math.pi / 8
   return { x = math.sin(angle), y = -math.cos(angle) }
end

-- A train stop's position sits beside the track it parks trains on (left of the
-- travel direction), so effects are shifted there to land on the rails instead
-- of on the stop tile.
local function warp_effect_position(position, direction)
   local dir = direction_vector(direction)
   return {
      x = position.x + dir.y * warp_settings.train.warp_effect_tile_offset,
      y = position.y - dir.x * warp_settings.train.warp_effect_tile_offset,
   }
end

local function get_surface_offset(surface_name)
   local zero_offset = { x = 0, y = 0 }
   if storage.warptorio and storage.warptorio.surface_positions then
      return storage.warptorio.surface_positions[surface_name] or zero_offset
   end
   return zero_offset
end

-- Queues a bright warp flash (expanding shockwave + light pulse) at a position.
function train_code.create_warp_flash(surface, position, direction)
   if not (surface and surface.valid and position) then return end

   local effects = warp_effects()
   effects[#effects + 1] = {
      kind = "flash",
      surface = surface,
      position = warp_effect_position(position, direction),
      tick_start = game.tick,
   }
end

-- Queues a flaming skid-mark trail behind a station, opposite its facing.
-- length is the trail extent behind the station (towards the train's tail),
-- front is the extra extent ahead of the station (towards the locomotive nose).
-- reverse makes the flames brightest at the tail end instead of the nose.
function train_code.create_warp_trail(surface, position, direction, length, front, reverse)
   if not (surface and surface.valid and position) then return end

   local effects = warp_effects()
   effects[#effects + 1] = {
      kind = "trail",
      surface = surface,
      position = warp_effect_position(position, direction),
      direction = direction,
      length = length,
      front = front or 0,
      reverse = reverse,
      tick_start = game.tick,
   }
end

-- Advances and draws all active warp effects. Called every tick from control.lua.
function train_code.on_tick(tick)
   local effects = warp_effects()
   if not next(effects) then return end

   local i = 1
   while i <= #effects do
      local f = effects[i]
      local age = tick - f.tick_start

      if not (f.surface and f.surface.valid) then
         table.remove(effects, i)
      elseif f.kind == "flash" then
         if age > warp_settings.train.warp_flash_duration then
            table.remove(effects, i)
         else
            local t = age / warp_settings.train.warp_flash_duration  -- 0..1
            local fade = 1 - t

            -- Light shifts from white to the selected trail colour as it expands
            local glow = trail_pallette.glow
            local cr = 1 - (1 - glow[1]) * t
            local cg = 1 - (1 - glow[2]) * t
            local cb = 1 - (1 - glow[3]) * t

            -- Light pulse that grows and fades with the flash
            rendering.draw_light{
               sprite = "utility/light_medium",
               target = f.position,
               surface = f.surface,
               color = { r = cr, g = cg, b = cb, a = fade },
               intensity = fade,
               scale = 2 + t * 4,
               time_to_live = 3,
            }

            i = i + 1
         end
      else -- trail
         if age > warp_settings.train.trail_ticks then
            table.remove(effects, i)
         else
            -- quick ignition at the start, then linear burnout
            local fade = math.min(1, age / 3) * (1 - age / warp_settings.train.trail_ticks)
            local dir = direction_vector(f.direction)
            local total = f.length + f.front

            local d = -f.front
            while d <= f.length do
               -- flames are brightest and biggest at the train's nose (front),
               -- shrinking towards the far end of the trail; reverse flips it
               -- so the tail end burns brightest instead
               local tpos = (d + f.front) / total
               local spread = f.reverse and tpos or (1 - tpos)
               local flicker = 0.75 + 0.25 * math.sin(age * 1.3 + d * 1.7)
               local pos = {
                  x = f.position.x - dir.x * d,
                  y = f.position.y - dir.y * d,
               }

               local flame = trail_pallette.flame
               local core = trail_pallette.core

               rendering.draw_circle{
                  color = { r = flame[1], g = flame[2], b = flame[3], a = fade * 0.75 * flicker },
                  radius = 0.55 * spread * flicker + 0.05,
                  filled = true,
                  target = pos,
                  surface = f.surface,
                  time_to_live = 2,
                  draw_on_ground = true,
               }
               rendering.draw_circle{
                  color = { r = core[1], g = core[2], b = core[3], a = fade * flicker },
                  radius = 0.3 * spread * flicker,
                  filled = true,
                  target = pos,
                  surface = f.surface,
                  time_to_live = 2,
                  draw_on_ground = true,
               }

               d = d + warp_settings.train.trail_step
            end

            -- Plasma glow over the whole trail
            rendering.draw_light{
               sprite = "utility/light_medium",
               target = {
                  x = f.position.x - dir.x * (f.length - f.front) / 2,
                  y = f.position.y - dir.y * (f.length - f.front) / 2,
               },
               surface = f.surface,
               color = { r = trail_pallette.glow[1], g = trail_pallette.glow[2], b = trail_pallette.glow[3], a = fade * 0.8 },
               intensity = fade * 0.8,
               scale = 3 + f.length / 4,
               time_to_live = 2,
            }

            i = i + 1
         end
      end
   end
end

function train_code.get_ground_surface()
   return storage.warptorio.teleporting and "warp-space-transition" or storage.warptorio.warp_zone
end

-- Resolves which surface a train should warp to, given the surface+station it's
-- currently sitting at. Single source of truth shared by the event handler and
-- the retry poller, so they can never disagree about routing.
function train_code.resolve_train_destination(surface_name, station_name)
   -- While teleporting the ground floor is being moved from the old planet surface
   -- to warp-space-transition. Trains may still be sitting on either one, so treat
   -- both as "ground" during the transition.
   local ground_surfaces = { train_code.get_ground_surface() }
   if storage.warptorio.teleporting and storage.warptorio.warp_zone ~= ground_surfaces[1] then
      ground_surfaces[#ground_surfaces + 1] = storage.warptorio.warp_zone
   end

   local train_decision = {
      { surface = "factory",      station = warp_settings.train.ground_station,  destination = ground_surfaces[1] },
   }
   for _, gs in ipairs(ground_surfaces) do
      train_decision[#train_decision + 1] = { surface = gs, station = warp_settings.train.factory_station, destination = "factory" }
   end

   if game.forces["player"].technologies[warp_settings.train.garden_research].researched then
      train_decision[#train_decision + 1] = { surface = "garden", station = warp_settings.train.ground_station, destination = ground_surfaces[1] }
      train_decision[#train_decision + 1] = { surface = "garden", station = warp_settings.train.factory_station, destination = "factory" }
      for _, gs in ipairs(ground_surfaces) do
         train_decision[#train_decision + 1] = { surface = gs, station = warp_settings.train.garden_station, destination = "garden" }
      end
      train_decision[#train_decision + 1] = { surface = "factory", station = warp_settings.train.garden_station, destination = "garden" }
   end

   for _, d in ipairs(train_decision) do
      if d.surface == surface_name and d.station == station_name then
         return d.destination
      end
   end
   return nil
end

function train_code.queue_retry(train, station_name, reason_msg)
   local queue = pending_warps()
   local pending = queue[train.id]
   if not pending then
      queue[train.id] = { station_name = station_name, queued_at = game.tick, warned = false }
      return
   end
   if not pending.warned and game.tick - pending.queued_at >= warp_settings.train.retry_warn_after then
      if not warp_settings.train.block_info_messages then
         game.print(reason_msg, {color={1,0.6,0}})
      end
      pending.warned = true
   end
end

local function carriage_warp_position(carriage, source_station, target_station)
   return {
      x = carriage.position.x - source_station.position.x + target_station.position.x,
      y = carriage.position.y - source_station.position.y + target_station.position.y
   }
end

local function is_rail_at(surface, position)
   local rails = surface.find_entities_filtered {
      position = position,
      radius = 1.5,
      type = { "straight-rail", "curved-rail" },
      limit = 1,
   }
   return #rails > 0
end

-- Returns true if there is rail under every carriage position on the destination
-- surface, i.e. the track behind the target station is long enough for the train.
-- destination_surface MUST be a LuaSurface
function train_code.is_train_track_long_enough(train, destination_surface, source_station, target_station)
   for _, carriage in ipairs(train.carriages) do
      local new_pos = carriage_warp_position(carriage, source_station, target_station)
      if not is_rail_at(destination_surface, new_pos) then
         return false
      end
   end
   return true
end

-- Returns true if the full train footprint is clear on the destination surface
-- destination_surface MUST be a LuaSurface
function train_code.is_train_footprint_clear(train, destination_surface, source_station, target_station)
   local surface = destination_surface

   for _, carriage in ipairs(train.carriages) do
      local new_pos = carriage_warp_position(carriage, source_station, target_station)

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

      local blockers = surface.find_entities_filtered {
         area = area,
         collision_mask = { "object", "player", "train" }
      }

      for _, ent in pairs(blockers) do
         if ent.valid then
            -- Allow-list
            if ent.name == "entity-ghost"
                or ent.type == "train-stop"
                or ent.type == "straight-rail"
                or ent.type == "curved-rail"
            then
               goto skip
            end

            return false
         end

         ::skip::
      end
   end

   return true
end

function train_code.warp_array(array, destination, target_station, source_station)
   -- Clone all carriages first; if any clone fails, roll back the clones so the
   -- source train stays intact and the warp can be retried later.
   local clones = {}
   for _, v in ipairs(array) do
      -- Subtract current station position from the train position
      -- Add target station position to get new position
      local new_pos = {
         x = v.position.x - source_station.position.x + target_station.position.x,
         y = v.position.y -
             source_station.position.y + target_station.position.y
      }

      local new_entity = v.clone({ position = new_pos, surface = destination })
      if not new_entity then
         for _, c in ipairs(clones) do
            if c.valid then c.destroy() end
         end
         return nil
      end
      clones[#clones + 1] = new_entity
   end

   local new_train = nil
   for i, new_entity in ipairs(clones) do
      new_entity.train.manual_mode = false
      new_entity.copy_settings(array[i])
      new_entity.train.manual_mode = false
      new_train = new_entity.train
      array[i].destroy()
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
    return nil
end

function train_code.train_has_passengers(train)
   return #train.passengers > 0
end

-- Kick any player who is remote-controlling this train (i.e. "Drive remotely"
-- from the train GUI / remote view). A remote driver appears in train.passengers
-- but has controller_type == remote; forcing exit_remote_view() yanks them out so
-- the warp is not blocked. Physically-riding players (controller_type == character)
-- are deliberately left alone so they keep blocking the warp.
function train_code.kick_remote_drivers(train)
   local kicked = false
   for _, p in ipairs(train.passengers) do
      if p.connected and p.controller_type == defines.controllers.remote then
         if p.exit_remote_view() then
            p.print({"warptorio.train-warp-kicked-remote"})
            kicked = true
         end
      end
   end
   return kicked
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
      radius = storage.warptorio.ground_size / 2
   else
      game.print("Warning: ground_size missing, using fallback", { color = { 1, 0.6, 0 } })
      radius = 100
   end
    if math.abs(pos.x - center.x) > radius or math.abs(pos.y - center.y) > radius then
       return true
    end
    return false
end

-- destination is the surface name the train should warp to. The caller decides it based on
-- which warp station the train stopped at (ground floor, garden floor, or factory).
function train_code.warp_trains(train, station_name, destination)
   if not game.forces["player"].technologies["warp-train"].researched then return end
   if not train or not train.valid or not train.id then return end

   local stations = game.train_manager.get_train_stops({station_name=station_name})
   for _, v in ipairs(stations) do
      local tmp_train = v.get_stopped_train()
      local valid = tmp_train and tmp_train.valid and tmp_train.id == train.id and train.state == defines.train_state.wait_station

      if valid then
         local target_station = train_code.get_free_warp_station(destination, v.backer_name, v.direction)
         if not target_station then
            train_code.queue_retry(train, station_name, {"warptorio.train-warp-waiting-no-destination", station_name})
         else
            local destination_surface = game.surfaces[destination]
            local track_ok = train_code.is_train_track_long_enough(train, destination_surface, v, target_station)
            local out_of_bounds = train_code.is_station_out_of_bounds(v) or train_code.is_station_out_of_bounds(target_station)
            -- Kick anyone remote-driving this train so it is not stuck on the
            -- passenger check; re-read passengers afterwards.
            train_code.kick_remote_drivers(train)
            local has_passengers = train_code.train_has_passengers(train)

            if not out_of_bounds
               and not has_passengers
               and track_ok
               and train_code.is_train_footprint_clear(train, destination_surface, v, target_station)
            then
               pending_warps()[train.id] = nil
               train_code.warp_single_train(train, destination, target_station, v)
               return
            elseif out_of_bounds then
               train_code.queue_retry(
                  train, station_name, {"warptorio.train-warp-station-range-error", station_name})
            elseif has_passengers then
               train_code.queue_retry(
                  train, station_name, {"warptorio.train-warp-passenger-error", station_name})
            elseif not track_ok then
               train_code.queue_retry(
                  train, station_name, {"warptorio.train-warp-track-too-short", station_name})
            else
               train_code.queue_retry(
                  train, station_name, {"warptorio.train-warp-waiting-blocked", station_name})
            end
         end
      end
   end
end

-- Called periodically (control.lua on_tick) to re-attempt blocked warps and catch
-- parked trains that never got a warp event (e.g. clones created mid-transition).
function train_code.retry_pending_warps()
   local queue = pending_warps()
   if next(queue) then
      for train_id, pending in pairs(queue) do
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
            queue[train_id] = nil
         end
      end
   end
   train_code.scan_for_parked_warps()
end

-- Warps trains parked at warp stations that never fired on_train_changed_state
-- (cloned mid-transition trains are created already parked, so no event fires).
function train_code.scan_for_parked_warps()
   local surfaces = { "factory", "garden", storage.warptorio.warp_zone }
   if game.surfaces["warp-space-transition"] and game.surfaces["warp-space-transition"].valid then
      surfaces[#surfaces + 1] = "warp-space-transition"
   end

   for _, surface_name in ipairs(surfaces) do
      if game.surfaces[surface_name] and game.surfaces[surface_name].valid then
         -- Filter by warp station names so we only ever touch warp stops, not
         -- every train stop the player has built on the surface.
         local warp_stops = game.train_manager.get_train_stops(
            {
               station_name = {
                  warp_settings.train.ground_station,
                  warp_settings.train.factory_station,
                  warp_settings.train.garden_station,
               },
               surface = surface_name })
         for _, stop in ipairs(warp_stops) do
            local t = stop.get_stopped_train()
            if t and t.valid and t.id and t.state == defines.train_state.wait_station
               and not pending_warps()[t.id] then
               local destination = train_code.resolve_train_destination(
                  surface_name, stop.backer_name)
               if destination then
                  train_code.warp_trains(t, stop.backer_name, destination)
               end
            end
         end
      end
   end
end

function train_code.warp_single_train(train, destination, target_station, source_station)
   local old_speed = train.speed
   local schedule = train.get_schedule()
   local schedule_records = schedule.get_records()
   local schedule_index = train.schedule.current

   local train_length = #train.carriages * warp_settings.train.train_element_lenght
   -- Departure: trail covers where the train stood, plus the locomotive nose
   -- sticking out ahead of the station.
   train_code.create_warp_trail(
      source_station.surface, source_station.position,
      source_station.direction, train_length, warp_settings.train.trail_front_pad)
   train_code.create_warp_flash(
      source_station.surface, source_station.position, source_station.direction)

   local new_train = train_code.warp_array(
      train.carriages, destination, target_station, source_station)
   if not new_train then
      game.print({"warptorio.train-warp-error"}, { color = { 1, 0, 0 } })
      -- Source train is still parked and intact (clones were rolled back), so
      -- queue a retry instead of giving up.
      train_code.queue_retry(train, source_station.backer_name, {"warptorio.train-warp-error"})
      return
   end

   local destination_surface = game.surfaces[destination]
   -- Arrival: trail extends a bit past the back of the landed train.
   train_code.create_warp_trail(
      destination_surface, target_station.position,
      target_station.direction,
      train_length + warp_settings.train.trail_back_pad, 0, true)
   train_code.create_warp_flash(
      destination_surface, target_station.position, target_station.direction)

   -- Automatic with an empty schedule would bounce back to manual and
   -- go_to_station would index past the stale index; leave manual in that case.
   local new_train_schedule = new_train.get_schedule()
   new_train_schedule.set_records(schedule_records)
   if #schedule_records > 0 then
      new_train.manual_mode = false
      new_train.go_to_station(schedule_index)
   end

   if new_train.valid and old_speed and old_speed ~= 0 then
      local same_facing = source_station.direction == target_station.direction
      new_train.speed = same_facing and old_speed or -old_speed
   end
end

-- Zeroes every train on floors feeding WarpGround (plus the ground floor being
-- cloned when extra_surface is given) so the clone is stationary. Pre-freeze
-- speeds are stashed for resume_ground_bound_trains.
function train_code.freeze_ground_bound_trains(extra_surface)
   local speeds = frozen_train_speeds()
   for k in pairs(speeds) do speeds[k] = nil end
   local floors = {}
   for _, stop in ipairs(game.train_manager.get_train_stops({ station_name = warp_settings.train.ground_station })) do
      floors[stop.surface.name] = true
   end
   if extra_surface then
      floors[extra_surface] = true
   end

   for surface_name in pairs(floors) do
      local surface = game.surfaces[surface_name]
      if surface and surface.valid then
         for _, carriage in ipairs(surface.find_entities_filtered{ type = warp_settings.train.stock }) do
            local train = carriage.train
            if train and train.valid then
               speeds[train.id] = train.speed
               train.speed = 0
            end
         end
      end
   end
end

-- After the warp: push any train left in manual back to automatic, restore
-- frozen speeds, clear stale entries.
function train_code.resume_ground_bound_trains()
   local speeds = frozen_train_speeds()
   local floors = {}
   for _, stop in ipairs(game.train_manager.get_train_stops({ station_name = warp_settings.train.ground_station })) do
      floors[stop.surface.name] = true
   end

   for surface_name in pairs(floors) do
      local surface = game.surfaces[surface_name]
      if surface and surface.valid then
         for _, carriage in ipairs(surface.find_entities_filtered{ type = warp_settings.train.stock }) do
            local train = carriage.train
            if train and train.valid then
               -- Hands off trains a player is actually driving: manual + occupied
               -- is deliberate, everything else gets forced back to automatic.
               if not (train.manual_mode and #train.passengers > 0) then
                  train.manual_mode = false
               end
               local frozen = speeds[train.id]
               if frozen and frozen ~= 0 and train.speed == 0
                  and train.state ~= defines.train_state.wait_station
                  and #train.passengers == 0 then
                  train.speed = frozen
               end
               speeds[train.id] = nil
            end
         end
      end
   end
   for k in pairs(speeds) do speeds[k] = nil end
   return true
end

-- Snapshot each train's mode/speed/state/schedule before the clone.
-- Positions are relative to the given surface offset so source/dest can differ.
function train_code.capture_clone_states(surface, offset)
   local captured = {}
   for _, carriage in ipairs(surface.find_entities_filtered{ type = warp_settings.train.stock }) do
      local train = carriage.train
      if train and train.valid then
         local schedule = train.get_schedule()
         captured[#captured + 1] = {
            x = carriage.position.x - offset.x,
            y = carriage.position.y - offset.y,
            mode = train.manual_mode,
            speed = train.speed,
            state = train.state,
            schedule_index = train.schedule and train.schedule.current or 0,
            records = schedule and schedule.get_records() or nil,
         }
      end
   end
   return captured
end

-- Restores mode, schedule and journey state on cloned trains: clones don't
-- inherit the schedule, and an automatic train with an empty schedule is forced
-- back to manual by the engine. 1.0 tile tolerance, trying every carriage.
function train_code.restore_clone_states(surface, offset, captured)
   local used = {}
   local seen = {}
   for _, carriage in ipairs(surface.find_entities_filtered{ type = warp_settings.train.stock }) do
      local train = carriage.train
      if train and train.valid and not seen[train.id] then
         seen[train.id] = true
         local match = nil
         for _, c in ipairs(train.carriages) do
            local rx = c.position.x - offset.x
            local ry = c.position.y - offset.y
            for j, cap in ipairs(captured) do
               if not used[j] and math.abs(cap.x - rx) < 1.0 and math.abs(cap.y - ry) < 1.0 then
                  match = cap
                  used[j] = true
                  break
               end
            end
            if match then break end
         end

         if match then
            if match.records and #match.records > 0 then
               train.get_schedule().set_records(match.records)
            end
            if match.mode ~= train.manual_mode then
               train.manual_mode = match.mode
            end
            -- A train that was driving when cloned stops dead on the clone; send it
            -- back on its way to the same schedule record at its previous speed.
            if not match.mode and match.schedule_index > 0
               and (match.speed ~= 0 or match.state == defines.train_state.on_the_path) then
               local target_index = match.records and #match.records > 0
                  and math.min(match.schedule_index, #match.records) or 0
               if target_index > 0 then
                  train.go_to_station(target_index)
               end
               if match.speed and match.speed ~= 0 then
                  train.speed = match.speed
               end
            end
         else
            log("[warptorio] no manual-mode match for cloned train " .. train.id)
         end
      end
   end
end

function train_code.on_train_changed_state(event)
   local train = event.train
   if not train or not train.valid then return end
   if train.state ~= defines.train_state.wait_station then return end
   if not train.station then return end
   if not train.id then game.print("ERROR") end

   local current = train.station.surface.name
   local station_name = train.station.backer_name
   local destination = train_code.resolve_train_destination(current, station_name)
   if destination then
      train_code.warp_trains(train, station_name, destination)
   end
end

return train_code
