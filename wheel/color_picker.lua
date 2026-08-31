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

local color = vec(1, 1, 1)
local colorHsv = vec(0, 0, 1)
local texColor = ""

local function updateTexture()
   local newColor = vectors.rgbToHex(colorHsv)
   if texColor == newColor then
      return
   end
   texColor = newColor
   local tex = wheel.lib.texture
   tex:setPixel(7, 0, vectors.hsvToRGB(colorHsv.x, 1, 1))
      :setPixel(9 , 1, 0, color.g, color.b)
      :setPixel(10, 1, 1, color.g, color.b)
      :setPixel(9 , 2, color.r, 0, color.b)
      :setPixel(10, 2, color.r, 1, color.b)
      :setPixel(9 , 3, color.r, color.g, 0)
      :setPixel(10, 3, color.r, color.g, 1)
   tex:update()
end

---@param fromHsv boolean?
local function updateColor(fromHsv)
   if fromHsv then
      color = vectors.hsvToRGB(colorHsv)
   else
      colorHsv = vectors.rgbToHSV(color)
   end
   sliderColor:setValue(colorHsv.y, colorHsv.z)
   hueSlider:setValue(colorHsv.x)
   redSlider:setValue(color.r)
   greenSlider:setValue(color.g)
   blueSlider:setValue(color.b)

   colorPreview:setTitle("#"..vectors.rgbToHex(color):upper())
   previewIcon.bg:setColor(color)
end

sliderColor:onValueChange(function(value, valueY)
   colorHsv.y = value
   colorHsv.z = valueY
   updateColor(true)
end):onPress(updateTexture)

hueSlider:onValueChange(function(value)
   colorHsv.x = value
   updateColor(true)
end)

redSlider:onValueChange(function(value)
   color.r = value
   updateColor()
end):onPress(updateTexture)

greenSlider:onValueChange(function(value)
   color.g = value
   updateColor()
end):onPress(updateTexture)

blueSlider:onValueChange(function(value)
   color.b = value
   updateColor()
end):onPress(updateTexture)

local presetsPage = wheel.newPage()
presetsAction:setPage(presetsPage)

local presetsColors = {
   {"#88eeff", "blue"},
   {"#ffaaee", "pink"},
   {"#ffffff", "white"},
}

for _, v in ipairs(presetsColors) do
   local action = presetsPage:newAction()
   local myColor = vectors.hexToRGB(v[1])
   action:setIconModel(makeColorIcon(myColor))
      :setTitle(v[2])
      :onPress(function()
         wheel.previousPage()
         color = myColor:copy()
         updateColor()
      end)
end

---@param action auria.wheel.action.color_picker
function api.press(action)
   color = action.color
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

wheel.lib.newActionType("color_picker", api)