local mod = require("./core") ---@class auria.wheel

for _, path in pairs(listFiles("./action")) do
   require(path)
end

require("./color_picker")

return mod