local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.page
local Page = wheel.page

local myTextureSize = wheel.texture:getDimensions()
local defaultBgSize = vec(96, 12)

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.slider : auria.wheel.action
---@field bgTexture Texture?
---@field bgMatrix Matrix3?
---@field backgroundSize Vector2
---@field bgRenderType ModelPart.renderType|string?
local methods = {}
api.methods = methods

local hueUVMatrix = matrices.mat3()
hueUVMatrix:scale(6, 0, 1)
   :translate(7.5 / myTextureSize.x, 0.5 / myTextureSize.y)

---@param action auria.wheel.action.slider
---@param model ModelPart
function api.makePopup(action, model)
   for _, v in pairs(wheel.models.slider:getChildren()) do
      v:copy(v:getName())
         :light(15, 15)
         :moveTo(model)
   end
   local size = action.backgroundSize
   if action.bgTexture then
      local bg = wheel.models.sprite:copy("bg")
      model:addChild(bg)
      bg:setPrimaryTexture("CUSTOM", action.bgTexture)
         :setUVMatrix(action.bgMatrix)
      if action.bgRenderType then
         bg:setPrimaryRenderType(action.bgRenderType)
      end
   else
      model:addChild(wheel.models.slider_bg:copy("bg"))
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

function api.press(action)
   wheel.makeActionPopup(action)
end

---@return auria.wheel.action.slider
function Page:newSlider()
   local slider = wheel.newAction("slider", self)
   slider.value = 0
   slider.backgroundSize = defaultBgSize
   return slider
end

---@param texture Texture
---@param pos Vector2
---@param size Vector2
---@param renderType? ModelPart.renderType
---@return auria.wheel.action.slider
function methods:setBackground(texture, pos, size, renderType)
   local texSize = texture:getDimensions()
   local mat = matrices.mat3()
   mat:scale((size / texSize):augmented(1))
   mat:translate(pos / texSize)
   self.bgTexture = texture
   self.bgMatrix = mat
   self.bgRenderType = renderType
   return self
end

---@param size Vector2?
---@return auria.wheel.action.slider
function methods:setBackgroundSize(size)
   self.backgroundSize = size or defaultBgSize
   return self
end

wheel.newActionType("slider", api)