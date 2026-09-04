local M = {}

function M.speak(entity, text, seconds)
  if not (entity and entity.valid) then return end

  storage.entity_speech = storage.entity_speech or {}

  local id = entity.unit_number or entity
  if storage.entity_speech[id] then
    if storage.entity_speech[id].bubble and storage.entity_speech[id].bubble.valid then
      storage.entity_speech[id].bubble.destroy()
    end
    storage.entity_speech[id] = nil
  end

  local bubble = entity.surface.create_entity({
    name = "warptorio_speech_bubble",
    text = { "", "[font=default-large-bold]", text, "[/font]" },
    position = { 0, 0 },
    source = entity,
  })

  storage.entity_speech[id] = {
    bubble = bubble,
    tick = (seconds and seconds > 0) and game.tick + seconds * 60 or nil,
  }
end

function M.clear(entity)
  if not (entity and entity.valid) then return end
  local id = entity.unit_number or entity
  if storage.entity_speech and storage.entity_speech[id] then
    if storage.entity_speech[id].bubble and storage.entity_speech[id].bubble.valid then
      storage.entity_speech[id].bubble.destroy()
    end
    storage.entity_speech[id] = nil
  end
end

script.on_nth_tick(61, function(event)
  if not storage.entity_speech then return end
  for id, speech in pairs(storage.entity_speech) do
    if speech.tick and game.tick >= speech.tick then
      if speech.bubble and speech.bubble.valid then
        speech.bubble.destroy()
      end
      storage.entity_speech[id] = nil
    end
  end
end)

return M