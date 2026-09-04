local env
local module = {}

function module.init(env_table)
  env = env_table
  return module
end

local function find_child(parent, name)
  if not parent then return nil end
  if parent[name] and parent[name].name == name then return parent[name] end
  for _, child in pairs(parent.children) do
    local found = find_child(child, name)
    if found then return found end
  end
  return nil
end

local function subheader(parent, caption)
  local flow = parent.add{type="flow", direction="horizontal"}
  flow.style.vertical_align = "center"
  flow.style.bottom_margin = 6
  local lbl = flow.add{type="label", style="caption_label", caption=caption}
  lbl.style.font_color = {0.72, 0.8, 0.88}
  local rule = flow.add{type="line"}
  rule.style.horizontally_stretchable = true
  rule.style.left_margin = 8
  return flow
end

local function action_button(parent, name, caption, style)
  local b = parent.add{type="button", name=name, caption=caption, style=style or "button"}
  b.style.left_margin = 0
  b.style.right_margin = 0
  b.style.minimal_height = 24
  b.style.horizontally_stretchable = true
  return b
end

local function field_row(parent, name, label, caption)
  local row = parent.add{type="flow", direction="horizontal"}
  row.style.vertical_align = "center"
  local lbl = row.add{type="label", caption=label, style="caption_label"}
  lbl.style.minimal_width = 95
  local control
  if name == "warpcheat-count" then
    control = row.add{type="textfield", name=name, text=caption, numeric=true}
    control.style.width = 60
  else
    control = row.add{type="drop-down", name=name}
    control.style.width = 240
  end
  return row, control
end

