
local Color = {}







local Color_mt = {
   __index = Color,
   __add = function(self, other)
      return Color.__add(self, other)
   end,
}

function Color.new(r, g, b)
   local self = setmetatable({}, Color_mt)
   self.r = r
   self.g = g
   self.b = b
   return self
end

function Color:__add(other)
   return Color.new(
   self.r + other.r,
   self.g + other.g,
   self.b + other.b)

end

return Color
