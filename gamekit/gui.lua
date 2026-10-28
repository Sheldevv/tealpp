
local GUI = {}

local UI = {}
UI.__index = UI

local function finite(n)
    return type(n) == "number"
        and n == n
        and n ~= math.huge
        and n ~= -math.huge
end

local function colorCopy(c)
    return {c[1], c[2], c[3], c[4] or 1}
end

local function inside(w, x, y)
    return x >= w.x and x <= w.x + w.w
        and y >= w.y and y <= w.y + w.h
end

local function merge(base, override)
    local result = {}
    for k, v in pairs(base) do result[k] = v end
    for k, v in pairs(override or {}) do result[k] = v end
    return result
end

local DEFAULTS = {
    background = {0.10, 0.11, 0.15, 0.98},
    foreground = {0.92, 0.93, 0.97, 1},
    muted = {0.55, 0.58, 0.65, 1},
    accent = {0.30, 0.58, 1, 1},
    border = {0.28, 0.30, 0.37, 1},
    surface = {0.15, 0.17, 0.22, 1},
    surface_hover = {0.22, 0.25, 0.32, 1},
    surface_pressed = {0.12, 0.14, 0.19, 1},
    disabled = {0.34, 0.35, 0.40, 1},
    track = {0.23, 0.25, 0.31, 1},
    radius = 6,
}

function GUI.new(options)
    options = options or {}

    local theme = merge(DEFAULTS, options.theme)

    local ui = setmetatable({
        x = options.x or 0,
        y = options.y or 0,
        w = options.w or options.width or 320,
        h = 0,
        fixed_height = options.height,
        padding = options.padding or 12,
        spacing = options.spacing or 8,
        direction = options.direction or "vertical",
        align = options.align or "stretch",
        responsive = options.responsive == true,
        right_margin = options.right_margin or 0,
        min_width = options.min_width or 160,
        max_width = options.max_width or math.huge,
        viewport_w = options.w or options.width or 320,
        viewport_h = options.height or 0,
        widgets = {},
        theme = theme,

        mouse_x = 0,
        mouse_y = 0,
        mouse_down = false,
        hovered_widget = nil,
        pressed_widget = nil,
        focused_widget = nil,
        focus_index = 0,
        tooltip_delay = options.tooltip_delay or 0.55,
        hover_time = 0,
    }, UI)

    ui:layout()
    return ui
end

