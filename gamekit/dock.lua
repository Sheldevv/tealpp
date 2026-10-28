-- GameKit dockable panel manager. Rendering and input are backend-agnostic.
local Dock = {}
local Manager = {}
Manager.__index = Manager

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function inside(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end
local function copyColor(c) return {c[1], c[2], c[3], c[4] or 1} end

function Dock.new(options)
    options = options or {}
    local self = setmetatable({
        x = options.x or 0, y = options.y or 0,
        w = options.w or options.width or 1280, h = options.h or options.height or 720,
        header_height = options.header_height or 28,
        min_panel_width = options.min_panel_width or 140,
        min_panel_height = options.min_panel_height or 90,
        snap_distance = options.snap_distance or 18,
        theme = options.theme or {
            background = {0.09, 0.10, 0.14, 0.98}, surface = {0.15, 0.17, 0.22, 1},
            surface_hover = {0.22, 0.25, 0.32, 1}, border = {0.28, 0.30, 0.37, 1},
            foreground = {0.92, 0.93, 0.97, 1}, muted = {0.55, 0.58, 0.65, 1}, accent = {0.30, 0.58, 1, 1},
        },
        panels = {}, active = nil, operation = nil, offset_x = 0, offset_y = 0,
        mouse_x = 0, mouse_y = 0,
    }, Manager)
    return self
end

function Manager:add(id, options)
    assert(type(id) == "string" and id ~= "", "panel id must be a non-empty string")
    assert(not self.panels[id], "panel already exists: " .. id)
    options = options or {}
    local panel = {
        id = id, title = options.title or id,
        x = options.x or self.x + 40 + #self.panels * 24,
        y = options.y or self.y + 40 + #self.panels * 24,
        w = options.w or options.width or 320, h = options.h or options.height or 240,
        min_w = options.min_w or self.min_panel_width, min_h = options.min_h or self.min_panel_height,
        visible = options.visible ~= false, collapsed = options.collapsed == true,
        dock = options.dock or "float", content = options.content,
        onClose = options.onClose, onFocus = options.onFocus,
    }
    assert(finite(panel.w) and panel.w > 0 and finite(panel.h) and panel.h > 0, "panel size must be positive")
    self.panels[id] = panel
    self:layout()
    return panel
end

function Manager:get(id) return self.panels[id] end
function Manager:remove(id)
    local panel = self.panels[id]
    if not panel then return false end
    if panel.onClose then panel.onClose(panel) end
    self.panels[id] = nil
    if self.active == panel then self.active = nil; self.operation = nil end
    self:layout()
    return true
end
function Manager:setBounds(x, y, w, h)
    assert(finite(x) and finite(y) and finite(w) and w > 0 and finite(h) and h > 0, "invalid dock bounds")
    self.x, self.y, self.w, self.h = x, y, w, h
    self:layout()
    return self
end
function Manager:resize(w, h) return self:setBounds(self.x, self.y, w, h) end
function Manager:setDock(panelOrId, zone)
    local p = type(panelOrId) == "table" and panelOrId or self.panels[panelOrId]
    assert(p, "unknown panel")
    assert(zone == "float" or zone == "left" or zone == "right" or zone == "top" or zone == "bottom", "invalid dock zone")
    p.dock = zone
    self:layout()
    return self
end
function Manager:setVisible(panelOrId, visible)
    local p = type(panelOrId) == "table" and panelOrId or self.panels[panelOrId]
    assert(p, "unknown panel")
    p.visible = visible == true
    if not p.visible and self.active == p then self.active = nil; self.operation = nil end
    return self
end
function Manager:toggleCollapsed(panelOrId)
    local p = type(panelOrId) == "table" and panelOrId or self.panels[panelOrId]
    assert(p, "unknown panel")
    p.collapsed = not p.collapsed
    self:layout()
    return p.collapsed
end

function Manager:layout()
    local left, right, top, bottom = self.x, self.x + self.w, self.y, self.y + self.h
    -- Reserve edge-docked panels in insertion order; floating panels retain their bounds.
    for _, zone in ipairs({"left", "right", "top", "bottom"}) do
        for _, p in pairs(self.panels) do
            if p.visible and p.dock == zone then
                if zone == "left" then p.x, p.y, p.h = left, top, bottom - top; left = left + p.w
                elseif zone == "right" then p.x, p.y, p.h = right - p.w, top, bottom - top; right = right - p.w
                elseif zone == "top" then p.x, p.y, p.w = left, top, right - left; top = top + (p.collapsed and self.header_height or p.h)
                else p.x, p.y, p.w = left, bottom - (p.collapsed and self.header_height or p.h), right - left; bottom = bottom - (p.collapsed and self.header_height or p.h) end
            end
        end
    end
    for _, p in pairs(self.panels) do
        if p.content and p.content.setBounds then
            p.content:setBounds(p.x + 1, p.y + self.header_height, math.max(1, p.w - 2), math.max(1, p.h - self.header_height - 1))
        end
    end
    return self
end

function Manager:_panelAt(x, y)
    -- Most recently focused panel gets priority.
    if self.active and self.active.visible and inside(x, y, self.active) then return self.active end
    for _, p in pairs(self.panels) do if p.visible and inside(x, y, p) then return p end end
end
function Manager:mousepressed(x, y, button)
    self.mouse_x, self.mouse_y = x, y
    if button ~= 1 then return false end
    local p = self:_panelAt(x, y)
    if not p then return false end
    self.active = p
    if p.onFocus then p.onFocus(p) end
    if y <= p.y + self.header_height then
        if x >= p.x + p.w - self.header_height then
            self:toggleCollapsed(p)
            return true
        end
        self.operation = "drag"
        self.offset_x, self.offset_y = x - p.x, y - p.y
        return true
    elseif x >= p.x + p.w - 10 and y >= p.y + p.h - 10 and not p.collapsed then
        self.operation = "resize"
        self.offset_x, self.offset_y = p.x + p.w - x, p.y + p.h - y
        return true
    elseif p.content and p.content.mousepressed then
        p.content:mousepressed(x, y, button)
        return true
    end
    return true
end
function Manager:mousemoved(x, y, dx, dy)
    self.mouse_x, self.mouse_y = x, y
    local p = self.active
    if not p or not self.operation then
        for _, panel in pairs(self.panels) do if panel.content and panel.content.mousemoved then panel.content:mousemoved(x, y) end end
        return false
    end
    if self.operation == "drag" then
        p.x, p.y = x - self.offset_x, y - self.offset_y
        local d = self.snap_distance
        if math.abs(p.x - self.x) <= d then p.x = self.x end
        if math.abs(p.y - self.y) <= d then p.y = self.y end
        if math.abs((p.x + p.w) - (self.x + self.w)) <= d then p.x = self.x + self.w - p.w end
        if math.abs((p.y + p.h) - (self.y + self.h)) <= d then p.y = self.y + self.h - p.h end
    elseif self.operation == "resize" then
        p.w = math.max(p.min_w, x - p.x + self.offset_x)
        p.h = math.max(p.min_h, y - p.y + self.offset_y)
    end
    if p.content and p.content.setBounds then p.content:setBounds(p.x + 1, p.y + self.header_height, math.max(1, p.w - 2), math.max(1, p.h - self.header_height - 1)) end
    return true
end
function Manager:mousereleased(x, y, button)
    if button ~= 1 then return false end
    local was = self.operation ~= nil
    if not was and self.active and self.active.content and self.active.content.mousereleased then
        self.active.content:mousereleased(x, y, button)
    end
    self.operation = nil
    self:layout()
    return was
end
function Manager:wheelmoved(x, y)
    local p = self:_panelAt(self.mouse_x, self.mouse_y)
    if p and p.content and p.content.wheelmoved then p.content:wheelmoved(x, y); return true end
    return false
end
function Manager:handleTextInput(text)
    local p = self.active
    if p and p.content and p.content.handleTextInput then p.content:handleTextInput(text) end
end
function Manager:releaseAll()
    self.operation = nil
    for _, p in pairs(self.panels) do
        if p.content and p.content.releaseAll then p.content:releaseAll() end
    end
end
function Manager:keypressed(key)
    if key == "escape" then self.operation = nil; return end
    local p = self.active
    if p and p.content and p.content.keypressed then p.content:keypressed(key) end
end
function Manager:draw(renderer)
    assert(type(renderer) == "table" and type(renderer.rect) == "function" and type(renderer.text) == "function", "renderer.rect and renderer.text are required")
    local t = self.theme
    for _, p in pairs(self.panels) do
        if p.visible then
            local height = p.collapsed and self.header_height or p.h
            renderer:rect("fill", p.x, p.y, p.w, height, copyColor(t.background), 5)
            renderer:rect("line", p.x, p.y, p.w, height, copyColor(self.active == p and t.accent or t.border), 5)
            renderer:rect("fill", p.x + 1, p.y + 1, p.w - 2, self.header_height - 1, copyColor(self.active == p and t.surface_hover or t.surface), 4)
            renderer:text(p.title, p.x + 9, p.y + 6, copyColor(t.foreground))
            renderer:text(p.collapsed and "+" or "−", p.x + p.w - self.header_height + 8, p.y + 5, copyColor(t.muted))
            if not p.collapsed then
                if p.content and p.content.draw then p.content:draw(renderer)
                else renderer:rect("fill", p.x + 1, p.y + self.header_height, p.w - 2, p.h - self.header_height - 1, copyColor(t.surface), 0) end
                renderer:rect("line", p.x + p.w - 9, p.y + p.h - 9, 8, 8, copyColor(t.muted), 0)
            end
        end
    end
end

Dock.Manager = Manager
return Dock
