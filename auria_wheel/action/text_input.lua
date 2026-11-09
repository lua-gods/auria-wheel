local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.action_maker
local ActionMaker = wheel.actions

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.text_input : auria.wheel.action
---@field text string
---@field textChange fun(text: string, oldText: string)
---@field textChangeFinished fun(text: string, oldText: string)
---@field defaultText string?
---@field defaultTextSize Vector2?
---@field charLimit number?
---@field maxLines number?
local methods = {}
api.methods = methods

local dot2width = client.getTextWidth("..")
---@param text string
---@return Vector2
local function getRealTextSize(text)
   text = "."..text:gsub("\n", ".\n.").."."
   local size = client.getTextDimensions(text)
   size.x = size.x - dot2width
   return size
end

---@param action auria.wheel.action.text_input
local function updateModel(action)
   local renderData = action.renderData
   if not renderData then return end
   local popup = renderData.popup
   if not popup then return end
   local model = popup.data.model
   local size = getRealTextSize(action.text)
   if action.defaultTextSize then
      size = vec(
         math.max(size.x, action.defaultTextSize.x),
         math.max(size.y, action.defaultTextSize.y)
      )
   end
   size = (size / 2):ceil() * 2
   size = size + vec(12, 6)
   if popup.data.bgSize ~= size then
      popup.data.bgSize = size
      if popup.data.outline then
         popup.data.outline:remove()
      end
      local outline = wheel.lib.makeNineslice(
         wheel.lib.texture,
         vec(8, 32, 5, 5),
         2,
         size
      )
      model:addChild(outline)
      popup.data.outline = outline
   end

   if action.text == "" and action.defaultText then
      popup.data.textTask:setText(toJson{text = action.defaultText, color = "gray"})
   else
      popup.data.textTask:setText(toJson{text = action.text})
   end
   model:setPos(vec(size.x, size.y, 0) * 0.5)

   local lineSize = getRealTextSize(action.text:match("[^\n]*$"))
   model.cursor:setPos(-lineSize.x, -size.y, 0)
end

---@param action auria.wheel.action.text_input
---@param popup auria.wheel.action_popup
function api.createPopup(action, popup)
   local model = popup.model:newPart("model")
   local cursor = wheel.lib.models.text_cursor:copy("cursor")
   model:addChild(cursor)
   local textTask = model:newText("text")
   textTask:setLight(15, 15)
      :setPos(-6, -4, -1)
   popup.data = {
      model = model,
      textTask = textTask,
      blinkTime = 0,
      bgSize = vec(-1, -1),
   }
   popup.pos = vec(0, 24, 0)
end

---@param action auria.wheel.action.text_input
---@param popup auria.wheel.action_popup
function api.popupOpened(action, popup)
   updateModel(action)
end

function api.press(action)
   local popup = wheel.lib.makeActionPopup(action, true)
   popup.data.blinkTime = -12
   wheel.lib.setInputAction(action)
end

function api.release(action)
   wheel.lib.makeActionPopup(action, true)
end

function api.select(action)
   wheel.lib.makeActionPopup(action, true)
end

---@param action auria.wheel.action.text_input
---@param state boolean
function api.textInputChanged(action, state)
   local popup = wheel.lib.makeActionPopup(action, true)
   if state then
      popup.data.prevText = action.text
   else
      local prevText = popup.data.prevText
      if prevText and action.text ~= prevText and action.textChangeFinished then
         action.textChangeFinished(action.text, prevText)
      end
   end
end

---@param action auria.wheel.action.text_input
---@param text string
local function updateText(action, text)
   local oldText = action.text
   if oldText == text then
      return
   end
   if action.charLimit and #text > action.charLimit then
      local diff = #text - #oldText
      if diff > 5 then
         text = text:sub(1, action.charLimit)
      else
         return
      end
   end
   if action.maxLines then
      local i = action.maxLines
      text = text:gsub("\n", function()
         i = i - 1
         return i > 0 and "\n" or ""
      end)
   end
   action.text = text
   if action.textChange then
      action.textChange(text, oldText)
   end
   updateModel(action)
end

---@param action auria.wheel.action.text_input
---@param key Minecraft.keyID
---@param modifiers number
---@return boolean
function api.keyPressed(action, key, modifiers)
   local renderData = action.renderData
   if not renderData then return end
   local popup = renderData.popup
   if not popup then return end
   popup.data.blinkTime = -12
   if key == 257 then
      if action.maxLines == 1 then
         wheel.lib.setInputAction()
      else
         updateText(action, action.text.."\n")
      end
   elseif key == 259 then
      updateText(action, action.text:gsub("[\x00-\x7F\xC2-\xF4][\x80-\xBF]*$", "", 1))
   elseif key == 67 and modifiers == 2 then
      host:setClipboard(action.text)
   elseif key == 86 and modifiers == 2 then
      updateText(action, action.text .. host:getClipboard())
   elseif (
      (key >= 340 and key <= 342) or
      (key >= 0 and key <= 255)
   ) then
      return true
   end
end

---@param action auria.wheel.action.text_input
---@param char string
function api.charTyped(action, char)
   local renderData = action.renderData
   if not renderData then return end
   local popup = renderData.popup
   if not popup then return end
   popup.data.blinkTime = -12
   updateText(action, action.text..char)
end

---@param action auria.wheel.action.text_input
function api.actionTick(action)
   local renderData = action.renderData
   if not renderData then return end
   local popup = renderData.popup
   if not popup then return end
   local cursorVisible = false
   local inputAction = wheel.lib.getInputAction()
   if action == inputAction then
      local blinkTime = popup.data.blinkTime + 1
      if blinkTime >= 10 then
         blinkTime = -10
      end
      cursorVisible = blinkTime <= 0
      popup.data.blinkTime = blinkTime
   end
   popup.data.model.cursor:setVisible(cursorVisible)
end

---creates new text input
---@return auria.wheel.action.text_input
function ActionMaker:newTextInput()
   local action = wheel.lib.newAction("text_input", self)
   action.text = ""
   return action
end

---sets current text
---@param text string
---@return auria.wheel.action.text_input
function methods:setText(text)
   self.text = text
   updateModel(self)
   return self
end


---sets function with will be called when any text is changed
---@param func fun(text: string, oldText: string)
---@return auria.wheel.action.text_input
function methods:onTextChange(func)
   self.textChange = func
   return self
end

---sets function with will be called when editing text is finished
---@param func fun(text: string, oldText: string)
---@return auria.wheel.action.text_input
function methods:onTextChangeFinished(func)
   self.textChangeFinished = func
   return self
end

---sets default text when no text is typed, doesnt affect text change events
---@param text string?
---@return auria.wheel.action.text_input
function methods:setDefaultText(text)
   self.defaultText = text
   if text then
      self.defaultTextSize = getRealTextSize(text)
   else
      self.defaultTextSize = nil
   end
   return self
end

---sets max amount of characters
---@param limit number?
---@return auria.wheel.action.text_input
function methods:setCharLimit(limit)
   self.charLimit = limit
   return self
end

---sets maximum number of lines text can have
---@param limit number?
---@return auria.wheel.action.text_input
function methods:setLineLimit(limit)
   self.maxLines = limit
   return self
end

wheel.lib.newActionType("text_input", api)