function UI:add(widget)
    assert(type(widget) == "table", "widget must be a table")

    widget.height = widget.height or 28
    widget.enabled = widget.enabled ~= false
    widget.hovered = false
    widget.pressed = false

    assert(finite(widget.height) and widget.height > 0,
        "widget height must be a positive finite number")

    self.widgets[#self.widgets + 1] = widget
    self:layout()
    return widget
end

function UI:label(text, options)
    options = options or {}
    return self:add({
        type = "label",
        text = tostring(text or ""),
        height = options.height or 24,
        color = options.color,
        width = options.width,
    })
end

function UI:separator(options)
    options = options or {}
    return self:add({
        type = "separator",
        height = options.height or 10,
        color = options.color,
        width = options.width,
    })
end

function UI:button(text, callback, options)
    options = options or {}
    return self:add({
        type = "button",
        text = tostring(text or ""),
        callback = callback,
        height = options.height or 34,
        width = options.width,
        enabled = options.enabled,
        background = options.background,
        foreground = options.foreground,
        radius = options.radius,
    })
end

function UI:checkbox(text, checked, callback, options)
    options = options or {}
    return self:add({
        type = "checkbox",
        text = tostring(text or ""),
        checked = checked == true,
        callback = callback,
        height = options.height or 30,
        width = options.width,
        enabled = options.enabled,
        color = options.color,
    })
end

function UI:textinput(text, callback, options)
    options = options or {}
    return self:add({
        type = "textinput",
        text = tostring(text or ""),
        placeholder = options.placeholder or "",
        callback = callback,
        height = options.height or 34,
        width = options.width,
        enabled = options.enabled,
        max_length = options.max_length or 256,
        background = options.background,
        foreground = options.foreground,
    })
end

function UI:radio(text, selected, callback, options)
    options = options or {}
    return self:add({
        type = "radio", text = tostring(text or ""),
        selected = selected == true, callback = callback,
        height = options.height or 30, width = options.width,
        enabled = options.enabled, color = options.color,
        group = options.group,
    })
end

function UI:dropdown(options)
    options = options or {}
    local items = options.items or {}
    assert(type(items) == "table", "dropdown items must be a table")
    local selected = options.selected or 1
    if #items > 0 then selected = math.max(1, math.min(#items, selected)) else selected = 0 end
    return self:add({
        type = "dropdown", items = items, selected = selected,
        callback = options.callback, height = options.height or 34,
        width = options.width, enabled = options.enabled,
        placeholder = options.placeholder or "Select...",
        open = false, option_height = options.option_height or 28,
        max_visible = options.max_visible or 6,
    })
end

function UI:setTheme(theme)
    self.theme = merge(self.theme, theme or {})
    for _, widget in ipairs(self.widgets) do
        if widget.type == "container" then widget.ui:setTheme(theme) end
    end
    return self
end

function UI:getTheme()
    return merge(self.theme, {})
end

function UI:setTooltip(widget, text, delay)
    assert(type(widget) == "table", "widget must be a table")
    widget.tooltip = text and tostring(text) or nil
    if delay ~= nil then
        assert(finite(delay) and delay >= 0, "tooltip delay must be non-negative")
        widget.tooltip_delay = delay
    end
    return self
end

function UI:container(options)
    options = options or {}
    local width = options.width or math.max(1, self.w - self.padding * 2)
    local child = GUI.new({
        x = 0,
        y = 0,
        w = width,
        padding = options.padding or 8,
        spacing = options.spacing or self.spacing,
        direction = options.direction or "vertical",
        align = options.align or "stretch",
        theme = options.theme or self.theme,
    })

    local widget = self:add({
        type = "container",
        ui = child,
        height = options.height or 160,
        width = options.width,
        background = options.background,
        border = options.border,
        scrollable = options.scrollable == true,
        scroll_y = 0,
    })
    child.w = widget.w
    child:layout()
    return child
end

function UI:slider(value, min, max, callback, options)
    options = options or {}
    min = min or 0
    max = max or 1
    value = value or min

    assert(finite(min) and finite(max) and max > min,
        "slider requires finite min and max, with max > min")
    assert(finite(value), "slider value must be a finite number")

    value = math.max(min, math.min(max, value))

    return self:add({
        type = "slider",
        value = value,
        min = min,
        max = max,
        step = options.step,
        callback = callback,
        height = options.height or 38,
        width = options.width,
        enabled = options.enabled,
        label = options.label,
        color = options.color,
    })
end

function UI:progressbar(value, options)
    options = options or {}
    value = value or 0

    assert(finite(value), "progress value must be a finite number")

    return self:add({
        type = "progressbar",
        value = math.max(0, math.min(1, value)),
        height = options.height or 14,
        width = options.width,
        color = options.color,
        track_color = options.track_color,
    })
end

function UI:setProgress(widget, value)
    assert(widget.type == "progressbar", "widget must be a progress bar")
    assert(finite(value), "progress must be a finite number")
    widget.value = math.max(0, math.min(1, value))
    return self
end

function UI:setValue(widget, value, silent)
    assert(type(widget) == "table", "widget must be a table")

    if widget.type == "slider" then
        assert(finite(value), "slider value must be a finite number")
        value = math.max(widget.min, math.min(widget.max, value))

        if widget.step and widget.step > 0 then
            value = widget.min
                + math.floor((value - widget.min) / widget.step + 0.5)
                * widget.step
            value = math.max(widget.min, math.min(widget.max, value))
        end

        local changed = value ~= widget.value
        widget.value = value

        if changed and not silent and widget.callback then
            widget.callback(value)
        end
    elseif widget.type == "textinput" then
        value = tostring(value or "")
        value = value:sub(1, widget.max_length)
        local changed = value ~= widget.text
        widget.text = value

        if changed and not silent and widget.callback then
            widget.callback(value)
        end
    elseif widget.type == "progressbar" then
        self:setProgress(widget, value)
    elseif widget.type == "dropdown" then
        assert(type(value) == "number" and value % 1 == 0, "dropdown selection must be an integer")
        value = #widget.items == 0 and 0 or math.max(1, math.min(#widget.items, value))
        local changed = value ~= widget.selected
        widget.selected = value
        if changed and not silent and widget.callback then widget.callback(value, widget.items[value]) end
    elseif widget.type == "radio" then
        value = value == true
        local changed = value ~= widget.selected
        if value and widget.group then
            for _, other in ipairs(self.widgets) do
                if other.type == "radio" and other.group == widget.group and other ~= widget then
                    other.selected = false
                end
            end
        end
        widget.selected = value
        if changed and not silent and widget.callback then widget.callback(value) end
    elseif widget.type == "checkbox" then
        value = value == true
        local changed = value ~= widget.checked
        widget.checked = value

        if changed and not silent and widget.callback then
            widget.callback(value)
        end
    else
        error("setValue is not supported for widget type " .. tostring(widget.type))
    end

    return self
end

function UI:setEnabled(widget, enabled)
    assert(type(widget) == "table", "widget must be a table")
    widget.enabled = enabled == true

    if not widget.enabled then
        widget.hovered = false
        widget.pressed = false
        if widget.type == "dropdown" then widget.open = false end

        if self.hovered_widget == widget then
            self.hovered_widget = nil
        end
        if self.pressed_widget == widget then
            self.pressed_widget = nil
        end
        if self.focused_widget == widget then
            self.focused_widget = nil
        end
    end

    return self
end

function UI:layout()
    local inner_width = math.max(1, self.w - self.padding * 2)
    local x = self.x + self.padding
    local y = self.y + self.padding
    local content_height = 0
    local max_widget_height = 0
    local auto_width_count = 0
    local explicit_width = 0

    if self.direction ~= "vertical" and self.direction ~= "horizontal" then
        error("layout direction must be 'vertical' or 'horizontal'")
    end

    if self.direction == "horizontal" then
        for _, widget in ipairs(self.widgets) do
            if widget.width then
                explicit_width = explicit_width + widget.width
            else
                auto_width_count = auto_width_count + 1
            end
        end
        local gaps = math.max(0, #self.widgets - 1) * self.spacing
        local auto_width = auto_width_count > 0
            and math.max(1, (inner_width - explicit_width - gaps) / auto_width_count)
            or 0

        for _, widget in ipairs(self.widgets) do
            widget.x = x
            widget.y = y
            widget.w = widget.width or auto_width
            widget.h = widget.height
            x = x + widget.w + self.spacing
            content_height = math.max(content_height, widget.h)
            max_widget_height = math.max(max_widget_height, widget.h)
            if widget.type == "container" then
                widget.ui.x = widget.x
                widget.ui.y = widget.y - (widget.scroll_y or 0)
                widget.ui.w = math.max(1, widget.w)
                widget.ui:layout()
            end
        end
        content_height = max_widget_height
    else
        for _, widget in ipairs(self.widgets) do
            local requested_width = widget.width
            local align = widget.align or self.align
            if not requested_width and align ~= "stretch" then
                requested_width = widget.preferred_width or math.min(inner_width, 180)
            end
            widget.w = math.max(1, requested_width or inner_width)
            if align == "center" then
                widget.x = self.x + (self.w - widget.w) / 2
            elseif align == "end" then
                widget.x = self.x + self.w - self.padding - widget.w
            else
                widget.x = self.x + self.padding
            end
            widget.y = y
            widget.h = widget.height
            y = y + widget.h + self.spacing
            content_height = content_height + widget.h
            if widget.type == "container" then
                widget.ui.x = widget.x
                widget.ui.y = widget.y - (widget.scroll_y or 0)
                widget.ui.w = math.max(1, widget.w)
                widget.ui:layout()
            end
        end
    end

    if #self.widgets > 0 then
        content_height = content_height + math.max(0, #self.widgets - 1) * self.spacing
    end

    self.content_h = content_height + self.padding * 2
    self.h = self.fixed_height or self.content_h
    self.viewport_w = self.w
    self.viewport_h = self.h

    return self
end

function UI:setBounds(x, y, width, height)
    assert(finite(x) and finite(y), "bounds x and y must be finite numbers")
    assert(finite(width) and width > 0, "bounds width must be a positive finite number")
    if height ~= nil then
        assert(finite(height) and height > 0, "bounds height must be a positive finite number")
    end
    self.x, self.y, self.w = x, y, width
    self.fixed_height = height
    self:layout()
    return self
end

function UI:resize(width, height)
    assert(finite(width) and width > 0, "window width must be a positive finite number")
    assert(finite(height) and height > 0, "window height must be a positive finite number")
    self.viewport_w, self.viewport_h = width, height
    if self.responsive then
        self.w = math.max(self.min_width,
            math.min(self.max_width, width - self.x - self.right_margin))
    end
    self:layout()
    for _, widget in ipairs(self.widgets) do
        if widget.type == "container" then
            widget.ui:resize(widget.w, widget.h)
        end
    end
    return self
end

function UI:wheelmoved(x, y)
    for _, widget in ipairs(self.widgets) do
        if widget.type == "container" and inside(widget, self.mouse_x, self.mouse_y) then
            if widget.scrollable then
                local max_scroll = math.max(0, (widget.ui.content_h or widget.ui.h) - widget.h)
                widget.scroll_y = math.max(0, math.min(max_scroll, widget.scroll_y - y * 28))
                widget.ui.y = widget.y - widget.scroll_y
                widget.ui:layout()
            end
            widget.ui:wheelmoved(x, y)
        end
    end
end

function UI:update(dt)
    if finite(dt) and dt > 0 and self.hovered_widget then
        self.hover_time = self.hover_time + dt
    else
        self.hover_time = 0
    end
    for _, widget in ipairs(self.widgets) do
        if widget.type == "container" then widget.ui:update(dt) end
    end
end

function UI:mousemoved(x, y)
    if not finite(x) or not finite(y) then return end

    self.mouse_x, self.mouse_y = x, y
    local old_hovered = self.hovered_widget
    self.hovered_widget = nil

    for _, widget in ipairs(self.widgets) do
        widget.hovered = widget.enabled and inside(widget, x, y)

        if widget.hovered then
            self.hovered_widget = widget
        end

        widget.pressed = self.pressed_widget == widget
            and self.mouse_down
            and inside(widget, x, y)
            and widget.enabled
    end

    if old_hovered ~= self.hovered_widget then self.hover_time = 0 end
    for _, item in ipairs(self.widgets) do
        if item.type == "container" then item.ui:mousemoved(x, y) end
        if item.type == "dropdown" and item.open then
            local count = math.min(#item.items, item.max_visible)
            local menuY = item.y + item.h
            if x >= item.x and x <= item.x + item.w and y >= menuY and y <= menuY + count * item.option_height then
                item.option_hover = math.floor((y - menuY) / item.option_height) + 1
            else
                item.option_hover = nil
            end
        end
    end

    local widget = self.pressed_widget
    if self.mouse_down and widget and widget.enabled
        and widget.type == "slider" then
        self:_updateSlider(widget, x)
    end
end

function UI:_updateSlider(widget, x)
    local ratio = math.max(0, math.min(1,
        (x - widget.x) / widget.w))
    local value = widget.min + ratio * (widget.max - widget.min)

    if widget.step and widget.step > 0 then
        value = widget.min
            + math.floor((value - widget.min) / widget.step + 0.5)
            * widget.step
    end

    value = math.max(widget.min, math.min(widget.max, value))

    if value ~= widget.value then
        widget.value = value
        if widget.callback then widget.callback(value) end
    end
end

function UI:mousepressed(x, y, button)
    if button ~= 1 then return end

    self:mousemoved(x, y)
    self.mouse_down = true
    self.pressed_widget = nil

    for _, widget in ipairs(self.widgets) do
        widget.pressed = false
    end

    -- An open dropdown owns clicks on its popup options, even though the popup
    -- extends beyond the widget's normal bounds.
    for _, item in ipairs(self.widgets) do
        if item.type == "dropdown" and item.open then
            local count = math.min(#item.items, item.max_visible)
            if x >= item.x and x <= item.x + item.w and y >= item.y + item.h
                and y <= item.y + item.h + count * item.option_height then
                local index = math.floor((y - item.y - item.h) / item.option_height) + 1
                if index >= 1 and index <= #item.items then self:setValue(item, index) end
                item.open = false
                self.mouse_down = false
                return
            end
            item.open = false
        end
    end

    local target = self.hovered_widget
    for _, item in ipairs(self.widgets) do
        if item.type == "container" and item ~= target then
            item.ui:clearFocus()
        end
    end
    if not target or not target.enabled then
        self.focused_widget = nil
        for _, item in ipairs(self.widgets) do
            if item.type == "container" then item.ui:clearFocus() end
        end
        return
    end

    self.pressed_widget = target
    target.pressed = true

    if target.type == "container" then
        target.ui:mousepressed(x, y, button)
        return
    end

    if target.type == "textinput" then
        self.focused_widget = target
    else
        self.focused_widget = nil
    end

    if target.type == "slider" then
        self:_updateSlider(target, x)
    end
end

function UI:mousereleased(x, y, button)
    if button ~= 1 then return end

    self:mousemoved(x, y)

    local widget = self.pressed_widget
    local activate = widget and widget.enabled and inside(widget, x, y)

    self.mouse_down = false
    self.pressed_widget = nil

    for _, item in ipairs(self.widgets) do
        item.pressed = false
    end

    if not activate then
        if widget and widget.type == "container" then
            widget.ui:mousereleased(x, y, button)
        end
        return
    end

    if widget.type == "container" then
        widget.ui:mousereleased(x, y, button)
    elseif widget.type == "button" then
        if widget.callback then widget.callback() end
    elseif widget.type == "dropdown" then
        widget.open = not widget.open
        self.focused_widget = widget
    elseif widget.type == "radio" then
        if not widget.selected then
            if widget.group then
                for _, other in ipairs(self.widgets) do
                    if other.type == "radio" and other.group == widget.group and other ~= widget then
                        other.selected = false
                    end
                end
            end
            widget.selected = true
            if widget.callback then widget.callback(true) end
        end
    elseif widget.type == "checkbox" then
        widget.checked = not widget.checked
        if widget.callback then widget.callback(widget.checked) end
    elseif widget.type == "slider" then
        self:_updateSlider(widget, x)
    end
end

function UI:clearFocus()
    self.focused_widget = nil
    for _, item in ipairs(self.widgets) do
        if item.type == "container" then item.ui:clearFocus() end
    end
    return self
end

function UI:handleTextInput(text)
    local widget = self.focused_widget
    if not widget then
        for _, item in ipairs(self.widgets) do
            if item.type == "container" then item.ui:handleTextInput(text) end
        end
        return
    end
    if not widget.enabled or widget.type ~= "textinput" then return end

    if #widget.text >= widget.max_length then return end

    self:setValue(widget,
        widget.text .. text:sub(1, widget.max_length - #widget.text))
end

function UI:keypressed(key)
    local candidates = {}
    for _, widget in ipairs(self.widgets) do
        if widget.enabled and (widget.type == "button" or widget.type == "checkbox"
            or widget.type == "radio" or widget.type == "dropdown" or widget.type == "textinput"
            or widget.type == "slider") then
            candidates[#candidates + 1] = widget
        elseif widget.type == "container" then
            widget.ui:keypressed(key)
        end
    end

    local focused = self.focused_widget
    if key == "tab" then
        if #candidates == 0 then self.focused_widget = nil; return end
        local index = 0
        for i, item in ipairs(candidates) do if item == focused then index = i; break end end
        if love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("lshift", "rshift") then
            index = index - 1
            if index < 1 then index = #candidates end
        else
            index = index + 1
            if index > #candidates then index = 1 end
        end
        self.focused_widget = candidates[index]
        self.focus_index = index
        return
    end

    if not focused then return end
    if not focused.enabled then self.focused_widget = nil; return end
    if focused.type == "textinput" then
        if key == "backspace" then
            local offset = #focused.text
            while offset > 0 do
                local byte = focused.text:byte(offset)
                if byte < 128 or byte >= 192 then break end
                offset = offset - 1
            end
            self:setValue(focused, focused.text:sub(1, offset - 1))
        elseif key == "return" or key == "kpenter" or key == "escape" then
            self.focused_widget = nil
        end
        return
    end

    if focused.type == "dropdown" then
        if key == "return" or key == "kpenter" or key == "space" then
            focused.open = not focused.open
        elseif focused.open and (key == "down" or key == "up") then
            local delta = key == "down" and 1 or -1
            self:setValue(focused, math.max(1, math.min(#focused.items, focused.selected + delta)))
        elseif key == "escape" then focused.open = false end
        return
    end

    if focused.type == "radio" and (key == "left" or key == "right" or key == "up" or key == "down") then
        local group = {}
        for _, item in ipairs(self.widgets) do
            if item.enabled and item.type == "radio" and item.group == focused.group then group[#group + 1] = item end
        end
        if #group > 0 then
            local index = 1
            for i, item in ipairs(group) do if item == focused then index = i; break end end
            local delta = (key == "left" or key == "up") and -1 or 1
            index = ((index - 1 + delta) % #group) + 1
            self.focused_widget = group[index]
            self:setValue(group[index], true)
            if group[index].callback then group[index].callback(true) end
        end
        return
    end

    if key == "return" or key == "kpenter" or key == "space" then
        if focused.type == "button" and focused.callback then focused.callback()
        elseif focused.type == "checkbox" then self:setValue(focused, not focused.checked)
        elseif focused.type == "radio" then
            if focused.group then
                for _, other in ipairs(self.widgets) do
                    if other.type == "radio" and other.group == focused.group then other.selected = other == focused end
                end
            else focused.selected = true end
            if focused.callback then focused.callback(true) end
        end
    elseif focused.type == "slider" and (key == "left" or key == "right") then
        local step = focused.step or ((focused.max - focused.min) / 100)
        self:setValue(focused, focused.value + (key == "right" and step or -step))
    elseif key == "escape" then self.focused_widget = nil end
end

function UI:releaseAll()
    self.mouse_down = false
    self.pressed_widget = nil

    for _, widget in ipairs(self.widgets) do
        widget.pressed = false
        if widget.type == "container" then widget.ui:releaseAll() end
    end
end

function UI:draw(renderer)
    assert(type(renderer) == "table", "renderer must be a table")
    assert(type(renderer.rect) == "function", "renderer.rect is required")
    assert(type(renderer.text) == "function", "renderer.text is required")

    local t = self.theme

    renderer:rect("fill", self.x, self.y, self.w, self.fixed_height or self.h,
        colorCopy(t.background), t.radius)

    for _, widget in ipairs(self.widgets) do
        local enabled = widget.enabled

        if widget.type == "container" then
            renderer:rect("fill", widget.x, widget.y, widget.w, widget.h,
                colorCopy(widget.background or t.surface), t.radius)
            renderer:rect("line", widget.x, widget.y, widget.w, widget.h,
                colorCopy(widget.border or t.border), t.radius)
            if renderer.pushClip then renderer:pushClip(widget.x + 1, widget.y + 1, widget.w - 2, widget.h - 2) end
            widget.ui.x = widget.x
            widget.ui.y = widget.y - (widget.scroll_y or 0)
            widget.ui.w = widget.w
            widget.ui:layout()
            widget.ui:draw(renderer)
            if renderer.popClip then renderer:popClip() end
            if widget.scrollable and (widget.ui.content_h or 0) > widget.h then
                local track_h = widget.h - 12
                local content_h = widget.ui.content_h
                local thumb_h = math.max(18, track_h * widget.h / content_h)
                local max_scroll = content_h - widget.h
                local thumb_y = widget.y + 6 + (track_h - thumb_h) * widget.scroll_y / max_scroll
                renderer:rect("fill", widget.x + widget.w - 6, widget.y + 6, 3, track_h, colorCopy(t.track), 2)
                renderer:rect("fill", widget.x + widget.w - 6, thumb_y, 3, thumb_h, colorCopy(t.accent), 2)
            end

        elseif widget.type == "label" then
            renderer:text(widget.text, widget.x, widget.y + 3,
                colorCopy(widget.color or t.foreground))

        elseif widget.type == "separator" then
            renderer:rect("fill", widget.x, widget.y + widget.h / 2,
                widget.w, 1, colorCopy(widget.color or t.border), 0)

        elseif widget.type == "button" then
            local bg = widget.background
                or (not enabled and t.disabled)
                or (widget.pressed and t.surface_pressed)
                or (widget.hovered and t.surface_hover)
                or t.surface

            renderer:rect("fill", widget.x, widget.y, widget.w, widget.h,
                colorCopy(bg), widget.radius or t.radius)

            renderer:text(widget.text, widget.x + 10,
                widget.y + math.max(2, (widget.h - 16) / 2),
                colorCopy(widget.foreground or (enabled and t.foreground or t.muted)))

        elseif widget.type == "checkbox" then
            local size = math.min(18, widget.h - 4)
            local boxY = widget.y + (widget.h - size) / 2
            local color = enabled and (widget.color or t.accent) or t.disabled

            renderer:rect("line", widget.x, boxY, size, size,
                colorCopy(color), 3)

            if widget.checked then
                renderer:rect("fill", widget.x + 4, boxY + 4,
                    size - 8, size - 8, colorCopy(color), 2)
            end

            renderer:text(widget.text, widget.x + size + 8,
                widget.y + math.max(2, (widget.h - 16) / 2),
                colorCopy(enabled and t.foreground or t.muted))

        elseif widget.type == "radio" then
            local size = math.min(18, widget.h - 4)
            local boxY = widget.y + (widget.h - size) / 2
            local color = enabled and (widget.color or t.accent) or t.disabled
            renderer:rect("line", widget.x, boxY, size, size, colorCopy(color), size / 2)
            if widget.selected then
                renderer:rect("fill", widget.x + 5, boxY + 5, size - 10, size - 10, colorCopy(color), size / 2)
            end
            renderer:text(widget.text, widget.x + size + 8, widget.y + math.max(2, (widget.h - 16) / 2), colorCopy(enabled and t.foreground or t.muted))

        elseif widget.type == "dropdown" then
            renderer:rect("fill", widget.x, widget.y, widget.w, widget.h, colorCopy(widget.enabled and (widget.hovered and t.surface_hover or t.surface) or t.disabled), t.radius)
            renderer:rect("line", widget.x, widget.y, widget.w, widget.h, colorCopy(t.border), t.radius)
            local label = widget.selected > 0 and tostring(widget.items[widget.selected]) or widget.placeholder
            renderer:text(label, widget.x + 9, widget.y + 9, colorCopy(widget.enabled and t.foreground or t.muted))
            renderer:text(widget.open and "▲" or "▼", widget.x + widget.w - 22, widget.y + 9, colorCopy(t.muted))
            -- Popup rendering happens after all regular widgets so later labels and
            -- controls cannot paint over the open menu.

        elseif widget.type == "textinput" then
            local bg = widget.background or t.surface
            renderer:rect("fill", widget.x, widget.y, widget.w, widget.h,
                colorCopy(bg), t.radius)

            local focused = self.focused_widget == widget
            renderer:rect("line", widget.x, widget.y, widget.w, widget.h,
                colorCopy(focused and t.accent or t.border), t.radius)

            local value = widget.text
            local color = widget.foreground or t.foreground
            if value == "" then
                value = widget.placeholder
                color = t.muted
            end

            renderer:text(value, widget.x + 9, widget.y + 9,
                colorCopy(enabled and color or t.muted))

            if focused then
                local cursorX = widget.x + 9
                    + renderer:textWidth(value)
                renderer:rect("fill", cursorX, widget.y + 8, 1,
                    widget.h - 16, colorCopy(t.foreground), 0)
            end

        elseif widget.type == "slider" then
            local trackY = widget.y + 23
            local ratio = (widget.value - widget.min) / (widget.max - widget.min)
            local fillW = widget.w * ratio
            local color = enabled and (widget.color or t.accent) or t.disabled

            if widget.label then
                renderer:text(widget.label, widget.x, widget.y,
                    colorCopy(t.foreground))
                renderer:text(tostring(widget.value),
                    widget.x + widget.w - 48, widget.y,
                    colorCopy(t.muted))
            end

            renderer:rect("fill", widget.x, trackY, widget.w, 5,
                colorCopy(t.track), 3)
            renderer:rect("fill", widget.x, trackY, fillW, 5,
                colorCopy(color), 3)
            renderer:rect("fill", widget.x + fillW - 6, trackY - 5,
                12, 15, colorCopy(color), 6)

        elseif widget.type == "progressbar" then
            renderer:rect("fill", widget.x, widget.y, widget.w, widget.h,
                colorCopy(widget.track_color or t.track), t.radius)
            renderer:rect("fill", widget.x, widget.y,
                widget.w * widget.value, widget.h,
                colorCopy(widget.color or t.accent), t.radius)
        end
        if self.focused_widget == widget and widget.type ~= "textinput" then
            renderer:rect("line", widget.x, widget.y, widget.w, widget.h, colorCopy(t.accent), t.radius)
        end
    end

    -- Draw open dropdown popups in a final pass, above every regular widget.
    -- Keep the popup background opaque so underlying labels are not visible
    -- through the option list.
    for _, widget in ipairs(self.widgets) do
        if widget.type == "dropdown" and widget.open and widget.enabled then
            local count = math.min(#widget.items, widget.max_visible)
            if count > 0 then
                local menu_x = widget.x
                local menu_y = widget.y + widget.h
                local menu_h = count * widget.option_height

                renderer:rect("fill", menu_x, menu_y, widget.w, menu_h,
                    colorCopy(t.background), t.radius)
                renderer:rect("line", menu_x, menu_y, widget.w, menu_h,
                    colorCopy(t.border), t.radius)

                for i = 1, count do
                    local option_y = menu_y + (i - 1) * widget.option_height
                    if widget.option_hover == i or widget.selected == i then
                        local option_color = widget.option_hover == i
                            and t.surface_hover or t.surface
                        renderer:rect("fill", menu_x + 1, option_y,
                            widget.w - 2, widget.option_height,
                            colorCopy(option_color), 2)
                    end
                    renderer:text(tostring(widget.items[i]), menu_x + 9,
                        option_y + math.max(4, (widget.option_height - 16) / 2),
                        colorCopy(t.foreground))
                end
            end
        end
    end

    local hovered = self.hovered_widget
    if hovered and hovered.tooltip and self.hover_time >= (hovered.tooltip_delay or self.tooltip_delay) then
        local label = tostring(hovered.tooltip)
        local tw = renderer.textWidth and renderer:textWidth(label) or (#label * 7)
        local tx, ty = self.mouse_x + 14, self.mouse_y + 16
        local max_x = self.x + self.w
        if tx + tw + 16 > max_x then tx = math.max(self.x, self.mouse_x - tw - 18) end
        renderer:rect("fill", tx, ty, tw + 16, 28, colorCopy(t.surface_pressed), t.radius)
        renderer:rect("line", tx, ty, tw + 16, 28, colorCopy(t.border), t.radius)
        renderer:text(label, tx + 8, ty + 6, colorCopy(t.foreground))
    end
end

GUI.themes = {
    dark = DEFAULTS,
    light = {
        background = {0.96, 0.97, 0.99, 1},
        foreground = {0.12, 0.14, 0.19, 1},
        muted = {0.40, 0.43, 0.50, 1},
        accent = {0.12, 0.38, 0.82, 1},
        border = {0.78, 0.80, 0.85, 1},
        surface = {1, 1, 1, 1},
        surface_hover = {0.91, 0.93, 0.97, 1},
        surface_pressed = {0.85, 0.88, 0.94, 1},
        disabled = {0.78, 0.79, 0.82, 1},
        track = {0.84, 0.86, 0.90, 1},
        radius = 6,
    },
}

return GUI
