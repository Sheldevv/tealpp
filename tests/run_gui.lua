
local GUI = require("gamekit.gui")

local passed = 0

local function test(name, callback)
    local ok, err = pcall(callback)

    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        print("FAIL: " .. name)
        print("  " .. tostring(err))
        os.exit(1)
    end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(
            (message or "Values are not equal")
            .. ": expected "
            .. tostring(expected)
            .. ", got "
            .. tostring(actual),
            2
        )
    end
end

local function near(actual, expected, message)
    if math.abs(actual - expected) > 0.0001 then
        error(
            (message or "Values are not close")
            .. ": expected "
            .. tostring(expected)
            .. ", got "
            .. tostring(actual),
            2
        )
    end
end

local function makeUI()
    local ui = GUI.new({
        x = 10,
        y = 10,
        width = 300,
        padding = 10,
        spacing = 5,
    })

    return ui
end

-- Original GUI tests

test("widgets receive valid layout dimensions", function()
    local ui = makeUI()
    local label = ui:label("Hello")
    local button = ui:button("Click me")
    local checkbox = ui:checkbox("Enabled", false)

    ui:layout()

    for _, widget in ipairs({label, button, checkbox}) do
        assert(widget.x ~= nil)
        assert(widget.y ~= nil)
        assert(widget.w ~= nil)
        assert(widget.h ~= nil)
        assert(widget.w > 0)
        assert(widget.h > 0)
    end
end)

test("button activates on press and release inside", function()
    local ui = makeUI()
    local clicked = false

    local button = ui:button("Click me", function()
        clicked = true
    end)

    ui:mousepressed(button.x + 5, button.y + 5, 1)
    equal(clicked, false)

    ui:mousereleased(button.x + 5, button.y + 5, 1)
    equal(clicked, true)
end)

test("dragging off a button cancels the click", function()
    local ui = makeUI()
    local clicked = false

    local button = ui:button("Click me", function()
        clicked = true
    end)

    ui:mousepressed(button.x + 5, button.y + 5, 1)
    ui:mousemoved(button.x + button.w + 20, button.y + 5)
    ui:mousereleased(button.x + button.w + 20, button.y + 5, 1)

    equal(clicked, false)
end)

test("releasing on a different button does not activate it", function()
    local ui = makeUI()
    local firstClicked = false
    local secondClicked = false

    local first = ui:button("First", function()
        firstClicked = true
    end)

    local second = ui:button("Second", function()
        secondClicked = true
    end)

    ui:layout()

    ui:mousepressed(first.x + 5, first.y + 5, 1)
    ui:mousereleased(second.x + 5, second.y + 5, 1)

    equal(firstClicked, false)
    equal(secondClicked, false)
end)

test("right-click does not activate widgets", function()
    local ui = makeUI()
    local clicked = false

    local button = ui:button("Click me", function()
        clicked = true
    end)

    ui:mousepressed(button.x + 5, button.y + 5, 2)
    ui:mousereleased(button.x + 5, button.y + 5, 2)

    equal(clicked, false)
end)

test("hover state follows the mouse", function()
    local ui = makeUI()
    local button = ui:button("Hover me")

    ui:mousemoved(button.x + 5, button.y + 5)
    equal(button.hovered, true)

    ui:mousemoved(button.x + button.w + 20, button.y + button.h + 20)
    equal(button.hovered, false)
end)

test("checkbox toggles and reports its new value", function()
    local ui = makeUI()
    local reported = nil

    local checkbox = ui:checkbox("Enabled", false, function(value)
        reported = value
    end)

    ui:mousepressed(checkbox.x + 5, checkbox.y + 5, 1)
    ui:mousereleased(checkbox.x + 5, checkbox.y + 5, 1)

    equal(checkbox.checked, true)
    equal(reported, true)
end)

test("disabled button cannot activate", function()
    local ui = makeUI()
    local clicked = false

    local button = ui:button("Disabled", function()
        clicked = true
    end)

    ui:setEnabled(button, false)

    ui:mousepressed(button.x + 5, button.y + 5, 1)
    ui:mousereleased(button.x + 5, button.y + 5, 1)

    equal(clicked, false)
end)

