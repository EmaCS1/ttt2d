Hud = {}
Hud.x = 105
Hud.y = 425
Hud.timer = 0
Hud.timer_txt = Hudtxt(0, 1)
Hud.timer_color = Color(220, 220, 220)


local hud = {
    detectives={}
}

local hud_txt1 = Hudtxt(0, 1)
local hud_timer = 0

Hook('second', function()
    Hud.timer = math.max(Hud.timer-1, 0)
    Hud.update_timer()
end)

function Hud.set_timer(value)
    Hud.timer = math.max(value, 0)
end

function Hud.update_timer()
    local min = math.floor(Hud.timer/60)
    local sec = Hud.timer % 60
    local str = Hud.timer_color .. string.format("%01d:%02d", min, sec)
    
    Hud.timer_txt:show(str, Hud.x+20, Hud.y-3, 0)
end

function Hud.draw_base(ply)
    if ply.bot then return end
    
    if ply.hud.base then
        ply.hud.base:remove()
    end
    
    ply.hud.base = Image('gfx/ttt_dev/base.png', Hud.x, Hud.y, 2, ply.id)
end

function Hud.draw_role(ply)
    if ply.bot then return end
    
    if ply.hud.team then
        ply.hud.team:remove()
    end
    
    local path = ''
    if ply.role == INNOCENT then
        path = 'gfx/ttt_dev/innocent.png'
    elseif ply.role == PREPARING then
        path = 'gfx/ttt_dev/preparing.png'
    elseif ply.role == TRAITOR then
        path = 'gfx/ttt_dev/traitor.png'
    elseif ply.role == DETECTIVE then
        path = 'gfx/ttt_dev/detective.png'
    else
        path = 'gfx/ttt_dev/spectator.png'
    end
    
    ply.hud.team = Image(path, Hud.x, Hud.y, 2, ply.id)
end

function Hud.draw_health(ply)
    if ply.bot then return end
    
    if not ply.hud.health then
        ply.hud.health = Image('gfx/ttt_dev/health.png', Hud.x, Hud.y, 2, ply.id)
        ply.hud.health:color(20, 170, 50)
    end
     
    local speed = 300
    local scale = ply.health / ply.maxhealth
    local red = 100 * (1-scale) + 20
    local green = 120 * scale + 50
    local blue = 50
    
    ply.hud.health:t_scale(speed, scale, 1)
    ply.hud.health:t_move(speed, Hud.x-100 + scale*100, Hud.y)
    ply.hud.health:t_color(speed, red, green, blue)
end

function Hud.mark_traitors(ply) 
    if ply.bot then return end
    if ply.hud.traitors then
        clear_traitors(ply) 
    end
    
    ply.hud.traitors = {}
    
    local players = Player.tableliving
    for _,v in pairs(players) do
        if v.role and v.role == TRAITOR then
            local img = Image('gfx/shadow.bmp<a>', 2, 0, v.id + 100, ply.id)
            img:scale(1.5, 1.5)
            img:color(220, 20, 20)
            table.insert(ply.hud.traitors, img)
        end
    end
end

function Hud.clear_traitor_marks(ply)
    if ply.bot then return end
    if ply.hud.traitors then
        for k,v in pairs(ply.hud.traitors) do
            v:remove()
        end
        ply.hud.traitors = nil
    end
end

function Hud.mark_detectives()
    local players = Player.tableliving
    for _,v in pairs(players) do
        if v.role and v.role == DETECTIVE then
            local img = Image('gfx/shadow.bmp<a>', 2, 0, v.id + 100)
            img:scale(1.5, 1.5)
            img:color(60, 60, 220)
            table.insert(hud.detectives, img)
        end
    end
end

function Hud.clear_detective_marks()
    for k,v in pairs(hud.detectives) do
        v:remove()
    end
end

function Hud.clear_marks()
    Hud.clear_detective_marks()
    
    local players = Player.table
    for _,ply in pairs(players) do
        Hud.clear_traitor_marks(ply)
    end
end

function Hud.draw(ply)
    Hud.draw_base(ply)
    Hud.draw_role(ply)
    Hud.draw_health(ply)
end
