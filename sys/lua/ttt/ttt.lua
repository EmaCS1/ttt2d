TTT = {}

-- {{{ Includes
dofile("sys/lua/lapi/lapi.lua")
lapi.load("plugins/walk.lua")

dofile("sys/lua/ttt/player.lua")
dofile("sys/lua/ttt/karma.lua")
dofile("sys/lua/ttt/config.lua")
dofile("sys/lua/ttt/chat.lua")
dofile("sys/lua/ttt/hud.lua")
-- }}}

-- {{{ Game settings
Game.mp_randomspawn = 0
Game.mp_autoteambalance = 0
Game.mp_teamkillpenalty = 0
Game.mp_damagefactor = 1.1
Game.mp_killinfo = 0
Game.sv_friendlyfire = 1
Game.mp_hud = 0
Game.mp_radar = 0
Game.sv_gamemode = 2
Game.sv_fow = 1
Game.mp_mapvoteratio = 0
Game.mp_shotweakening = 100
-- }}}

-- {{{ Initial stuff
math.randomseed(os.time() + os.clock()*1000)

Walk.scan() -- scan walkable tiles

TTT.state = S_WAITING
TTT.round_started = os.time()
TTT.round_count = 0

-- fix bots
for i=1,32 do
    Player(i).hud = {}
end
-- }}}

-- {{{ Hooks
Hook("startround", function()
    print(Color.traitor.."TTT startround")

    if #Player.table < 2 then
        print("no enough players")
        return
    end

    TTT.round_started = os.time()
    TTT.round_count = TTT.round_count+1

    TTT.state = S_PREPARING

    Player.each(function(p)
        if p.health > 0 then
            p.weapons = {50}
        end

        p:set_preparing()
    end)

    TTT.spawn_items()

    Timer(15000, function()
        TTT.select_teams()
        TTT.state = S_RUNNING
    end)

    TTT.round_timer = Timer(180000, function()
        msg(Color.white.."Time ran out!"..Color.traitor.." Traitors lost!@C")
        TTT.round_end(R_INNOCENT)
    end)
end)

Hook("join", function(p)
    print(Color.traitor.."TTT join")
    p.joined = os.time()
    p:reset_data()
    p:load_data()

    if not p.hud then
        p.hud = {}
    end

    if TTT.state == S_PREPARING then
        p:set_preparing()
    else
        p:set_spectator()
    end
end)

Hook("spawn", function(p)
    if TTT.state == S_RUNNING and not p:is_mia() then
        p.info = {}
        p.body = {}
        Timer(1, function()
            p:set_spectator()
        end)
    end

    return "x"
end)

Hook("die", function(p)

    if p:is_mia() then
        p:spawn(p.x, p.y)

    elseif not p:is_spectator() then
        p:set_mia()
    end

    return 1
end)

Hook("team", function(p, team)
    if not p.change_team then
        return 1
    end
end)

Hook("hit", function(victim, p, wpn, hpdmg, apdmg, rawdmg)
    if TTT.state ~= S_RUNNING then
        return 1
    end

    if type(p) ~= "table" then
        p = victim
    end

    if p:is_mia() or victim:is_mia() then
        return 1
    end

    local newdmg = math.ceil(hpdmg * p.damagefactor)
    Karma.hurt(p, victim, newdmg)

    if victim.health-newdmg > 0 then
        victim.health = victim.health-newdmg

    else
        Karma.killed(p, victim)
        victim:set_mia(p)
    end

    return 1
end)

Hook("use", function(p)
    Player.each(function(p2)
        if not p2.info then -- if player doesn't have a corpse
            return
        end

        local info = p2.info
        local distx = math.abs(p.x-info.x)
        local disty = math.abs(p.y-info.y)

        if distx+disty > 32 then
            return
        end

        if info.found then
            p:msg(Color.white.."This body belongs to "..info.cname)

            if p:is_detective() then
                local time = os.time()-info.time
                p:msg(Color.detective.."He was killed "..time.." seconds ago using weapon "..item(info.killer_wpn,"name"))
            end

        else
            info.found = true

            p2.body:t_alpha(2000, 1)
            p2:set_spectator()

            if p:is_detective() then
                msg(Color.detective..p.name..Color.white.." found the body of "..info.cname.."@C")
            else
                msg(Color.innocent..p.name..Color.white.." found the body of "..info.cname.."@C")
            end
        end

        return
    end)
end)

Hook("drop", function(p)
    Timer(1, function()
        p.weapon = 50
    end)
end)

Hook("radio", function()
    return 1
end)

Hook("buy", function()
    return 1
end)

Hook("leave", function(p)
    p.body = nil
    p.info = nil
    p.karma = nil
end)


Hook("second", function()
    local time = os.time() - TTT.round_started

    if TTT.state == S_RUNNING then
        local traitors = 0
        local innocent = 0

        Player.each_living(function (p)
            if p:is_traitor() then
                traitors = traitors+1
            elseif not p:is_mia() then
                innocent = innocent+1
            end
        end)

        if traitors == 0 then
            msg(Color.white.."All traitors are gone!"..Color.innocent.." Innocent won!@C")
            TTT.round_end(R_INNOCENT)

        elseif innocent == 0 then
            msg(Color.traitor.."Traitors"..Color.white.." won!@C")
            TTT.round_end(R_TRAITOR)

        end

    elseif TTT.state == S_WAITING then
        if #Player.table > 1 then
            print("Start new round")
            Parse("endround", 1)
        end
    end
end)

TTT.traitorshop = {
    {1, "USP"},
    {3, "M4A1"},
    {4, "Teleporter"},
    {4, "Spoofer"},
    {50, "Multitool"}
}

Hook("severaction", function(p, action)
    if TTT.state == S_RUNNING then
        if p:is_traitor() then
            local points = math.floor(p.points-p.points_used)
            local m = Menu("Traitor Shop (Points: " .. points .. " )")

            for k,v in pairs(TTT.traitorshop) do
                local label = v[2] .. "|" .. v[1]
                if points < v[1] then
                    label = "("..label..")"
                end
                m:button({label, k})
            end

            m:bind(function(p, label, item)
                if not p:is_traitor() or TTT.state ~= S_RUNNING then
                    p:msg(Color.white.."You can't buy Traitor Shop items right now.")
                    return
                end

                local price = TTT.traitorshop[item][1]
                if points < price then
                    p:msg(Color.white.."You don't have enought points for this.")
                    return
                end

                if item > 2 then
                    p:msg(Color.white.."Item currently disabled sorry.")
                    return
                end

                if item == 1 then
                    p:equip(1)
                elseif item == 2 then
                    p:equip(32)
                end

                p.points_used = p.points_used + price
                p:msg(Color.white.."You bought "..TTT.traitorshop[item][2])
            end)
        end
    end
end)
-- }}}