test("releaseAll clears pressed state", function()
    local ui = makeUI()
    local button = ui:button("Click me")

    ui:mousepressed(button.x + 5, button.y + 5, 1)
    ui:releaseAll()

    equal(button.pressed, false)
end)

test("draw calls the renderer for panel and widgets", function()
    local ui = makeUI()

    ui:label("Hello")
    ui:button("Click me")
    ui:checkbox("Enabled", false)

    local rectCount = 0
    local textCount = 0

    local renderer = {
        rect = function()
            rectCount = rectCount + 1
        end,

        text = function()
            textCount = textCount + 1
        end,

        textWidth = function(_, text)
            return #text * 8
        end,
    }

    ui:draw(renderer)

    assert(rectCount > 0, "Expected at least one rectangle to be drawn")
    assert(textCount > 0, "Expected at least one text element to be drawn")
end)

-- Milestone 4 tests

test("text input accepts text when focused", function()
    local ui = makeUI()
    local received = nil

    local input = ui:textinput("", function(value)
        received = value
    end, {
        placeholder = "Name",
    })

    ui:mousepressed(input.x + 5, input.y + 5, 1)
    ui:mousereleased(input.x + 5, input.y + 5, 1)

    -- The GUI's keyboard-text handler is separate from its widget constructor.
    ui:handleTextInput("Sam")

    equal(input.text, "Sam")
    equal(received, "Sam")
end)

test("text input backspace removes the last character", function()
    local ui = makeUI()
    local input = ui:textinput("Hello")

    ui:mousepressed(input.x + 5, input.y + 5, 1)
    ui:mousereleased(input.x + 5, input.y + 5, 1)
    ui:keypressed("backspace")

    equal(input.text, "Hell")
end)

test("slider clamps and reports values", function()
    local ui = makeUI()
    local reported = nil

    local slider = ui:slider(0.5, 0, 1, function(value)
        reported = value
    end)

    ui:setValue(slider, 2)
    equal(slider.value, 1)
    equal(reported, 1)

    ui:setValue(slider, -1)
    equal(slider.value, 0)
    equal(reported, 0)
end)

test("slider step rounds to valid increments", function()
    local ui = makeUI()
    local slider = ui:slider(0, 0, 10, nil, {
        step = 2,
    })

    ui:setValue(slider, 5.1)
    equal(slider.value, 6)
end)

test("progress bar values are clamped", function()
    local ui = makeUI()
    local progress = ui:progressbar(0.5)

    ui:setProgress(progress, 1.5)
    equal(progress.value, 1)

    ui:setProgress(progress, -2)
    equal(progress.value, 0)
end)

test("custom widget colors do not mutate theme colors", function()
    local ui = makeUI()

    local button = ui:button("Custom", nil, {
        background = {1, 0, 0, 1},
    })

    local renderer = {
        rect = function(_, mode, x, y, w, h, color)
            if mode == "fill" and x == button.x and y == button.y then
                color[1] = 0
            end
        end,

        text = function() end,

        textWidth = function(_, text)
            return #text * 8
        end,
    }

    ui:draw(renderer)

    near(ui.theme.surface[1], 0.15)
end)


test("horizontal layout distributes automatic widget widths", function()
    local ui = GUI.new({
        x = 0, y = 0, w = 300, padding = 10, spacing = 10,
        direction = "horizontal",
    })
    local first = ui:button("First")
    local second = ui:button("Second")
    ui:layout()
    assert(first.w > 0 and second.w > 0)
    assert(first.x + first.w <= second.x)
    assert(second.x + second.w <= ui.x + ui.w - ui.padding)
end)

test("setBounds updates widget positions and widths", function()
    local ui = makeUI()
    local button = ui:button("Resize me")
    ui:setBounds(20, 30, 400)
    equal(button.x, 30)
    equal(button.y, 40)
    equal(button.w, 380)
end)

