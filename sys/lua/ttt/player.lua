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
    self:equip(1)

    Hud.draw_role(self)
end

function Player.mt:set_detective()
    self:set_role(R_DETECTIVE)
    self:equip(79)

    if self.team ~= 1 then
        self:set_team(1)
    end

    Hud.draw_role(self)
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
    self.change_team = true
    self.team = value
    self.change_team = false
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
    self.karma = Karma.base
    self.playtime = 0
    self.savetime = os.time()
    self.points = 0
end

function Player.mt:save_data()
    if self.usgn == 0 then
        return
    end

    local timenow = os.time()
    self.playtime = self.playtime + (timenow - self.savetime)
    self.savetime = timenow

    local f = File('sys/lua/ttt/saves/' .. self.usgn .. '.txt')
    f:write({
        karma = self.karma,
        playtime = self.playtime,
        points = self.points
    })
end

function Player.mt:load_data()
    if self.usgn == 0 then
        self.karma = Karma.player_base
        return
    end

    self.savetime = os.time()

    local f = File('sys/lua/ttt/saves/' .. self.usgn .. '.txt')
    local data = f:read()

    if type(data) ~= 'table' then
        return
    end

    for k,v in pairs(data) do
        self[k] = v
    end

    if self.karma < Karma.reset then
        self.karma = Karma.reset
    end

    Timer(3000, function()
        self:notify("Welcome back, " .. self.name .. "!@C")
    end)
end
-- }}}
