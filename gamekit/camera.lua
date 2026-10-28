-- Backend-agnostic 2D camera and viewport math.
local Camera = {}
local Camera2D = {}
Camera2D.__index = Camera2D
local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end
local function number(value, fallback) return value == nil and fallback or value end

function Camera.new(options)
    options = options or {}
    local self = setmetatable({
        x = number(options.x, 0), y = number(options.y, 0),
        zoom = number(options.zoom, 1), rotation = number(options.rotation, 0),
        viewport_x = number(options.viewport_x, 0), viewport_y = number(options.viewport_y, 0),
        viewport_w = number(options.viewport_w or options.width, 1280),
        viewport_h = number(options.viewport_h or options.height, 720),
        min_zoom = number(options.min_zoom, 0.05), max_zoom = number(options.max_zoom, 32),
    }, Camera2D)
    assert(self.zoom > 0 and self.min_zoom > 0 and self.max_zoom >= self.min_zoom, "camera zoom bounds must be positive")
    self.zoom = math.max(self.min_zoom, math.min(self.max_zoom, self.zoom))
    return self
end
function Camera2D:setPosition(x, y)
    assert(finite(x) and finite(y), "camera position must be finite")
    self.x, self.y = x, y
    return self
end
function Camera2D:move(dx, dy)
    assert(finite(dx) and finite(dy), "camera movement must be finite")
    self.x, self.y = self.x + dx, self.y + dy
    return self
end
function Camera2D:setZoom(zoom, screen_x, screen_y)
    assert(finite(zoom) and zoom > 0, "zoom must be a positive finite number")
    screen_x = screen_x or (self.viewport_x + self.viewport_w / 2)
    screen_y = screen_y or (self.viewport_y + self.viewport_h / 2)
    local before_x, before_y = self:screenToWorld(screen_x, screen_y)
    self.zoom = math.max(self.min_zoom, math.min(self.max_zoom, zoom))
    local after_x, after_y = self:screenToWorld(screen_x, screen_y)
    self.x, self.y = self.x + before_x - after_x, self.y + before_y - after_y
    return self
end
function Camera2D:zoomBy(factor, screen_x, screen_y)
    assert(finite(factor) and factor > 0, "zoom factor must be positive")
    return self:setZoom(self.zoom * factor, screen_x, screen_y)
end
function Camera2D:setRotation(radians)
    assert(finite(radians), "rotation must be finite")
    self.rotation = radians
    return self
end
function Camera2D:setViewport(x, y, width, height)
    assert(finite(x) and finite(y) and finite(width) and width > 0 and finite(height) and height > 0, "invalid viewport")
    self.viewport_x, self.viewport_y, self.viewport_w, self.viewport_h = x, y, width, height
    return self
end
function Camera2D:worldToScreen(x, y)
    local dx, dy = x - self.x, y - self.y
    local c, s = math.cos(self.rotation), math.sin(self.rotation)
    local rx, ry = dx * c - dy * s, dx * s + dy * c
    return self.viewport_x + self.viewport_w / 2 + rx * self.zoom,
        self.viewport_y + self.viewport_h / 2 + ry * self.zoom
end
function Camera2D:screenToWorld(x, y)
    local dx = (x - self.viewport_x - self.viewport_w / 2) / self.zoom
    local dy = (y - self.viewport_y - self.viewport_h / 2) / self.zoom
    local c, s = math.cos(self.rotation), math.sin(self.rotation)
    local rx, ry = dx * c + dy * s, -dx * s + dy * c
    return self.x + rx, self.y + ry
end
function Camera2D:containsScreenPoint(x, y)
    return x >= self.viewport_x and x <= self.viewport_x + self.viewport_w
        and y >= self.viewport_y and y <= self.viewport_y + self.viewport_h
end
function Camera2D:getVisibleWorldBounds()
    local x1, y1 = self:screenToWorld(self.viewport_x, self.viewport_y)
    local x2, y2 = self:screenToWorld(self.viewport_x + self.viewport_w, self.viewport_y)
    local x3, y3 = self:screenToWorld(self.viewport_x, self.viewport_y + self.viewport_h)
    local x4, y4 = self:screenToWorld(self.viewport_x + self.viewport_w, self.viewport_y + self.viewport_h)
    local minX, maxX = math.min(x1, x2, x3, x4), math.max(x1, x2, x3, x4)
    local minY, maxY = math.min(y1, y2, y3, y4), math.max(y1, y2, y3, y4)
    return minX, minY, maxX - minX, maxY - minY
end
function Camera2D:attachLove()
    assert(love and love.graphics, "Camera:attachLove requires LÖVE")
    love.graphics.push()
    love.graphics.translate(self.viewport_x + self.viewport_w / 2, self.viewport_y + self.viewport_h / 2)
    love.graphics.scale(self.zoom, self.zoom)
    love.graphics.rotate(self.rotation)
    love.graphics.translate(-self.x, -self.y)
    return self
end
function Camera2D:detachLove()
    assert(love and love.graphics, "Camera:detachLove requires LÖVE")
    love.graphics.pop()
    return self
end
Camera.Camera2D = Camera2D
return Camera