test("responsive UI respects window size and maximum width", function()
    local ui = GUI.new({
        x = 20, y = 10, w = 300, responsive = true,
        right_margin = 20, min_width = 160, max_width = 500,
    })
    ui:resize(800, 600)
    equal(ui.w, 500)
    ui:resize(300, 600)
    equal(ui.w, 260)
end)

test("nested container buttons receive clicks", function()
    local ui = makeUI()
    local clicked = false
    local panel = ui:container({height = 100, padding = 8})
    local button = panel:button("Nested", function() clicked = true end)
    ui:layout()

    local x = button.x + button.w / 2
    local y = button.y + button.h / 2
    ui:mousepressed(x, y, 1)
    ui:mousereleased(x, y, 1)
    equal(clicked, true)
end)

test("scrollable containers clamp scrolling", function()
    local ui = makeUI()
    local panel = ui:container({height = 70, scrollable = true})
    for i = 1, 10 do panel:label("Item " .. i) end
    ui:layout()
    local container = ui.widgets[1]
    ui:mousemoved(container.x + 5, container.y + 5)
    ui:wheelmoved(0, -100)
    assert(container.scroll_y > 0)
    assert(container.scroll_y <= panel.content_h - container.h)
end)

test("dropdown opens and selects an option", function()
    local ui = makeUI()
    local selected = nil
    local dropdown = ui:dropdown({items = {"Easy", "Normal", "Hard"}, selected = 1, callback = function(index) selected = index end})
    ui:mousepressed(dropdown.x + 5, dropdown.y + 5, 1)
    ui:mousereleased(dropdown.x + 5, dropdown.y + 5, 1)
    equal(dropdown.open, true)
    local x, y = dropdown.x + 5, dropdown.y + dropdown.h + dropdown.option_height + 5
    ui:mousepressed(x, y, 1)
    equal(dropdown.selected, 2)
    equal(selected, 2)
    equal(dropdown.open, false)
end)

test("dropdown popup draws above widgets below it", function()
    local ui = makeUI()
    local dropdown = ui:dropdown({items = {"First", "Second", "Third"}, selected = 1})
    ui:label("Text underneath the popup")
    dropdown.open = true

    local drawn_text = {}
    local renderer = {
        rect = function() end,
        text = function(_, value)
            drawn_text[#drawn_text + 1] = tostring(value)
        end,
        textWidth = function(_, value) return #tostring(value) * 8 end,
    }

    ui:draw(renderer)
    local last_option, lower_label = nil, nil
    for i, value in ipairs(drawn_text) do
        if value == "Third" then last_option = i end
        if value == "Text underneath the popup" then lower_label = i end
    end
    assert(lower_label and last_option, "Expected both the lower label and popup option to draw")
    assert(last_option > lower_label, "Dropdown popup should draw after the widgets behind it")
end)

test("radio buttons enforce a shared selection group", function()
    local ui = makeUI()
    local a = ui:radio("A", true, nil, {group = "mode"})
    local b = ui:radio("B", false, nil, {group = "mode"})
    ui:mousepressed(b.x + 5, b.y + 5, 1)
    ui:mousereleased(b.x + 5, b.y + 5, 1)
    equal(a.selected, false)
    equal(b.selected, true)
end)

test("keyboard tab focuses and activates buttons", function()
    local ui = makeUI()
    local clicked = false
    local button = ui:button("Keyboard", function() clicked = true end)
    ui:keypressed("tab")
    equal(ui.focused_widget, button)
    ui:keypressed("return")
    equal(clicked, true)
end)

test("theme changes are copied and tooltips render after their delay", function()
    local ui = makeUI()
    local button = ui:button("Help")
    ui:setTooltip(button, "Helpful hint", 0.1)
    ui:setTheme({accent = {1, 0, 0, 1}})
    equal(ui.theme.accent[1], 1)
    ui:mousemoved(button.x + 3, button.y + 3)
    ui:update(0.2)
    local found = false
    local renderer = {
        rect = function() end,
        text = function(_, value) if value == "Helpful hint" then found = true end end,
        textWidth = function(_, value) return #value * 7 end,
    }
    ui:draw(renderer)
    equal(found, true)
end)

print(("%d GUI tests passed!"):format(passed))
