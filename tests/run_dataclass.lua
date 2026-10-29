package.path = "./?.lua;./?/init.lua;" .. package.path
local tpp = dofile("src/tpp.lua")

local out = tpp.compile([[
data class Point(x: number, y: number)
    public dist(other: Point): number
        return 0.0
    end
end
]])

assert(out:find("local record Point"), "record declaration missing")
assert(out:find("x: number"), "field x missing")
assert(out:find("y: number"), "field y missing")
assert(out:find("new: function%(x: number, y: number%): Point"), "constructor signature missing")
assert(out:find("__tostring: function%(self: Point%): string"), "__tostring signature missing")
assert(out:find("__eq: function%(self: Point, other: Point%): boolean"), "__eq signature missing")
assert(out:find("copy: function%(self: Point%): Point"), "copy signature missing")
assert(out:find("self%.x = x"), "auto-assignment for x missing")
assert(out:find("self%.y = y"), "auto-assignment for y missing")
assert(out:find("Point%.new%(self%.x, self%.y%)"), "copy body missing")

-- Override check
local out2 = tpp.compile([[
data class Version(major: number, minor: number)
    public __tostring(): string
        return "custom"
    end
end
]])
assert(out2:find('return "custom"'), "user __tostring not used")
assert(not out2:find("Version%(major="), "auto __tostring should be skipped")

print("OK: run_dataclass")
