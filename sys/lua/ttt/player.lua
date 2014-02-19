-- {{{ Set role
function Player.mt:set_role(role)
    self.role = role
    Hud.draw_role(self)
end

function Player.mt:set_preparing()
    self:set_role(R_PREPARING)
    self.body = nil
    self.info = nil

    if self.team ~= 1 then
        self:set_team(1)
    end
end

function Player.mt:set_innocent()
    self:set_role(R_INNOCENT)

    if self.team ~= 1 then
        self:set_team(1)
    end
end

function Player.mt:set_traitor()
    self:set_role(R_TRAITOR)

    if self.team ~= 1 then
        self:set_team(1)
    end

    Hud.draw_role(self)

    Timer(3000, function()
        self:notify("Press F2 to access Traitor Shop!")
    end)
end

function Player.mt:set_detective()
    self:set_role(R_DETECTIVE)

    if self.team ~= 1 then
        self:set_team(1)
    end

    Hud.draw_role(self)

    Timer(3000, function()
        self:notify("Press F2 to access Detective Shop!")
    end)
end

function Player.mt:set_spectator()
    self:set_role(R_SPECTATOR)

    if self.team ~= 0 then
        self:set_team(0)
    end

    Hud.draw_role(self)
end

function Player.mt:set_mia(killer)
    if type(killer) ~= "table" then
        killer = self
    end

    if self.weapon and self.weapon ~= 50 then
        Parse("spawnitem", self.weapon, self.tilex, self.tiley)
    end

    self.info = {
        time = os.time(),
        found = false,

        x = self.x,
        y = self.y,

        name = self.name,
        cname = self:c_name(),
        role = self.role,
        color = self:get_color(),

        killer = killer,
        killer_x = killer.x,
        killer_y = killer.y,
        killer_name = killer.name,
        killer_cname = killer:c_name(),
        killer_role = killer.role,
        killer_wpn = killer.weapon
    }

    self:spawn_body(killer)
    self.role = R_MIA

    self:move_to_vip()

    Hud.draw_role(self)
end
-- }}}

-- {{{ Is role
function Player.mt:is_preparing()
    return self.role == R_PREPARING
end

function Player.mt:is_innocent()
    return self.role == R_INNOCENT
end

function Player.mt:is_traitor()
    return self.role == R_TRAITOR
end

function Player.mt:is_detective()
    return self.role == R_DETECTIVE
end

function Player.mt:is_mia()
    return self.role == R_MIA
end

function Player.mt:is_spectator()
    return self.role == R_SPECTATOR
end
-- }}}

-- {{{ Common functions
function Player.mt:get_color()
    return TTT.get_color(self.role)
end

function Player.mt:c_name()
    return self:get_color() .. self.name
end

function Player.mt:set_team(value)
    Timer(1, function()
        self.change_team = true
        self.team = value
        self.change_team = false
    end)
end

function Player.mt:notify(message)
    self:msg(Color(120,220,120) .. message)
end

function Player.mt:remove_body()
    if not self.body then
        return
    end

    local body = self.body
    body:t_alpha(2000, 0)
    Timer(2000, function()
        body:remove()
    end)

    self.body = nil
end

function Player.mt:spawn_body(killer)
    local body = Image("gfx/ttt_dev/body.png", self.x, self.y, 0)
    body:pos(self.x, self.y, killer.rot)
    body:alpha(0)
    body:t_alpha(2000, 0.5)

    self.body = body
end

function Player.mt:move_to_game()
    local tilex, tiley = randomentity(1)

    self:spawn(tilex*32+16, tiley*32+16)
end

function Player.mt:move_to_vip()
    local tilex, tiley = randomentity(2)

    self:spawn(tilex*32+16, tiley*32+16)
    self.health = 100
    self.weapons = {50}

    self:notify("You are currently Missing-in-Action (MIA)!@C")
end
-- }}}

-- {{{ Data handling
function Player.mt:reset_data()
    self.savetime = os.time()

    for key,v in pairs(Player.save_table) do
        self[key] = v[2]
    end
end

Player.save_table = {
    karma = {"number", 1000},
    playtime = {"number", 0},
    points = {"number", 0},
    points_used = {"number", 0},
    rank = {"number", 0},
    topkarma = {"number", 1000},
    bans = {"number", 0},
    teamkills = {"number", 0}
}

function Player.mt:save_data()
    if self.usgn == 0 then
        return
    end

    local timenow = os.time()
    self.playtime = self.playtime + (timenow - self.savetime)
    self.savetime = timenow

    if self.karma > self.topkarma then
        self.topkarma = self.karma
    end

    local f = File('sys/lua/ttt/saves/' .. self.usgn .. '.txt')

    local tbl = {}
    for key,v in pairs(Player.save_table) do
        local value = self[key]
        if value and type(value) == v[1] then
            tbl[key] = value
        else
            print("Failed to save " .. key .. " for player " .. self.id .. ", using default value")
            tbl[key] = v[2]
        end
    end

    f:write(tbl)
end

function Player.mt:load_data()
    print("Load player data " .. self.usgn)
    if self.usgn == 0 then
        self.karma = Karma.player_base
        Timer(3000, function()
            self:notify("Please login usgn to enjoy full karma bonuses!@C")
        end)
        return
    end

    self.savetime = os.time()

    local f = File('sys/lua/ttt/saves/' .. self.usgn .. '.txt')
    local data = f:read()

    if type(data) ~= 'table' then
        Timer(3000, function()
            self:msg(Color.white .. "Welcome to the server ".. Color.innocent .. self.name .. Color.white .. "!@C")
        end)
        Timer(5000, function()
            self:msg(Color.white .. "If you are new to this gamemode please read " .. Color.traitor .. "F1!@C")
        end)
        return
    end

    for k,v in pairs(data) do
        if not Player.save_table[k] then
            print("Loaded unused data " .. k .. " for player " .. self.id .. ", skipping")
        elseif type(v) ~= Player.save_table[k][1] then
            print("Loaded data in wrong type for player " .. self.id ..": " .. Player.save_table[k][1] .. " expected but got " .. type(v))
            self[k] = Player.save_table[k][2]
        else
            self[k] = v
        end
    end

    if self.karma < Karma.reset then
        self.karma = Karma.reset
        Timer(5000, function()
            self:msg(Color.traitor .. "Karma reset! Please don't let your karma drop next time!@C")
        end)
    end

    Timer(3000, function()
        self:msg(Color.white .. "Welcome back " .. Color.innocent .. self.name .. Color.white ..  "!@C")
    end)
end
-- }}}
