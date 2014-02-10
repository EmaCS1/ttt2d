local image = image
local addhook = addhook

Image = {}
Image.mt = {}
Image.alive = {}

setmetatable(Image, {
    __call = function(_, ...)
        local img = image(unpack({...}))
        local o = setmetatable({id = img, exists = true}, Image.mt)

        Image.alive[img] = o
        return o
    end,
    __index = function(_, key)
        local m = rawget(Image, key)
        if m then return m end

        return rawget(Image.mt, key)
    end
})

-- Clear image objects
addhook("startround_prespawn", "Image.hook")
Image.hook = function()
    for _,img in pairs(Image.alive) do
        img.exists = false
        img.id = -1
    end

    Image.alive = {}
end

local transform = {
    alpha = 'imagealpha',
    blend = 'imageblend',
    color = 'imagecolor',
    hitzone = 'imagehitzone',
    pos = 'imagepos',
    scale = 'imagescale',
    t_alpha = 'tween_alpha',
    t_color = 'tween_color',
    t_move = 'tween_move',
    t_rotate = 'tween_rotate',
    t_rotateconstantly = 'tween_rotateconstantly',
    t_scale = 'tween_scale'
}

for k,v in pairs(transform) do  -- generate methods from transform table
    Image.mt[k] = function(self, ...)
        if self.exists then
            _G[v](self.id, unpack({...}))
        end
    end
end

function Image.mt:remove()
    if self.exists then
        freeimage(self.id)
        Image.alive[self.id] = nil
        self.exists = false
    end
end

function Image.mt:__index(key)
    local m = rawget(Image.mt, key)
    if m then
        return m
    else
        error("Unknown method " .. key)
    end
end

function Image.mt.__eq(a, b)
    if a.id and b.id then
        return a.id == b.id
    else
        return false
    end
end
