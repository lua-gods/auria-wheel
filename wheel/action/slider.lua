local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.page
local Page = wheel.page

local myTextureSize = wheel.texture:getDimensions()

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.slider : auria.wheel.action
---@field sliderType auria.wheel.action.slider.sliderType
local methods = {}
api.methods = {}
---@alias auria.wheel.action.slider.sliderType "colorpicker"|"hue"

local hueUVMatrix = matrices.mat3()
hueUVMatrix:scale(6, 0, 1)
   :translate(7.5 / myTextureSize.x, 0.5 / myTextureSize.y)

function api.makePopup(action, model)
   for _, v in pairs(wheel.models.slider:getChildren()) do
      v:copy(v:getName())
         :light(15, 15)
         :moveTo(model)
   end
   local size = vec(96, 12)
   -- local bg = uiSpriteTemplate:copy("")
   -- local outline = uiSpriteTemplate:copy("")
   if action.type == "colorpicker" or action.type == "hue" then
      model.bg:setPrimaryRenderType("BLURRY")
      if action.type == "hue" then
         model.bg:setUVMatrix(hueUVMatrix)
         model.indicator:setColor(0, 0, 0)
      else
         size = vec(128, 128)
         model.bg:setUVPixels(3.5, 0.5)
      end
   else
      model.indicator:setVisible(false)
   end
   local size2 = size:augmented(0)
   model.bg:setScale(size2)
      :setPos(size2 / -2 + vec(0, 0, -1))
   model.outline1:setPos(size2 / 2):scale(size.x + 4, 2, 1)
   model.outline2:setPos(size2 / -2):scale(size.x + 4, 2, 1)
   model.outline3:setPos(size2 / 2):scale(2, size.y, 1)
   model.outline4:setPos(size2 / -2):scale(2, size.y, 1)
end

---@return auria.wheel.action.slider
function Page:newSlider()
   return wheel.newAction("slider", self)
end

function methods:setSliderType()

end

wheel.newActionType("slider", api)