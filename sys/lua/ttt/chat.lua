Chat = {}
Chat.commands = {}

function Chat.add_command(cmd, desc, rank, func)
    if Chat.commands[cmd] then
        error("Chat command already exists: " .. cmd)
    else
        Chat.commands[cmd] = {desc = desc, rank = rank, func = func}
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
                if string.starts(p.name:lower(), name) then
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
        p:msg(Color.traitor .. "Command not found!")
        return true
    end

    local func = Chat.commands[command:sub(2)].func
    local rank = Chat.commands[command:sub(2)].rank

    if p.rank < rank then
        p:msg(Color.traitor .. "You're not allowed to use that command!")
    else
        print(p.name .. " used command " .. message)
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

    for _,recv in pairs(players) do
        if recv:is_traitor() then
            recv:msg(Chat.format(p, message))
        else
            recv:msg(Chat.format(p, message, R_INNOCENT))
        end
    end
end

function Chat.traitor_message_team(p, message)
    local players = Player.table

    for _,recv in pairs(players) do
        if recv:is_traitor() then
            recv:msg("(TRAITORS) " .. Chat.format(p, message))
        end
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

Chat.add_command("commands", "Show commands available", RANK_GUEST, function(p, arg)
    for command,tbl in pairs(Chat.commands) do
        if p.rank >= tbl.rank then
            p:msg(Color.white .. command .. " - " .. tbl.desc)
        end
    end
end)

Chat.add_command("map", "Change map", RANK_MODERATOR, function(p, arg)
    Parse('map', arg)
end)

Chat.add_command("maplist", "List official maps", RANK_MODERATOR, function(p, arg)
    for _,map in pairs(TTT.maps) do
        p:msg(Color.white .. map)
    end
end)

Chat.add_command("bc", "Broadcast a message", RANK_MODERATOR, function(p, arg)
    msg(Color.white .. arg)
end)

Chat.add_command("reset", "Reset player's karma", RANK_ADMIN, function(p, arg)
    local id = tonumber(arg)
    if not id or  id < 1 or id > 32 then
        p:msg("Invalid id")
        return
    end

    Player(id).karma = Karma.base
    Player(id).score = Karma.base
end)

Chat.add_command("ban", "Ban player for 6 hours", RANK_MODERATOR, function(p, arg)
    local id = tonumber(arg)
    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end
    if Player(id).usgn == 0 then
        Player(id):banip(6*60, "Banned by " .. p.name)
    else
        Player(id):banusgn(6*60, "Banned by " .. p.name)
    end
end)

Chat.add_command("kick", "Kick player", RANK_MODERATOR, function(p, arg)
    local id = tonumber(arg)
    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end
    Player(id):kick("Kicked by " .. p.name)
end)

Chat.add_command("make_moderator", "Make moderator", RANK_ADMIN, function(p, arg)
    local id = tonumber(arg)
    if not Player(id) or not Player(id).exists then
        p:msg(Color.traitor .. "Player with that ID doesn't exist")
        return
    end
    Player(id).rank = RANK_MODERATOR
end)

Chat.add_command("points", "Show how many points you got", RANK_GUEST, function(p, arg)
    local points = math.floor(p.points)
    p:msg(Color.white.."Points: "..Color.traitor..(points-p.points_used)..Color.white.." Total earned: "..points)
end)
