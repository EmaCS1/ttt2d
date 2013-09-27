dofile('sys/lua/lapi/lapi.lua')
lapi.load('plugins/walk.lua')

dofile('sys/lua/ttt/hud.lua')

Walk.scan()

-- game settings
Game.mp_autoteambalance = 0
Game.mp_teamkillpenalty = 0
Game.mp_damagefactor = 1.3
Game.mp_killinfo = 0
Game.sv_friendlyfire = 1
Game.mp_hud = 0
Game.mp_radar = 0
Game.sv_gamemode = 2
Parse('mp_wpndmg', 'USP', 30)

-- constant
PREPARING = 1
INNOCENT = 2
TRAITOR = 3
DETECTIVE = 4
SPECTATOR = 5
RUNNING = 6
WAITING = 7

-- config
WEAPON_1 = {30, 20, 10}
WEAPON_2 = {2, 4, 69}
TIME_PREPARE = 15
TIME_GAME = 10
TIME_NEXTROUND = 5


-- variables
state = WAITING
lock_team = true
time = 0
round_timer = nil

function start_round()
    state = PREPARING
    
    local rnd = Walk.random()
    local pos = {x=rnd.x*32+16,y=rnd.y*32+16}
    local players = Player.table 
    
    clear_items()
    clear_detectives()
    
    lock_team = false
    for _,ply in pairs(players) do
        clear_traitors(ply)
        ply.team = 1
        ply:spawn(pos.x, pos.y)
        set_role(ply, PREPARING)
        draw_health(ply)
    end
    lock_team = true
    
    spawn_items()
    
    msg(Color(20,220,20).."Go get your weapons!@C")
    set_timer(TIME_PREPARE)
    Timer(TIME_PREPARE*1000, function()
        state = RUNNING
        set_teams()
        set_timer(TIME_GAME)
        
        round_timer = Timer(TIME_GAME*1000, function()
            msg(Color(220, 20, 20).."Traitors lost!@C")
            end_round()
        end)
    end)
    
    
end

function end_round()
    if round_timer then
        round_timer:remove()
    end
    
    state = PREPARING
    Timer(2000, function()
        state = WAITING
    end)
end

function set_teams()
    local players = Player.tableliving
    local t_num = math.ceil(#players / 7)
    local d_num = math.floor(#players / 12)
    
    lock_team = false
    for i=1,t_num do  -- select traitors
        local rnd = math.random(#players)
        local ply = table.remove(players, rnd)
        set_role(ply, TRAITOR)
        
        Timer(1, function()
            mark_traitors(ply)
        end)
    end
    
    for i=1,d_num do  -- select detectives
        local rnd = math.random(#players)
        local ply = table.remove(players, rnd)
        set_role(ply, DETECTIVE)
        
    end
    
    for _,ply in pairs(players) do  -- select innocents
        set_role(ply, INNOCENT)
    end
    
    mark_detectives()
    lock_team = true
end

function spawn_items()
    local players = Player.tableliving
    local wpn_1 = math.max(#players, 5)
    local wpn_2 = math.max(math.floor(#players * 1.5), 10)
    
    for i=1,wpn_1 do
        local wep = WEAPON_1[math.random(#WEAPON_1)]
        local pos = Walk.random()
        Parse('spawnitem', wep, pos.x, pos.y)
    end
    
    for i=1,wpn_2 do
        local wep = WEAPON_2[math.random(#WEAPON_1)]
        local pos = Walk.random()
        Parse('spawnitem', wep, pos.x, pos.y)
    end
end

function clear_items()
    local items = item(0,"table")
    for _,id in pairs(items) do
       Parse('removeitem', id)
    end
end

function set_role(ply, role)
    ply.role = role
    draw_team(ply)
end

function hook_kill(ply, attacker)
    if attacker.role == TRAITOR then
        if ply.role == TRAITOR then
            attacker:msg(Color(220,20,20) .. "Stupid! You just killed a fellow traitor!@C")
        else
            attacker:msg(Color(20,220,20) .. "You just killed " .. ply.name .. "!@C")
        end
    else
        if ply.role == DETECTIVE then
            attacker:msg(Color(220,20,20) .. "Stupid! You just killed a friendly detective!@C")
        elseif not ply.has_hit then
            attacker:msg(Color(220,20,20) .. "Why did you kill him?@C")
        end
    end
end

Hook('buy', function(ply)
    ply:msg(Color(220,20,20) .. "Buying is not allowed!@C")
    return 1
end)

Hook('spawn', function(ply)
    return 'x'
end)

Hook('join', function(ply)
    ply.hud = {}
    set_role(ply, SPECTATOR)
    Timer(1000, function()
        draw_hud(ply)
    end)
end)

Hook('die', function()
    if not lock_team then
        return 1
    end
end)

Hook('team', function(ply, team)
    if team ~= 0 and lock_team then
        return 1
    end
end)

Hook('hit', function(ply, attacker, weapon, hpdmg, apdmg, rawdmg)
    if state ~= RUNNING then return 1 end
    
    Timer(1, function()
        draw_health(ply)
    end)
    
    if type(attacker) == 'table' then
        attacker.has_hit = true
    end
    
    if ply.health - hpdmg < 1 then
        if type(attacker) == 'table' then
            hook_kill(ply, attacker)
        end
        set_role(ply, SPECTATOR)
        ply.team = 0
        return 1
    end
end)

Hook('second', function()
    time = time + 1
    
    
    if state == RUNNING then
        local players = Player.tableliving
        local t_num = 0
        
        for _,ply in pairs(players) do
            if ply.role == TRAITOR then
                t_num = t_num + 1
            end
        end
        
        if t_num == 0 and not preparing then
            msg(Color(20,220,20).."All traitors are gone! Innocent won!@C")
            end_round()
        elseif t_num == #players then
            msg(Color(220,20,20).."Traitors won!@C")
            end_round()
        end
    elseif state == WAITING then
        local players = Player.table
        if #players > 1 then
            state = PREPARING
            msg(Color(220,20,220).."Next round in " .. TIME_NEXTROUND .. " seconds@C")
            clear_items()
            set_timer(5)
            Timer(TIME_NEXTROUND*1000, function()
                start_round()
            end)
        end
    end
end)

Hook('say', function(ply, message)
    if message == 'start' then
        start_round()
    end
    
    if message == 'team' then
        set_teams()
    end
    
    if message == 'hud' then
        draw_hud(ply)
    end
end)
