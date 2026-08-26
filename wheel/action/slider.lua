local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.page
local Page = wheel.page

local myTextureSize = wheel.texture:getDimensions()
local defaultBgSize = vec(96, 12)

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.slider : auria.wheel.action
---@field value number
---@field valueY number
---@field range Vector2
---@field rangeY Vector2
---@field step number
---@field loop boolean
---@field bgTexture Texture?
---@field bgMatrix Matrix3?
---@field backgroundSize Vector2
---@field bgRenderType ModelPart.renderType|string?
---@field valueChange (fun(value: number, valueY: number))?
local methods = {}
api.methods = methods

local hueUVMatrix = matrices.mat3()
hueUVMatrix:scale(6, 0, 1)
   :translate(7.5 / myTextureSize.x, 0.5 / myTextureSize.y)

---@param action auria.wheel.action.slider
---@param popup auria.wheel.action_popup
function api.createPopup(action, popup)
   popup.data = {
      lastValue = vec(0, 0),
   }
   -- model
   local model = popup.model
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

---@param value number
---@param range Vector2
---@param fallback number
---@param offset number
---@param step number
---@return number
local function unmapSliderValue(value, range, fallback, offset, step)
   if range.x == range.y then
      return fallback
   end
   local scale = (range.y - range.x)
   local v = (value - range.x) / scale
   v = v + offset
   if step ~= 0 then
      v = math.round(v * scale / step) / scale * step
   end
   return v
end

---@param action auria.wheel.action.slider
---@param popup auria.wheel.action_popup
---@param mousePos Vector2
---@return Vector2
local function getUnmappedSliderPos(action, popup, mousePos)
   local offset = mousePos - popup.data.mouseStart
   offset = offset / action.backgroundSize
   offset.y = -offset.y
   local value = popup.data.lastValue
   local fallback = action.bgTexture and 0.5 or 1
   local step = action.step
   local values = vec(
      unmapSliderValue(value.x, action.range, fallback, offset.x, step),
      unmapSliderValue(value.y, action.rangeY, fallback, offset.y, step)
   )
   if action.loop then
      return values % 1
   end
   return vec(math.clamp(values.x, 0, 1), math.clamp(values.y, 0, 1))
end

---@param n number
---@param range Vector2
local function clampValueWithRange(n, range)
   return math.clamp(
      n,
      math.min(range.x, range.y),
      math.max(range.x, range.y)
   )
end

---@param action auria.wheel.action.slider
local function clampSliderValues(action)
   action.value = clampValueWithRange(action.value, action.range)
   action.valueY = clampValueWithRange(action.valueY, action.rangeY)
end

---@param action auria.wheel.action.slider
---@param popup auria.wheel.action_popup
function api.popupOpened(action, popup)
   clampSliderValues(action)
   popup.data.lastValue = vec(action.value, action.valueY)
   popup.data.mouseStart = wheel.lib.getMousePos()
end

---@param action auria.wheel.action.slider
---@param popup auria.wheel.action_popup
local function updateSliderValues(action, popup)
   action.value = math.lerp(action.range.x, action.range.y, popup.data.pos.x)
   action.valueY = math.lerp(action.rangeY.x, action.rangeY.y, popup.data.pos.y)
end

---@param action auria.wheel.action.slider
---@param popup auria.wheel.action_popup
function api.popupClosed(action, popup)
   if popup.data.pos then
      updateSliderValues(action, popup)
      popup.data.pos = nil
   end
   popup.data.mouseStart = nil
end

---@param action auria.wheel.action.slider
---@param data auria.wheel.action.render
---@param delta number
function api.actionRender(action, data, delta)
   local popup = data.popup
   if not popup then return end
   if not popup.data.mouseStart then return end
   local newPos = getUnmappedSliderPos(action, popup, wheel.lib.getMousePos())
   if popup.data.pos == newPos then return end
   popup.data.pos = newPos
   if action.valueChange then
      updateSliderValues(action, popup)
      action.valueChange(action.value, action.valueY)
   end
   local pos = popup.data.pos
   local tex = action.bgTexture
   if not tex then
      popup.model.bg:setUVPixels(1 - pos.x, pos.y - 1)
      return
   end
   local modelPos = vec(-pos.x, pos.y - 1) * action.backgroundSize - action.backgroundSize * -0.5
   popup.model.indicator:setPos(modelPos:augmented(0))
end

---@return auria.wheel.action.slider
function Page:newSlider()
   local slider = wheel.newAction("slider", self)
   slider.value = 0
   slider.valueY = 0
   slider.backgroundSize = defaultBgSize
   slider.range = vec(0, 1)
   slider.rangeY = vec(0, 0)
   slider.step = 0
   slider.loop = false
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

---sets range, minimum (x) and maximum (y) of this slider
---@param range Vector2
---@param rangeY? Vector2
---@return auria.wheel.action.slider
function methods:setRange(range, rangeY)
   self.range = range
   self.rangeY = rangeY or vec(0, 0)
   return self
end

---sets spacing between values in slider
---@param step number
---@return auria.wheel.action.slider
function methods:setStep(step)
   self.step = step
   return self
end

---sets function which will be called when slider value changes
---@param func? fun(value: number, valueY: number)
---@return auria.wheel.action.slider
function methods:onValueChange(func)
   self.valueChange = func
   return self
end

---sets value of this slider
---@param value? number
---@param valueY? number
---@return auria.wheel.action.slider
function methods:setValue(value, valueY)
   if value then
      self.value = value
   end
   if valueY then
      self.valueY = valueY
   end
   return self
end

---makes slider loop instead of clamp
---@param loop any
---@return auria.wheel.action.slider
function methods:setLoop(loop)
   self.loop = loop
   return self
end

wheel.newActionType("slider", api)