Chat = {}

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
            recv:msg(Chat.format(p, message, ROLE_INNOCENT))
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
        if recv:is_spectator() or recv:is_mia() or not TTT:is_running() then
            recv:msg(Chat.format(p, message))
        end
    end
end

Hook('say', function(p, message)
    message = Chat.shortcut(message)

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
