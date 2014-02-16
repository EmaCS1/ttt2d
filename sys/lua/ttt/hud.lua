Hud = {}
Hud.x = 105
Hud.y = 425
Hud.clock = Hudtxt(0, 1)

-- {{{ Clock
function Hud.update_clock()
    local time = 120 - (os.time() - TTT.round_started)
    local str = "0:00"

    if time > 0 then
        local min = math.floor(time/60)
        local sec = time % 60
        str = string.format("%01d:%02d", min, sec)
    end

    Hud.clock:show(Color.white..str, Hud.x+20, Hud.y-3, 0)
end
-- }}}

-- {{{ Base
function Hud.draw_base()
    Hud.base = Image("gfx/ttt_dev/base.png", Hud.x, Hud.y, 2)
end

Hud.draw_base()
-- }}}

-- {{{ Health
function Hud.draw_hp(p)
    local hp = Image("gfx/ttt_dev/health.png", Hud.x-100, Hud.y, 2, p.id)
    hp:color(20, 170, 50)
    hp:scale(0, 1)
    p.hud.hp = hp
end

function Hud.update_hp(p)
    if not p.hud.hp then
        return
    end
    local speed = 350
    local scale = p.health / p.maxhealth

    local r = 100 * (1-scale) + 20
    local g = 120 * scale + 50
    local b = 50

    local hp = p.hud.hp
    hp:t_scale(speed, scale, 1)
    hp:t_move(speed, Hud.x-100 + scale*100, Hud.y)
    hp:t_color(speed, r, g, b)
end

function Hud.flash(p)
    local img = Image("gfx/block.bmp", 320, 240, 2, p.id)
    img:scale(20, 20)
    img:color(250,0,0)
    img:alpha(0.5)
    img:t_alpha(200, 0)

    Timer(200, function()
        img:remove()
    end)
end
-- }}}

-- {{{ Role
function Hud.draw_role(p)
    if p.hud.role then
        p.hud.role:remove()
    end

    local path = "gfx/ttt_dev/spectator.png"

    if p:is_innocent() then
        path = "gfx/ttt_dev/innocent.png"
    elseif p:is_preparing() then
        path = "gfx/ttt_dev/preparing.png"
    elseif p:is_traitor() then
        path = "gfx/ttt_dev/traitor.png"
    elseif p:is_detective() then
        path = "gfx/ttt_dev/detective.png"
    elseif p:is_mia() then
        path = "gfx/ttt_dev/mia.png"
    end

    Timer(1, function()
        p.hud.role = Image(path, Hud.x, Hud.y, 2, p.id)
    end)
end
-- }}}

-- {{{ Shadows
function Hud.mark_players()
    Player.each(function(p)
        if p:is_detective() then
            local img = Image("gfx/shadow.bmp<a>", 2, 0, p.id+100)
            img:scale(1.8, 1.8)
            img:color(50, 50, 250)

        elseif p:is_traitor() then
            for _,p2 in pairs(TTT.traitors) do
                local img = Image("gfx/shadow.bmp<a>", 2, 0, p.id+100, p2.id)
                img:scale(1.8, 1.8)
                img:color(250, 50, 50)
            end
        end
    end)
end
-- }}}

-- {{{ Hooks
Hook("second", Hud.update_clock)

Hook("leave", function(p)
    p.hud = {}
end)

Hook("startround", function()
    Hud.draw_base()

    Player.each(Hud.draw_hp)
end)

Hook("join", function(p)
    if not p.hud then
        p.hud = {}
    end

    Timer(1, function()
        Hud.draw_hp(p)
    end)
end, -100)

Hook("spawn", function(p)
    Timer(1, function()
        Hud.update_hp(p)
    end)
end, -100)

Hook("hit", function(p)
    local hp = p.health

    Timer(1, function()
        local diff = p.health-hp

        Hud.update_hp(p)

        if diff < 0 then
            Hud.flash(p)
        end
    end)
end, -100)

Hook("die", function(p)
    Timer(1, function()
        Hud.update_hp(p)
    end)
end, -100)
-- }}}