local function warpcheat_gui(player)
  log("warpcheat_gui called")
  local container = player.gui.screen
  if container["warpcheat"] then
    container["warpcheat"].destroy()
    return
  end
  if not storage.warporio then storage.warporio = {} end

  local frame = container.add{type="frame", name="warpcheat", direction="vertical"}
  frame.style.margin = 4
  frame.style.minimal_width = 480
  frame.force_auto_center()

  local titlebar = frame.add{type="flow", direction="horizontal"}
  titlebar.style.horizontal_spacing = 8
  titlebar.drag_target = frame
  local title = titlebar.add{type="label", style="frame_title", caption="Warpcheat"}
  title.ignored_by_interaction = true
  local drag_handle = titlebar.add{type="empty-widget"}
  drag_handle.style.height = 24
  drag_handle.style.horizontally_stretchable = true
  drag_handle.style.right_margin = 4
  drag_handle.ignored_by_interaction = true
  titlebar.add{type="sprite-button", name="warpcheat-close",
    style="frame_action_button", sprite="utility/close", tooltip="Close"}

  local content = frame.add{type="frame", style="inside_shallow_frame_with_padding", direction="vertical"}

  local columns = content.add{type="flow", direction="horizontal"}
  columns.style.horizontal_spacing = 12

  -- LEFT column: transportation + location
  local left = columns.add{type="flow", direction="vertical"}
  left.style.vertical_spacing = 6

  subheader(left, "Navigation")
  local countrow = left.add{type="flow", direction="horizontal"}
  countrow.style.vertical_align = "center"
  countrow.style.horizontally_stretchable = true
  local lbl = countrow.add{type="label", style="caption_label", caption="Warp count"}
  lbl.style.minimal_width = 95
  local spacer = countrow.add{type="empty-widget"}
  spacer.style.horizontally_stretchable = true
  local tf = countrow.add{type="textfield", name="warpcheat-count", numeric=true,
    text=tostring(storage.warporio.index or 0)}
  tf.style.width = 60
  local apply = countrow.add{type="button", name="warpcheat-count-apply", caption="Set", style="green_button"}
  apply.style.minimal_width = 44
  apply.style.minimal_height = 24

  local planetrow, dd = field_row(left, "warpcheat-planet", "Next planet")
  for name, _ in pairs(game.planets) do
    dd.add_item(name)
  end
  local cur = storage.warptorio.planet_next
  if cur and game.planets[cur] then
    local idx = 0
    for k, name in ipairs(dd.items) do
      if name == cur then idx = k break end
    end
    if idx > 0 then dd.selected_index = idx end
  end

  action_button(left, "warpcheat-warp", "Warp now", "red_button")
  action_button(left, "warpcheat-warp-home", "Force home (Nauvis)", "green_button")

  subheader(left, "Location")
  local telrow = left.add{type="flow", direction="horizontal"}
  telrow.style.horizontal_spacing = 6
  action_button(telrow, "warpcheat-tp-factory", "Factory", "green_button")
  action_button(telrow, "warpcheat-tp-garden", "Garden", "tool_button_blue")
  action_button(telrow, "warpcheat-tp-home", "Home", "red_button")

  subheader(left, "Time")
  action_button(left, "warpcheat-reset-time", "Reset planet time")

  subheader(left, "Waves")
  local waveflow = left.add{type="flow", direction="horizontal"}
  waveflow.style.horizontal_spacing = 6
  action_button(waveflow, "warpcheat-wave-pause",
    storage.warptorio.wave_paused and "Resume waves" or "Pause waves")
  action_button(waveflow, "warpcheat-wave-add", "Wave +1")

  -- RIGHT column: platform + research + container
  local right = columns.add{type="flow", direction="vertical"}
  right.style.vertical_spacing = 6

  subheader(right, "Platform")
  action_button(right, "warpcheat-clean-platform", "Clean platform")
  action_button(right, "warpcheat-repair-platform", "Repair platform")
  action_button(right, "warpcheat-platform", "Spawn random platform")

  subheader(right, "Research")
  local techrow, techdd = field_row(right, "warpcheat-tech", "Technology")
  local techs = {}
  for name, _ in pairs(game.forces.player.technologies) do
    if string.match(name, "^warp") then table.insert(techs, name) end
  end
  table.sort(techs)
  for _, name in ipairs(techs) do
    techdd.add_item(name)
  end
  techdd.selected_index = 1
  local tech_actions = right.add{type="flow", direction="horizontal"}
  tech_actions.style.horizontal_spacing = 6
  action_button(tech_actions, "warpcheat-research", "Research", "green_button")
  action_button(tech_actions, "warpcheat-unresearch", "Unresearch", "red_button")

  subheader(right, "Container")
  action_button(right, "warpcheat-chest", "Give warpchest")

  local notice = content.add{type="label", style="semibold_label",
    caption="[color=1,0.35,0.3][font=default-bold]WARNING[/font][/color][color=0.9,0.72,0.45] - Debug only. Can corrupt your save, brick your run, or ruin the whole experience. Use at your own risk.[/color]"}
  notice.style.top_margin = 10
  notice.style.horizontal_align = "center"
end