-- {{{ General functions
TTT.get_color = function(role)
    local tbl = {}
    tbl[R_TRAITOR] = Color.traitor
    tbl[R_DETECTIVE] = Color.detective
    tbl[R_INNOCENT] = Color.innocent

    return tbl[role] or Color.spectator
end

TTT.round_end = function(winner)
    TTT.state = S_WAITING

    if TTT.round_timer then
        TTT.round_timer:remove()
        TTT.round_timer = nil
    end

    -- tell killers etc
    Player.each(function(p)
        if p.info and p.info.killer_cname then
            p:msg(Color.white .. "You were killed by " .. p.info.killer_cname)
        end
    end)


    Karma.round_end(winner)

    Player.each(function(p)
        p:save_data()
    end)
end

TTT.spawn_items = function()
    local players = Player.table
    
    local wpnlist1 = {11, 20, 20, 23, 24}
    local wpnlist2 = {2, 2, 2, 2, 3, 6}

    local wpn1 = math.min(#players, 24)
    local wpn2 = math.min(#players, 24)

    for i=1,wpn1 do
        Timer(i*100, function()
            local pos = Walk.random()
            local wpn = wpnlist1[math.random(#wpnlist1)]
            Parse("spawnitem", wpn, pos.x, pos.y)
        end)
    end

    for i=1,wpn2 do
        Timer(i*100, function()
            local pos = Walk.random()
            local wpn = wpnlist2[math.random(#wpnlist2)]
            Parse("spawnitem", wpn, pos.x, pos.y)
        end)
    end
end

TTT.notify_teams = function()
    Player.each(function(p)
        if p:is_detective() then
            msg(p:c_name()..Color.white.." is detective.")
            return

        elseif not p:is_traitor() then
            return
        end

        for _,fellow in pairs(TTT.traitors) do
            if p ~= fellow then
                p:msg(fellow:c_name()..Color.white.." is traitor.")
            end
        end
    end)
end

TTT.select_teams = function()
    Player.each(function(p)
        if p.health == 0 then
            p:set_preparing()
            p:move_to_game()
        end
    end)

    local players = Player.tableliving
    local t_num = math.ceil(#players / 6)
    local d_num = math.floor(#players / 9)

    -- remove mias from list
    for k,p in pairs(players) do
        if p:is_mia() then
            table.remove(players, k)
        end
    end

    -- select traitors
    TTT.traitors = {}
    for i=1,t_num do
        local rnd = math.random(#players)
        local p = table.remove(players, rnd)

        p:set_traitor()
        table.insert(TTT.traitors, p)
    end

    -- select detectives
    TTT.detectives = {}
    for i=1,d_num do
        local rnd = math.random(#players)
        local p = table.remove(players, rnd)

        p:set_detective()
        table.insert(TTT.detectives, p)
    end

    for _,p in pairs(players) do
        p:set_innocent()
    end

    TTT.notify_teams()
    Hud.mark_players()
end
-- }}}
