local wheel = require("./init") ---@class auria.wheel

---@class auria.wheel.page
local Page = wheel.lib.page

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.color_picker : auria.wheel.action
---@field color Vector3
---@field colorChange? fun(color: Vector3)
---@field colorChangeConfirmed? fun(color: Vector3)
---@field colorChangeFinished? fun(color: Vector3)
local methods = {}
api.methods = methods

local mainPage = wheel.newPage()
mainPage:setTitle("Color picker")

local sliderColor = mainPage:newSlider()
sliderColor:setTitle("Saturation, value")
   :setIconTexture(wheel.lib.texture, vec(24, 0), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(6.5, 0.5), vec(1, 1), "BLURRY")
   :setBackgroundSize(vec(128, 128))
   :setRange(vec(0, 1), vec(0, 1))

local hueSlider = mainPage:newSlider()
hueSlider:setTitle("Hue")
   :setIconTexture(wheel.lib.texture, vec(24, 8), vec(8, 8))
   :setLoop(true)
   :setBackground(wheel.lib.texture, vec(9.5, 0.5), vec(6, 0), "BLURRY")

local redSlider = mainPage:newSlider()
redSlider:setTitle("Red")
   :setIconTexture(wheel.lib.texture, vec(16, 8), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(9.5, 1.5), vec(1, 0), "BLURRY")

local greenSlider = mainPage:newSlider()
greenSlider:setTitle("Green")
   :setIconTexture(wheel.lib.texture, vec(16, 16), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(9.5, 2.5), vec(1, 0), "BLURRY")

local blueSlider = mainPage:newSlider()
blueSlider:setTitle("Blue")
   :setIconTexture(wheel.lib.texture, vec(24, 16), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(9.5, 3.5), vec(1, 0), "BLURRY")

local presetsAction = mainPage:newAction()
presetsAction:setTitle("Presets")
   :setIconTexture(wheel.lib.texture, vec(16, 24), vec(8, 8))

---@param color Vector3?
---@return ModelPart
local function makeColorIcon(color)
   local og = wheel.lib.models.color_icon
   local model = models:newPart(""):remove()
   model:addChild(og.bg:copy("bg"))
   model:addChild(og.outline:copy("outline"))
   if color then
      model.bg:setColor(color)
   end
   return model
end

local colorPreview = mainPage:newAction()
local previewIcon = makeColorIcon()
colorPreview:setIconModel(previewIcon)

local currentColor = vec(1, 1, 1)
local currentColorHsv = vec(0, 0, 1)
local texColor = ""

---@type auria.wheel.action.color_picker?
local currentAction = nil

local colorEventsData = {
   {"colorChange", ""},
   {"colorChangeConfirmed", ""},
   {"colorChangeFinished", ""},
}

---@param i number
local function callEvent(i)
   if not currentAction then return end
   local colorHex = vectors.rgbToHex(currentColor)
   local color = vectors.hexToRGB(colorHex)
   currentAction.color = color:copy()
   for k = 1, i do
      local eventData = colorEventsData[k]
      if eventData[2] ~= colorHex then
         eventData[2] = colorHex
         ---@type function?
         local func = currentAction[ eventData[1] ]
         if func then
            func(color:copy())
         end
      end
   end
end

local function callEvent2()
   callEvent(2)
end

local function updateTexture()
   local newColor = vectors.rgbToHex(currentColorHsv)
   if texColor == newColor then
      return
   end
   texColor = newColor
   local tex = wheel.lib.texture
   tex:setPixel(7, 0, vectors.hsvToRGB(currentColorHsv.x, 1, 1))
      :setPixel(9 , 1, 0, currentColor.g, currentColor.b)
      :setPixel(10, 1, 1, currentColor.g, currentColor.b)
      :setPixel(9 , 2, currentColor.r, 0, currentColor.b)
      :setPixel(10, 2, currentColor.r, 1, currentColor.b)
      :setPixel(9 , 3, currentColor.r, currentColor.g, 0)
      :setPixel(10, 3, currentColor.r, currentColor.g, 1)
   tex:update()
end

---@param color? Vector3
local function updatePreview(color)
   color = color or currentColor
   colorPreview:setTitle("#"..vectors.rgbToHex(color):upper())
   previewIcon.bg:setColor(color)
end

