-- Data class demo: auto fields, auto constructor, __tostring, __eq, copy.

data class Point(x: number, y: number)
    public dist(other: Point): number
        local dx = self.x - other.x
        local dy = self.y - other.y
        return math.sqrt(dx * dx + dy * dy)
    end

    public scale(factor: number): Point
        return Point.new(self.x * factor, self.y * factor)
    end
end

local p1 = Point.new(3, 4)
local p2 = Point.new(3, 4)
local origin = Point.new(0, 0)

print(p1)                          -- Point(x=3, y=4)
print(p1 == p2)                    -- true
print(p1 == origin)                -- false
print(p1:dist(origin))             -- 5
print(p1:copy() == p1)             -- true

local scaled = p1:scale(2)
print(scaled)                      -- Point(x=6, y=8)
print(p1 == scaled)                -- false
