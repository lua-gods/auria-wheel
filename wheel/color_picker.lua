local wheel = require("./init") ---@class auria.wheel

---@class auria.wheel.page
local Page = wheel.lib.page

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.color_picker : auria.wheel.action
---@field color Vector3
local methods = {}
api.methods = methods

local page = wheel.newPage()

local sliderColor = page:newSlider()
sliderColor:setTitle("Saturation, value")
   :setIconTexture(wheel.lib.texture, vec(24, 0), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(6.5, 0.5), vec(1, 1), "BLURRY")
   :setBackgroundSize(vec(128, 128))
   :setRange(vec(0, 1), vec(0, 1))

local hueSlider = page:newSlider()
hueSlider:setTitle("Hue")
   :setIconTexture(wheel.lib.texture, vec(24, 8), vec(8, 8))
   :setLoop(true)
   :setBackground(wheel.lib.texture, vec(9.5, 0.5), vec(6, 0), "BLURRY")

local redSlider = page:newSlider()
redSlider:setTitle("Red")
   :setIconTexture(wheel.lib.texture, vec(16, 8), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(9.5, 1.5), vec(1, 0), "BLURRY")

local greenSlider = page:newSlider()
greenSlider:setTitle("Green")
   :setIconTexture(wheel.lib.texture, vec(16, 16), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(9.5, 2.5), vec(1, 0), "BLURRY")

local blueSlider = page:newSlider()
blueSlider:setTitle("Blue")
   :setIconTexture(wheel.lib.texture, vec(24, 16), vec(8, 8))
   :setBackground(wheel.lib.texture, vec(9.5, 3.5), vec(1, 0), "BLURRY")

local presetsAction = page:newAction()
presetsAction:setTitle("presets")
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

local colorPreview = page:newAction()
local previewIcon = makeColorIcon()
colorPreview:setIconModel(previewIcon)

local currentColor = vec(1, 1, 1)
local currentColorHsv = vec(0, 0, 1)
local texColor = ""

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

local function updatePreview()
   colorPreview:setTitle("#"..vectors.rgbToHex(currentColor):upper())
   previewIcon.bg:setColor(currentColor)
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
end):onPress(updateTexture)

hueSlider:onValueChange(function(value)
   currentColorHsv.x = value
   updateColor(true)
end)

redSlider:onValueChange(function(value)
   currentColor.r = value
   updateColor()
end):onPress(updateTexture)

greenSlider:onValueChange(function(value)
   currentColor.g = value
   updateColor()
end):onPress(updateTexture)

blueSlider:onValueChange(function(value)
   currentColor.b = value
   updateColor()
end):onPress(updateTexture)

local presetsPage = wheel.newPage()
presetsAction:setPage(presetsPage)

local presetsColors = {
      {"#ff5757", "red"},
      {"#ff7a45", "orange"},
      {"#ffed66", "yellow"},
      {"#bdff66", "lime"},
      {"#5cf761", "green"},
      {"#5ef4ff", "light blue"},
      {"#349fc9", "cyan"},
      {"#4956fc", "blue"},
      {"#a64dff", "purple"},
      {"#ff4dff", "magenta"},
      {"#ffadbc", "pink"},
      {"#69453f", "brown"},
      {"#ffffff", "white"},
      {"#bcbfc4", "light gray"},
      {"#2f2f2f", "dark gray"},
      {"#000000", "black"},
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

---@param action auria.wheel.action.color_picker
function api.press(action)
   currentColor = action.color
   texColor = ""
   updateColor()
end

---creates new color picker
---@return auria.wheel.action.color_picker
function Page:newColorPicker()
   local action = wheel.newAction("color_picker", self)
   action.color = vec(1, 1, 1)
   action:setPage(page)
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

wheel.lib.newActionType("color_picker", api)