---@param fromHsv boolean?
local function updateColor(fromHsv)
   if fromHsv then
      currentColor = vectors.hsvToRGB(currentColorHsv)
   else
      currentColorHsv = vectors.rgbToHSV(currentColor)
   end
   sliderColor:setValue(currentColorHsv.y, currentColorHsv.z)
   hueSlider:setValue(currentColorHsv.x)
   redSlider:setValue(currentColor.r)
   greenSlider:setValue(currentColor.g)
   blueSlider:setValue(currentColor.b)
   updatePreview()
end

sliderColor:onValueChange(function(value, valueY)
   currentColorHsv.y = value
   currentColorHsv.z = valueY
   updateColor(true)
   callEvent(1)
end):onPress(updateTexture):onRelease(callEvent2)

hueSlider:onValueChange(function(value)
   currentColorHsv.x = value
   updateColor(true)
   callEvent(1)
end):onRelease(callEvent2)

redSlider:onValueChange(function(value)
   currentColor.r = value
   updateColor()
   callEvent(1)
end):onPress(updateTexture):onRelease(callEvent2)

greenSlider:onValueChange(function(value)
   currentColor.g = value
   updateColor()
   callEvent(1)
end):onPress(updateTexture):onRelease(callEvent2)

blueSlider:onValueChange(function(value)
   currentColor.b = value
   updateColor()
   callEvent(1)
end):onPress(updateTexture):onRelease(callEvent2)

colorPreview:onPress(function()
   callEvent(3)
end)

local presetsPage = wheel.newPage()
presetsPage:setGroupSize(8)

presetsAction:setPage(presetsPage)

local presetsColors = {
      {"#ff5757", "Red"},
      {"#ff7a45", "Orange"},
      {"#ffed66", "Yellow"},
      {"#bdff66", "Lime"},
      {"#5cf761", "Green"},
      {"#5ef4ff", "Light blue"},
      {"#349fc9", "Cyan"},
      {"#4956fc", "Blue"},
      {"#a64dff", "Purple"},
      {"#ff4dff", "Magenta"},
      {"#ffadbc", "Pink"},
      {"#69453f", "Brown"},
      {"#ffffff", "White"},
      {"#bcbfc4", "Light gray"},
      {"#2f2f2f", "Dark gray"},
      {"#000000", "Black"},
   }

for _, v in ipairs(presetsColors) do
   local action = presetsPage:newAction()
   local myColor = vectors.hexToRGB(v[1])
   action:setIconModel(makeColorIcon(myColor))
      :setTitle(v[2])
      :onPress(function()
         wheel.previousPage()
         currentColor = myColor:copy()
         updateColor()
      end)
end

mainPage:onClose(function()
   callEvent(3)
end)

---@param action auria.wheel.action.color_picker
function api.press(action)
   currentColor = action.color:copy()
   texColor = ""
   local hex = vectors.rgbToHex(currentColor)
   for i, v in pairs(colorEventsData) do
      v[2] = hex
   end
   currentAction = action
   presetsPage:setCurrentGroup(1)
   updateColor()
end

---@param action auria.wheel.action.color_picker
function api.select(action)
   updatePreview(action.color)
end

---creates new color picker
---@return auria.wheel.action.color_picker
function Page:newColorPicker()
   local action = wheel.newAction("color_picker", self)
   action.color = vec(1, 1, 1)
   action:setPage(mainPage)
      :setTitle("Color")
      :setIconTexture(wheel.lib.texture, vec(16, 24), vec(8, 8))
   return action
end

---sets color of color picker, you can use string to set it from hex value
---@param color Vector3|string
---@return auria.wheel.action.color_picker
function methods:setColor(color)
   if type(color) == "string" then
      self.color = vectors.hexToRGB(color)
   else
      self.color = color
   end
   return self
end

---sets function with will be called when color changed during sliding slider
---@param func? fun(color: Vector3)
---@return auria.wheel.action.color_picker
function methods:onColorChange(func)
   self.colorChange = func
   return self
end

---sets function with will be called when color changed after finishing sliding slider
---might be useful if you do some slower operation with color such as updating texture
---@param func? fun(color: Vector3)
---@return auria.wheel.action.color_picker
function methods:onColorChangeConfirmed(func)
   self.colorChangeConfirmed = func
   return self
end

---sets function with will be called when color changed after closing color picker
---might be useful if you do some really slower operation with color
---or you dont need it instantly
---@param func? fun(color: Vector3)
---@return auria.wheel.action.color_picker
function methods:onColorChangeFinished(func)
   self.colorChangeFinished = func
   return self
end

wheel.lib.newActionType("color_picker", api)