function module.handle_click(event)
  local element = event.element
  if not element then return end
  local name = element.name
  if not name or not string.find(name, "^warpcheat") then return end
  if not event.player_index then return end
  local player = game.players[event.player_index]
  if not player.admin then return end

  if name == "warpcheat-close" then
    if player.gui.screen["warpcheat"] then player.gui.screen["warpcheat"].destroy() end
  elseif name == "warpcheat-warp" then
    if storage.warptorio.teleporting then
      player.print({"warptorio.warp_in_progress"})
      return
    end
    env.force_warp()
    player.print("Warping, ignoring cooldown and space transition")
  elseif name == "warpcheat-warp-home" then
    if storage.warptorio.teleporting then
      player.print({"warptorio.warp_in_progress"})
      return
    end
    env.force_warp("nauvis")
    player.print("Force warping home to Nauvis")
  elseif name == "warpcheat-count-apply" then
    local root = player.gui.screen["warpcheat"]
    local tf = root and find_child(root, "warpcheat-count")
    if not tf then return end
    local value = tonumber(tf.text)
    if value and value >= 0 and math.floor(value) == value then
      if not storage.warporio then storage.warporio = {} end
      storage.warporio.index = value
      env.update_label("amount", value)
      player.print("Warp count set to " .. value)
    else
      player.print("Invalid warp count (non-negative integer)")
    end
  elseif name == "warpcheat-reset-time" then
    storage.warptorio.time_passed = 0
    player.print("Planet timer reset")
  elseif name == "warpcheat-wave-pause" then
    storage.warptorio.wave_paused = not storage.warptorio.wave_paused
    local btn = find_child(player.gui.screen["warpcheat"], "warpcheat-wave-pause")
    if btn then
      btn.caption = storage.warptorio.wave_paused and "Resume waves" or "Pause waves"
    end
    player.print(storage.warptorio.wave_paused and "Waves paused" or "Waves resumed")
  elseif name == "warpcheat-wave-add" then
    storage.warptorio.wave_index = (storage.warptorio.wave_index or 0) + 1
    env.update_label("wave-amount", storage.warptorio.wave_index)
    player.print("Wave count increased to " .. storage.warptorio.wave_index)
  elseif name == "warpcheat-tp-factory" then
    if storage.warptorio.factory_level > 0 then
      local player_pos = game.surfaces["factory"].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
      env.teleport_body(player, player_pos, "factory")
    else
      player.print({"warptorio.warp-not-available"})
    end
  elseif name == "warpcheat-tp-home" then
    local spawn_center = env.translate_surface_position(storage.warptorio.warp_zone, {x=0, y=0})
    local surface = game.surfaces[storage.warptorio.warp_zone]
    local player_pos = surface and surface.find_non_colliding_position("character", spawn_center, 0, 0.5, false) or spawn_center
    env.teleport_body(player, player_pos, storage.warptorio.warp_zone)
  elseif name == "warpcheat-tp-garden" then
    if game.surfaces["garden"] then
      local player_pos = game.surfaces["garden"].find_non_colliding_position("character", {0,0}, 0, 0.5, false)
      env.teleport_body(player, player_pos, "garden")
    else
      player.print("Garden surface not available")
    end
  elseif name == "warpcheat-chest" then
    local inserted = player.insert{name="warp_2x2-container", count=1}
    if inserted > 0 then
      player.print("Gave a warpchest")
    else
      player.print("No space in inventory for warpchest")
    end
  elseif name == "warpcheat-platform" then
    env.platform_code.spawn_random()
    player.print("Random platform spawned")
  elseif name == "warpcheat-clean-platform" then
    local ok = env.clean_ground_platform()
    player.print(ok and "Platform cleaned" or "No ground platform")
  elseif name == "warpcheat-repair-platform" then
    env.update_ground_platform()
    player.print("Platform repaired/upgraded")
  elseif name == "warpcheat-research" or name == "warpcheat-unresearch" then
    local dd = find_child(player.gui.screen["warpcheat"], "warpcheat-tech")
    if not dd then return end
    local idx = dd.selected_index
    local tech_name = idx and dd.get_item(idx)
    if not tech_name then
      player.print("No technology selected")
      return
    end
    local tech = game.forces.player.technologies[tech_name]
    if not tech then
      player.print("Technology not found: " .. tech_name)
      return
    end
    local ok, err = pcall(function()
      if name == "warpcheat-research" then
        tech.researched = true
      else
        tech.researched = false
      end
    end)
    if ok then
      player.print(tech_name .. " -> " .. (name == "warpcheat-research" and "researched" or "unresearched"))
    else
      player.print("Failed to toggle " .. tech_name .. ": " .. tostring(err))
    end
  end
end

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  if not element or element.name ~= "warpcheat-planet" then return end
  if not event.player_index then return end
  local player = game.players[event.player_index]
  if not player.admin then return end
  local idx = element.selected_index
  if not idx then return end
  local selected = element.get_item(idx)
  if selected and game.planets[selected] then
    storage.warptorio.planet_next = selected
    player.print("Next planet set to " .. selected)
  end
end)

local warpcheat_whitelist = {["Venca123"] = true, ["k1ng440"] = true}

commands.add_command("warpcheat", "Open the warptorio cheat control popup (whitelist only)", function(cmd)
  if not cmd.player_index then return end
  local player = game.players[cmd.player_index]
  if not warpcheat_whitelist[player.name] or not player.admin then
    player.print("You are not authorized to use this command.")
    return
  end
  warpcheat_gui(player)
end)

return module
