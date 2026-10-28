local tpp = dofile("src/tpp.lua")

local source = [[
-- comment before import
import gamekit as GameKit
import gamekit.camera as Camera -- import a submodule too

local ui = GameKit.GUI.new({ width = 320 })
print("this line should be preserved")
]]

local output = tpp.compile_program(source)
assert(output:find('local GameKit = require("gamekit")', 1, true), "main import was not lowered")
assert(output:find('local Camera = require("gamekit.camera")', 1, true), "submodule import was not lowered")
assert(output:find("local ui = GameKit.GUI.new({ width = 320 })", 1, true), "Teal source was not preserved")
assert(output:find('print("this line should be preserved")', 1, true), "program body was not preserved")

local ok, err = pcall(tpp.compile_program, "import gamekit\n")
assert(not ok and tostring(err):find("invalid import", 1, true), "malformed import should fail clearly")

local class_source = [[
class Sample
    public value: number
    constructor(@value: number)
    end
end
]]
local class_output = tpp.compile(class_source)
assert(class_output:find("function Sample.new(value: number): Sample", 1, true), "existing class compilation regressed")

print("6 Teal++ program/import checks passed!")
