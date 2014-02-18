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
TTT.traitor_round = false

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
        p.grenade = nil

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
    if p == 0 then
        print("Join hook failed! Player ID is 0?")
    end

    print(Color.traitor.."TTT join")
    p.joined = os.time()
    p:reset_data()
    p:load_data()

    if not p.hud then
        p.hud = {}
    end

    if TTT.state == S_PREPARING then
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

Hook("endround", function(reason)
    Player.each(function(p)
        if p.has_armor then
            p:set_spectator()
            p.has_armor = false
        end
    end)
end)

Hook("ms100", function()
    Player.each(function(p)
        p:reqcld(2)
    end)
end)

Hook("clientdata", function(p, mode, x, y)
    if not p or p == 0 then
        print("Failed to get client data! Player ID is invalid")
        return
    end

    if mode == 2 then
        p.mouse = {x=x, y=y}
    end
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

        if p:is_detective() then
            local time = os.time()-info.time
            local txt = Color.detective.."He was killed "..time.." seconds ago"
            local wpn = itemtype(info.killer_wpn, "name")
            if wpn then
                p:msg(txt.." using "..Color.traitor..wpn)
            else
                p:msg(txt)
            end

            local img = Image("gfx/sprites/snowflage.bmp<a>", info.x, info.y, 3, p.id)
            img:scale(0.2, 0.2)
            img:t_move(3000, info.killer_x, info.killer_y)
            img:t_scale(5000, 0.5, 0.5)
            Timer(5000, function()
                img:remove()
            end)
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
    p:save_data()
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

        if TTT.traitor_round then
            if traitors == 1 then
                msg(Color.white.."Only one traitor left! He won!@C")
                TTT.round_end(R_TRAITOR)
            end
        else
            if traitors == 0 then
                msg(Color.white.."All traitors are gone!"..Color.innocent.." Innocent won!@C")
                TTT.round_end(R_INNOCENT)

            elseif innocent == 0 then
                msg(Color.traitor.."Traitors"..Color.white.." won!@C")
                TTT.round_end(R_TRAITOR)

            end
        end

    elseif TTT.state == S_WAITING then
        if TTT.voter_count > 0 then
            local mapname = nil
            local votes = 0
            for k,v in pairs(TTT.vote_result) do
                print("voteresult " .. k .. " " .. v)
                if v > votes then
                    print("chosen")
                    votes = v
                    mapname = k
                end
            end

            if mapname then
                Parse("changelevel", mapname)
            else
                msg("Map voting failed.")
                TTT.voter_count = 0
            end
        end

        if #Player.table > 1 then
            print("Start new round")
            Parse("endround", 1)
            TTT.state = S_STARTING
        end
    end
end)

TTT.traitorshop = {
    {1, "USP"},
    {4, "M4A1"},
    {4, "Armor"},
    {10, "Stealth Suit"},
    {1, "Smoke Grenade"},
    {2, "HE Grenade"}
}
TTT.detectiveshop = {
    {1, "Medikit"},
    {1, "Flare"},
    {2, "Armor"},
    {5, "Tactical Shield"}
}

function TTT.give_grenade(p, id)
    if p.grenade then
        return false
    else
        p.grenade = id
        p:msg(Color.white .. "You got a grenade! Press F3 to throw it@C")
        return true
    end
end

