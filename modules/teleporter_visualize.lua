local M = {}

local env

-- No module-level copy of state: control.lua runs before storage is restored
-- (and again on every MP join), so anything cached here would differ between
-- the server and a joining client and desync. Read storage on demand instead.
local function state()
  storage.warptorio = storage.warptorio or {}
  storage.warptorio.teleporter_visualize = storage.warptorio.teleporter_visualize or {}
  return storage.warptorio.teleporter_visualize
end

local function ensure_render_ids()
  local st = state()
  if type(st.render_ids) ~= "table" then
    st.render_ids = {}
  end
  return st.render_ids
end

local function is_active()
  local vis = storage.warptorio and storage.warptorio.teleporter_visualize
  return vis ~= nil and vis.active == true
end

-- rendering.draw_* returns a LuaRenderObject in 2.x; plain numeric ids may
-- still be around from older saves.
local function destroy_object(id)
  local obj = id
  if type(id) == "number" then
    obj = rendering.get_object_by_id(id)
  end
  if obj and obj.valid then
    obj.destroy()
  end
end

local function clear_all()
  local render_ids = ensure_render_ids()
  for _, id in pairs(render_ids) do
    destroy_object(id)
  end
  for id in pairs(render_ids) do
    render_ids[id] = nil
  end
end

local function draw_zone(surface, pos, box, color, label)
  if not surface or not surface.valid then return end
  local render_ids = ensure_render_ids()
  local sx = pos.x + (box.minx or -0.4)
  local sy = pos.y + (box.miny or -0.4)
  local ex = pos.x + (box.maxx or 2.4)
  local ey = pos.y + (box.maxy or 2.5)
  local r, g, b = color[1], color[2], color[3]

  local corners = {
    {sx, sy}, {ex, sy}, {ex, ey}, {sx, ey}, {sx, sy}
  }
  for i = 1, 4 do
    table.insert(render_ids, rendering.draw_line{
      surface = surface, from = corners[i], to = corners[i + 1],
      color = {r, g, b, 0.9}, width = 3, time_to_live = 0, draw_on_ground = true,
    })
  end

  table.insert(render_ids, rendering.draw_rectangle{
    surface = surface,
    left_top = {sx, sy}, right_bottom = {ex, ey},
    color = {r, g, b, 0.12}, filled = true, time_to_live = 0, draw_on_ground = true,
  })

  local cx = (sx + ex) / 2
  local cy = (sy + ey) / 2
  table.insert(render_ids, rendering.draw_text{
    surface = surface, target = {cx, sy - 0.8},
    text = label, color = {r, g, b, 1}, scale = 0.8,
    alignment = "center", time_to_live = 0,
  })
end

local function refresh()
  clear_all()
  if not is_active() then return end

  local warp_zone = env.get_warp_zone and env.get_warp_zone() or storage.warptorio.warp_zone
  log("[teleporter_visualize] refresh warp_zone=" .. tostring(warp_zone) ..
      " biochamber=" .. tostring(storage.warptorio.biochamber_level))
  for name, pad in pairs(env.teleporters) do
    if not pad.biochamber or storage.warptorio.biochamber_level then
      local surface_name = pad.surface == "$warp_zone" and warp_zone or pad.surface
      local surface = game.surfaces[surface_name]
      log("[teleporter_visualize]   pad=" .. tostring(name) .. " surface=" .. tostring(surface_name) ..
          " exists=" .. tostring(surface ~= nil) .. " valid=" .. tostring(surface and surface.valid))
      if surface and surface.valid then
        local pos = pad.position
        if env.translate_surface_position then
          pos = env.translate_surface_position(surface_name, pad.position)
        end
        draw_zone(surface, pos, pad.box, pad.color,
          "PAD: " .. name)
      end
    end
  end
end

-- Called from the control.lua main chunk: only wire up callbacks here. No
-- storage or rendering access, since storage is not restored yet and the main
-- chunk also runs on every joining client.
function M.init(env_table)
  env = env_table
end

function M.toggle(player)
  local active = not is_active()
  state().active = active
  if active then
    log("[teleporter_visualize] toggle ON by " .. (player and player.name or "?") .. " on surface=" ..
        tostring(player and player.character and player.character.surface and player.character.surface.name))
    refresh()
    player.print("[color=0.3,1,0.4]Teleporter zones: VISIBLE[/color]")
  else
    clear_all()
    player.print("[color=1,0.5,0.3]Teleporter zones: HIDDEN[/color]")
  end
end

function M.refresh()
  if is_active() then refresh() end
end

M.is_active = is_active

return M
