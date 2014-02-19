Chat = {}
Chat.commands = {}

function Chat.add_command(cmd, params, desc, rank, func)
    if Chat.commands[cmd] then
        error("Chat command already exists: " .. cmd)
    else
        Chat.commands[cmd] = {cmd = cmd, params = params, desc = desc, rank = rank, func = func}
    end
end

function Chat.literalize(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

function Chat.shortcut(message)
    local players = Player.table

    for word in string.gmatch(message, "%S+") do
        if word:sub(1,1) == "@" and word:len() > 1 then
            local name = word:sub(2):lower()

            for _,p in pairs(players) do
                if string.starts(p.name:lower(), name)
                    or string.find(p.name:lower(), "[^%a]"..Chat.literalize(name)) then
                    message = message:gsub(Chat.literalize(word), p.name)
                end
            end
        end
    end

    return message
end

function Chat.command(p, message)
    local command = message:match("^[!/][%a_]+")
    if not command then
        return false
    end

    if not Chat.commands[command:sub(2)] then
        p:msg(Color.traitor .. "Command not found: " .. command)
        return true
    end

    local func = Chat.commands[command:sub(2)].func
    local rank = Chat.commands[command:sub(2)].rank

    if p.rank < rank then
        p:msg(Color.traitor .. "You're not allowed to use command \"" .. command .. "\"")
    else
        print(p.name .. "[#" .. p.usgn .. "] used command: " .. message)
        func(p, message:sub(command:len()+2))
    end

    return true
end

function Chat.format(p, message, role)
    local color = TTT.get_color(role or p.role)
    message = message:gsub('[\169\166]', ''):gsub('@C', '')

    return color .. p.name .. Color.white .. ': ' .. message
end

function Chat.traitor_message(p, message)
    local players = Player.table

    if not TTT.traitor_round then
        for _,recv in pairs(players) do
            if recv:is_traitor() then
                recv:msg(Chat.format(p, message))
            else
                recv:msg(Chat.format(p, message, R_INNOCENT))
            end
        end
    else
        p:msg(Chat.format(p, message))
        for _,recv in pairs(players) do
            if recv ~= p then
                recv:msg(Chat.format(p, message, R_INNOCENT))
            end
        end
    end
end

function Chat.traitor_message_team(p, message)
    local players = Player.table

    if not TTT.traitor_round then
        for _,recv in pairs(players) do
            if recv:is_traitor() then
                recv:msg("(TRAITORS) " .. Chat.format(p, message))
            end
        end
    else
       p:msg("(TRAITORS) " .. Chat.format(p, message))
    end
end

function Chat.spectator_message(p, message)
    local players = Player.table

    for _,recv in pairs(players) do
        if recv:is_spectator() or recv:is_mia() or TTT.state ~= S_RUNNING then
            recv:msg(Chat.format(p, message))
        end
    end
end

Hook('say', function(p, message)
    message = Chat.shortcut(message)

    if Chat.command(p, message) then
        return 1
    end

    if p:is_traitor() then
        Chat.traitor_message(p, message)

    elseif p:is_spectator() or p:is_mia() then
        Chat.spectator_message(p, message)

    else
        msg(Chat.format(p, message))
    end

    return 1
end)

Hook('sayteam', function(p, message)
    message = Chat.shortcut(message)

    if p:is_traitor() then
        Chat.traitor_message_team(p, message)
    end

    return 1
end)

Chat.add_command("commands", "", "Show available commands", RANK_GUEST, function(p, arg)
    for command,tbl in pairs(Chat.commands) do
        if p.rank >= tbl.rank then
            p:msg(Color.white .. command .. " " .. tbl.params ..  " - " .. tbl.desc)
        end
    end
end)

Chat.add_command("map", "<mapname>", "Change map", RANK_MODERATOR, function(p, arg)
    Parse('map', arg)
end)

Chat.add_command("maplist", "", "List official maps", RANK_MODERATOR, function(p, arg)
    for _,map in pairs(TTT.maps) do
        p:msg(Color.white .. map)
    end
end)

Chat.add_command("bc", "<message>", "Broadcast a message", RANK_MODERATOR, function(p, arg)
    msg(Color.white .. arg)
end)

Chat.add_command("reset", "<id>", "Reset player's karma", RANK_ADMIN, function(p, arg)
    local id = tonumber(arg)
    if not id then
        p:msg(Color.traitor .. "Invalid arguments!")
        return
    end

    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end

    Player(id).karma = Karma.base
    Player(id).score = Karma.base
end)

Chat.add_command("ban", "<id> <duration> <reason>", "Ban player with a reason", RANK_MODERATOR, function(p, arg)
    local id, duration, reason = string.match(arg, "(%d+) (%d+) (.+)")
    id = tonumber(id)
    duration = tonumber(duration)

    if not id or not duration or not reason then
        p:msg(Color.traitor .. "Invalid arguments!")
        return
    end

    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end

    if string.len(reason) < 10 then
        p:msg(Color.traitor .. "Too short reason for a ban")
        return
    end

    if Player(id) == p then
        p:msg(Color.traitor .. "You can't ban yourself")
        return
    end

    local p2 = Player(id)
    p2.bans = p2.bans + 1
    p2:save_data()

    if p2.usgn == 0 then
        p2:banip(duration, reason)
    else
        p2:banusgn(duration, reason)
    end
end)

Chat.add_command("warn", "<id> <message>", "Send player a warning", RANK_MODERATOR, function(p, arg)
    local id, message = string.match(arg, "(%d+) (.+)")
    id = tonumber(id)

    if not id or not message then
        p:msg(Color.traitor .. "Invalid arguments!")
        return
    end

    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end

    Player(id):msg(Color.traitor..message.."@C")
end)

Chat.add_command("stats", "<id>", "View player stats", RANK_MODERATOR, function(p, arg)
    local id = tonumber(arg)
    if not id then
        p:msg(Color.traitor .. "Invalid arguments!")
        return
    end

    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end

    local p2 = Player(id)

    p:msg(Color.white .. "Statistics for " .. p2:c_name())
    p:msg(Color.white .. "Rank: " .. p2.rank)
    p:msg(Color.white .. "Points: " .. math.floor(p2.points) - p2.points_used)
    p:msg(Color.white .. "Points total earned: " .. math.floor(p2.points))
    p:msg(Color.white .. "Bans: " .. p2.bans)
    p:msg(Color.white .. "Teamkills: " .. p2.teamkills)
    local hours = math.floor(p2.playtime/3600)
    local minutes = math.floor(p2.playtime/60) - hours*60
    p:msg(Color.white .. "Time played: " .. hours .. "h " .. minutes .. "min")
    p:msg(Color.white .. "Best karma: " .. p2.topkarma)
end)

Chat.add_command("status", "", "View your status", RANK_GUEST, function(p, arg)
    p:msg(Color.white .. "Points: " .. math.floor(p.points) - p.points_used)
    p:msg(Color.white .. "Points total earned: " .. math.floor(p.points))
    p:msg(Color.white .. "Best karma: " .. p.topkarma)
    local hours = math.floor(p.playtime/3600)
    local minutes = math.floor(p.playtime/60) - hours*60
    p:msg(Color.white .. "Time played: " .. hours .. "h " .. minutes .. "min")
end)

Chat.add_command("kick", "<id>", "Kick player", RANK_MODERATOR, function(p, arg)
    local id = tonumber(arg)
    if not id then
        p:msg(Color.traitor .. "Invalid arguments!")
        return
    end

    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end
    Player(id):kick("Kicked by " .. p.name)
end)

Chat.add_command("vote", "", "Begin map voting", RANK_MODERATOR, function(p, arg)
    TTT.vote_map()
end)

Chat.add_command("fun", "", "Set next round traitor only", RANK_MODERATOR, function(p, arg)
    TTT.fun = true
end)

Chat.add_command("report", "<message>", "Send message to the admins", RANK_GUEST, function(p, arg)
    Player.each(function(p2)
        if p2.rank >= RANK_MODERATOR then
            p2:msg(Color.traitor .. "[REPORT] " .. Color.white .. p.name .. ": " .. arg)
        end
    end)
end)

Chat.add_command("rank", "<id> <ranknumber>", "Set player rank", RANK_ADMIN, function(p, arg)
    local id, rank = string.match(arg, "(%d+) (%d+)")
    id = tonumber(id)
    rank = tonumber(rank)

    if not id or not rank then
        p:msg(Color.traitor .. "Invalid arguments!")
        return
    end

    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end
    Player(id).rank = rank
end)