Hook("serveraction", function(p, action)
    if TTT.state == S_RUNNING and action == 1 then
        if p:is_traitor() then
            local points = math.floor(p.points-p.points_used)
            local m = p:menu("Traitor Shop (Points: " .. points .. " )")

            for k,v in pairs(TTT.traitorshop) do
                local label = v[2] .. "|" .. v[1]
                if points < v[1] then
                    label = "("..label..")"
                end
                m:button(k, label)
            end

            m:bind(function(p, item, label)
                if not TTT.traitorshop[item] then
                    return
                elseif not p:is_traitor() or TTT.state ~= S_RUNNING then
                    p:msg(Color.white.."You can't buy Traitor Shop items right now.")
                    return
                end

                local price = TTT.traitorshop[item][1]
                if points < price then
                    p:msg(Color.white.."You don't have enought points for this.")
                    return
                end

                if item == 1 then
                    p:equip(1)
                elseif item == 2 then
                    p:equip(32)
                elseif item == 3 then
                    p:equip(79)
                    p.has_armor = true
                elseif item == 4 then
                    p:equip(84)
                    p.has_armor = true
                elseif item == 5 then
                    if not TTT.give_grenade(p, 53) then
                        return
                    end
                elseif item == 6 then
                    if not TTT.give_grenade(p, 51) then
                        return
                    end
                end

                p.points_used = p.points_used + price
                p:msg(Color.white.."You bought "..TTT.traitorshop[item][2])
            end)
        elseif p:is_detective() then
            local points = math.floor(p.points-p.points_used)
            local m = p:menu("Detective Shop (Points: " .. points .. " )")

            for k,v in pairs(TTT.detectiveshop) do
                local label = v[2] .. "|" .. v[1]
                if points < v[1] then
                    label = "("..label..")"
                end
                m:button(k, label)
            end

            m:bind(function(p, item, label)
                if not TTT.detectiveshop[item] then
                    return
                elseif not p:is_detective() or TTT.state ~= S_RUNNING then
                    p:msg(Color.white.."You can't buy Detective Shop items right now.")
                    return
                end

                local price = TTT.detectiveshop[item][1]
                if points < price then
                    p:msg(Color.white.."You don't have enought points for this.")
                    return
                end

                if item == 1 then
                    Parse("spawnitem", 64, p.tilex, p.tiley)
                elseif item == 2 then
                    if not TTT.give_grenade(p, 54) then
                        return
                    end
                elseif item == 3 then
                    p:equip(79)
                    p.has_armor = true
                elseif item == 4 then
                    p:equip(41)
                end

                p.points_used = p.points_used + price
                p:msg(Color.white.."You bought "..TTT.detectiveshop[item][2])
            end)
        end
    elseif TTT.state == S_RUNNING and action == 2 then
        if p:is_traitor() or p:is_detective() then
            if not p.grenade then
                p:msg(Color.traitor.."You don't have a grenade!")
            end

            local distx = p.x-p.mouse.x
            local disty = p.y-p.mouse.y
            local dist = math.sqrt(distx*distx + disty*disty)
            local itemtype = p.grenade

            Parse("spawnprojectile", p.id, itemtype, p.x, p.y, dist, p.rot)
            p.grenade = nil
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
    if TTT.traitor_round then
        msg(Color.white .. "Everyone was a traitor!")

    elseif TTT.traitors_cname then
        if #TTT.traitors_cname == 1 then
            msg(TTT.traitors_cname[1] .. Color.white .. " was the only traitor.")
        else
            msg(Color.white .. "Traitors were:")
            for _,cname in pairs(TTT.traitors_cname) do
                msg(cname)
            end
        end
    end

    Player.each(function(p)
        if p.info and p.info.killer_cname then
            local txt = Color.white .. "You were killed by " .. p.info.killer_cname
            local wpn = itemtype(p.info.killer_wpn, "name")
            if wpn then
                txt = txt .. Color.white .. " using " .. wpn
            end
            p:msg(txt)
        end
    end)


    Karma.round_end(winner)

    Player.each(function(p)
        p:save_data()
    end)
end

TTT.vote_result = {}
TTT.vote_count = 0
TTT.voter_count = 0
TTT.vote_nextmap = nil

TTT.vote_menu = function(p, key, value)
    TTT.vote_result[key] = TTT.vote_result[key] + 1

    TTT.vote_count = TTT.vote_count + 1

    if TTT.vote_result[key] > TTT.voter_count/2 then
        msg(Colow.white .. "Next map: " .. key .. "@C")
        TTT.vote_nextmap = key
    end
end

TTT.vote_map = function()
    msg(Color.white .. "Time to vote next map!@C")

    local menubuttons = {}

    for k,v in pairs(TTT.maps) do
        if v ~= Game.sv_map then
            table.insert(menubuttons, {v, v})
            TTT.vote_result[k] = 0
        end
    end

    Timer(1000, function()
        Player.each(function(p)
            if p.karma > 700 then
                local m = p:menu("Vote map")
                m.buttons = menubuttons
                m:bind(TTT.vote_menu)

                TTT.voter_count = TTT.voter_count + 1
            end
        end)
    end)
end

TTT.spawn_items = function()
    local players = Player.table
    
    local wpnlist1 = {10, 20, 20, 20, 23, 23, 23, 24, 24, 24}
    local wpnlist2 = {2, 2, 2, 2, 3, 6}

    local wpn1 = math.min(#players, 24)
    local wpn2 = math.min(#players, 24)

    for i=1,wpn1 do
        Timer(i*100, function()
            local pos = Walk.random()
            local wpn = wpnlist1[math.random(#wpnlist1)]
            if math.random(1000) == 42 then
                Parse("spawnitem", 30, pos.x, pos.y)
            else
                Parse("spawnitem", wpn, pos.x, pos.y)
            end
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
    if TTT.traitor_round then
        return
    end

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

    if #Player.table < 4 or TTT.fun then
        TTT.fun = nil
        TTT.traitor_round = true
        t_num = #players
        d_num = 0
    else
        TTT.traitor_round = false
    end

    -- remove mias from list
    for k,p in pairs(players) do
        if p:is_mia() then
            table.remove(players, k)
        end
    end

    -- select traitors
    TTT.traitors = {}
    TTT.traitors_cname = {}
    for i=1,t_num do
        local rnd = math.random(#players)
        local p = table.remove(players, rnd)

        p:set_traitor()
        table.insert(TTT.traitors, p)
        table.insert(TTT.traitors_cname, p:c_name())
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
