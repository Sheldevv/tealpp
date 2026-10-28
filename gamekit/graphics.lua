-- gamekit/graphics.lua
-- Convenience wrapper over love.graphics.
-- Colors accept "#rrggbb", "#rrggbbaa", or { r, g, b, a? } in 0..1.

local G = {}

local function c(col)
    if type(col) == "table" then return col end
    if type(col) == "string" then
        local h = col:gsub("^#", "")
        if #h == 6 then
            return { tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255, 1 }
        elseif #h == 8 then
            return { tonumber(h:sub(1,2),16)/255, tonumber(h:sub(3,4),16)/255, tonumber(h:sub(5,6),16)/255, tonumber(h:sub(7,8),16)/255 }
        end
    end
    error("GameKit.graphics: invalid color " .. tostring(col))
end

local function applyColor(col)
    if col == nil then return end
    local t = c(col)
    love.graphics.setColor(t[1], t[2], t[3], t[4] or 1)
end

function G.setColor(col) applyColor(col) end

function G.clear(col)
    local t = c(col or {0, 0, 0, 1})
    love.graphics.clear(t[1], t[2], t[3], t[4] or 1)
end

function G.circle(mode, x, y, r, col, seg)
    applyColor(col); love.graphics.circle(mode, x, y, r, seg)
end

function G.rectangle(mode, x, y, w, h, col)
    applyColor(col); love.graphics.rectangle(mode, x, y, w, h)
end

function G.line(x1, y1, x2, y2, col)
    applyColor(col); love.graphics.line(x1, y1, x2, y2)
end

function G.print(text, x, y, col)
    applyColor(col); love.graphics.print(tostring(text), x or 0, y or 0)
end

function G.getDimensions() return love.graphics.getDimensions() end
function G.push() love.graphics.push() end
function G.pop() love.graphics.pop() end
function G.translate(x, y) love.graphics.translate(x, y) end
function G.scale(sx, sy) love.graphics.scale(sx, sy) end
function G.rotate(r) love.graphics.rotate(r) end
function G.raw() return love.graphics end

-- Extended helpers
function G.setFont(font) love.graphics.setFont(font) end
function G.setLineWidth(w) love.graphics.setLineWidth(w) end

function G.image(img, x, y, r, sx, sy)
    if not img then return end
    love.graphics.draw(img, x, y, r or 0, sx or 1, sy or sx or 1)
end

function G.polygon(mode, col, ...)
    applyColor(col); love.graphics.polygon(mode, ...)
end

function G.ellipse(mode, x, y, rx, ry, col, seg)
    applyColor(col); love.graphics.ellipse(mode, x, y, rx, ry, seg)
end

function G.arc(mode, x, y, r, a1, a2, col, seg)
    applyColor(col); love.graphics.arc(mode, x, y, r, a1, a2, seg)
end

function G.reset()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return G
