-- Teal declarations for the public GameKit API.
-- Keep these signatures aligned with gamekit/*.lua.

local record Widget
    type: string
    text: string
    x: number
    y: number
    w: number
    h: number
end

local record Renderer
    rect: function(self: Renderer, mode: string, x: number, y: number, w: number, h: number, color: any, radius?: number)
    text: function(self: Renderer, value: string, x: number, y: number, color: any)
    textWidth: function(self: Renderer, value: string): number
    pushClip: function(self: Renderer, x: number, y: number, w: number, h: number)
    popClip: function(self: Renderer)
end


local record UI
    x: number
    y: number
    w: number
    h: number
    theme: any
    widgets: {Widget}
    add: function(self: UI, widget: Widget): Widget
    label: function(self: UI, text: string, options?: any): Widget
    separator: function(self: UI, options?: any): Widget
    button: function(self: UI, text: string, callback?: function(), options?: any): Widget
    checkbox: function(self: UI, text: string, checked: boolean, callback?: function(checked: boolean), options?: any): Widget
    textinput: function(self: UI, text: string, callback?: function(value: string), options?: any): Widget
    radio: function(self: UI, text: string, selected: boolean, callback?: function(selected: boolean), options?: any): Widget
    dropdown: function(self: UI, options?: any): Widget
    setTheme: function(self: UI, theme: any): UI
    getTheme: function(self: UI): any
    setTooltip: function(self: UI, widget: Widget, text: string, delay?: number): UI
    container: function(self: UI, options?: any): UI
    slider: function(self: UI, value: number, min: number, max: number, callback?: function(value: number), options?: any): Widget
    progressbar: function(self: UI, value: number, options?: any): Widget
    setProgress: function(self: UI, widget: Widget, value: number): UI
    setValue: function(self: UI, widget: Widget, value: any, silent?: boolean): UI
    setEnabled: function(self: UI, widget: Widget, enabled: boolean): UI
    setBounds: function(self: UI, x: number, y: number, width: number, height: number): UI
    resize: function(self: UI, width: number, height: number): UI
    wheelmoved: function(self: UI, x: number, y: number)
    update: function(self: UI, dt: number)
    mousemoved: function(self: UI, x: number, y: number)
    mousepressed: function(self: UI, x: number, y: number, button: number)
    mousereleased: function(self: UI, x: number, y: number, button: number)
    handleTextInput: function(self: UI, text: string)
    keypressed: function(self: UI, key: string)
    releaseAll: function(self: UI)
    draw: function(self: UI, renderer: Renderer)
end


local record GUIThemes
    dark: any
    light: any
end

local record GUIFactory
    new: function(options?: any): UI
    themes: GUIThemes
end

local record LoveGUIFactory
    new: function(options?: any): Renderer
    attach: function(ui: UI): function()
end

local record TimerModule
    after: function(delay: number, callback: function()): number
    every: function(interval: number, callback: function(), repetitions?: number): number
    cancel: function(id: number): boolean
    clear: function()
    update: function(dt: number)
end

local record SceneModule
    switch: function(next_scene: any)
    current: function(): any
    update: function(dt: number)
    draw: function(...: any)
    reset: function()
end

local record InputModule
    bind: function(action: string, ...: any)
    unbind: function(action: string)
    down: function(action: string): boolean
    pressed: function(action: string): boolean
    released: function(action: string): boolean
    setSource: function(source: string, is_down: boolean)
    keypressed: function(key: string)
    keyreleased: function(key: string)
    releaseAll: function()
    endFrame: function()
    reset: function()
    mousePosition: function(): number, number
    mouseDown: function(button?: integer): boolean
    mouseMoved: function(x: number, y: number)
    mousePressed: function(x: number, y: number, button: integer)
    mouseReleased: function(x: number, y: number, button: integer)
end

local record WindowModule
    getSize: function(): number, number
    setSize: function(width: number, height: number)
    setTitle: function(title: string)
    setResizable: function(resizable: boolean)
    setMinSize: function(width: number, height: number)
    setFullscreen: function(enabled: boolean, mode?: string)
    toggleFullscreen: function(mode?: string): boolean
    setBorderless: function(enabled: boolean)
    isFullscreen: function(): boolean
    setVSync: function(value: number)
    configure: function(options: any)
end

local record CameraModule
    new: function(options?: any): any
end

local record DockModule
    new: function(options?: any): any
end

local record LoveModule
    install: function(create_scene: function())
end

local record LovrModule
    install: function(create_scene: function())
end

local record GraphicsModule
    clear: function(color?: any)
    setColor: function(color: any)
    circle: function(mode: string, x: number, y: number, radius: number, color?: any, segments?: integer)
    rectangle: function(mode: string, x: number, y: number, width: number, height: number, color?: any)
    line: function(x1: number, y1: number, x2: number, y2: number, color?: any)
    print: function(text: string, x?: number, y?: number, color?: any)
    getDimensions: function(): number, number
    push: function()
    pop: function()
    translate: function(x: number, y: number)
    scale: function(sx: number, sy?: number)
    rotate: function(radians: number)
    raw: function(): any
    setFont: function(font: any)
    setLineWidth: function(w: number)
    image: function(img: any, x: number, y: number, r?: number, sx?: number, sy?: number)
    polygon: function(mode: string, color: any, ...: any)
    ellipse: function(mode: string, x: number, y: number, rx: number, ry: number, color?: any, segments?: integer)
    arc: function(mode: string, x: number, y: number, radius: number, a1: number, a2: number, color?: any, segments?: integer)
    reset: function()
end

local record AssetsModule
    image: function(path: string): any
    font: function(path: any, size?: integer): any
    sound: function(path: string): any
    music: function(path: string): any
    clear: function()
end

local record AudioModule
    play: function(sound: any, volume?: number, pitch?: number): any
    playMusic: function(sound: any, volume?: number): any
    stopMusic: function()
    stopAll: function()
    setMasterVolume: function(v: number)
    fadeIn: function(source: any, duration: number, target?: number)
    fadeOut: function(source: any, duration: number, on_complete?: function())
    update: function(dt: number)
end

local record ErrorsModule
    traceback: function(err: any): string
    guard: function(fn: function(), on_error?: any, label?: string): function()
    fail: function(msg: string)
    assert: function(cond: any, msg?: string): any
end

local record AppHandle
    stop: function(self: AppHandle)
    onError: function(self: AppHandle, fn: function(string, any))
end

-- GameKit.app(config) accepts a plain table. Recognized keys (all optional):
--   title, width, height, resizable, vsync, background, clearOnDraw,
--   gui, gui_draw, gui_renderer, on_error,
--   load, update, draw, keypressed, keyreleased,
--   mousepressed, mousereleased, mousemoved, wheelmoved, textinput,
--   resize, focus, quit
-- Runtime defaults live in gamekit/app.lua mergeConfig().
local record GameKit
    app: function(config?: any): AppHandle
    graphics: GraphicsModule
    assets: AssetsModule
    audio: AudioModule
    errors: ErrorsModule
    Scene: SceneModule
    Input: InputModule
    Timer: TimerModule
    Love: LoveModule
    Lovr: LovrModule
    GUI: GUIFactory
    LoveGUI: LoveGUIFactory
    Window: WindowModule
    Dock: DockModule
    Camera: CameraModule
end

global update: function(dt: number)
global draw: function()
global keypressed: function(key: string, scancode?: string, isrepeat?: boolean)
global keyreleased: function(key: string)
global mousepressed: function(x: number, y: number, button: integer, istouch?: boolean, presses?: integer)
global mousereleased: function(x: number, y: number, button: integer, istouch?: boolean, presses?: integer)
global mousemoved: function(x: number, y: number, dx: number, dy: number, istouch?: boolean)
global wheelmoved: function(x: number, y: number)
global textinput: function(text: string)
global resize: function(width: number, height: number)
global focus: function(focused: boolean)

return GameKit
