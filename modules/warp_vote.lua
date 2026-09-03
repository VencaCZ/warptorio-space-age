local warp_settings = require("internal_settings")

local M = {}

function M.is_eligible(player_index)
    local player = game.get_player(player_index)
    if not player then return false end
    if player.online_time < warp_settings.time.new_player_threshold then return false end
    if player.afk_time >= warp_settings.time.afk_threshold then return false end
    return true
end

function M.get_eligible_count()
    local count = 0
    for _, p in ipairs(game.forces["player"].connected_players) do
        if p.online_time >= warp_settings.time.new_player_threshold
           and p.afk_time < warp_settings.time.afk_threshold then
            count = count + 1
        end
    end
    return count
end

function M.process_vote(player_index)
    local player = game.get_player(player_index)
    if player and player.admin then
        if not storage.warptorio.admin_clicks then
            storage.warptorio.admin_clicks = {}
        end
        if not storage.warptorio.admin_click_start then
            storage.warptorio.admin_click_start = {}
        end
        local clicks = storage.warptorio.admin_clicks
        local starts = storage.warptorio.admin_click_start
        if not clicks[player_index] or (game.tick - starts[player_index]) > 120 then
            clicks[player_index] = 0
            starts[player_index] = game.tick
        end
        clicks[player_index] = clicks[player_index] + 1
        local needed = warp_settings.time.admin_clicks_required - clicks[player_index]
        if needed <= 0 then
            clicks[player_index] = 0
            starts[player_index] = game.tick
            return "proceed"
        end
        return "admin_clicks", player.name, needed
    end

    if not storage.warptorio.clicks_to_teleport then
        storage.warptorio.clicks_to_teleport = {}
    end

    if not player then
        return "too_young", "Unknown"
    end

    local eligible_amount = M.get_eligible_count()
    local no_eligible = eligible_amount == 0
    if no_eligible then
        eligible_amount = #game.forces["player"].connected_players
    end

    if not M.is_eligible(player_index) then
        if not no_eligible then
            if player.afk_time >= warp_settings.time.afk_threshold then
                return "afk", player.name
            else
                return "too_young", player.name
            end
        end
    end

    if eligible_amount <= 1 then
        return "proceed"
    end

    for _, v in ipairs(storage.warptorio.clicks_to_teleport) do
        if v == player_index then
            return "already_voted"
        end
    end

    table.insert(storage.warptorio.clicks_to_teleport, player_index)
    local ratio = #storage.warptorio.clicks_to_teleport / eligible_amount
    if ratio < warp_settings.time.clicks_to_teleport then
        local needed = math.ceil(eligible_amount * warp_settings.time.clicks_to_teleport)
        local n = needed - #storage.warptorio.clicks_to_teleport
        return "need_votes", player.name, n
    end

    return "proceed"
end

function M.cleanup_player(player_index)
    if storage.warptorio.clicks_to_teleport then
        for i = #storage.warptorio.clicks_to_teleport, 1, -1 do
            if storage.warptorio.clicks_to_teleport[i] == player_index then
                table.remove(storage.warptorio.clicks_to_teleport, i)
            end
        end
    end
    if storage.warptorio.admin_clicks then
        storage.warptorio.admin_clicks[player_index] = nil
    end
    if storage.warptorio.admin_click_start then
        storage.warptorio.admin_click_start[player_index] = nil
    end
end

return M
