local Color = dofile("color.lua")

local red = Color.new(255, 0, 0)
local blue = Color.new(0, 0, 255)

local purple = red + blue

assert(purple.r == 255)
assert(purple.g == 0)
assert(purple.b == 255)

print("Color operator overloading works!")
print(("RGB(%d, %d, %d)"):format(
    purple.r,
    purple.g,
    purple.b
))
