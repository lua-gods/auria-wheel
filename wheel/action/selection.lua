local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.page
local Page = wheel.lib.page

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.selection : auria.wheel.action
---@field choices string[]
---@field value number
---@field valueChange (fun(i: number, str: string))?
---@field alueChangeFinish (fun(i: number, str: string))?
local methods = {}
api.methods = methods

---@param obj auria.wheel.action.selection.popup_choice|table
---@param selected boolean
local function updateChoiceModel(obj, selected)
   obj.task:setText(toJson{
      text = obj.text,
      color = selected and "white" or "gray"
   })
end

---@param action auria.wheel.action.selection
local function updateIndicatorPos(action)
   if not action.renderData then return end
   local popup = action.renderData.popup
   if not popup then return end
   popup.data.indicator:setPos(0, (action.value) * -10, 0)
end

---@param action auria.wheel.action.selection
---@param v number
---@return number
local function clampValue(action, v)
   return math.clamp(v, 1, #action.choices)
end

---@param action auria.wheel.action.selection
---@param popup auria.wheel.action_popup
function api.createPopup(action, popup)
   action.value = clampValue(action, action.value)
   local model = popup.model:newPart("")

   local indicator = wheel.lib.models.selection_indicator:copy("indicator")
   indicator:light(15, 15)
      :moveTo(model)

   local choices = {}
   local maxWidth = 16
   for i, text in ipairs(action.choices) do
      local width = client.getTextWidth(text)
      maxWidth = math.max(maxWidth, width)
      local task = model:newText("a"..i)
         :setPos(-10, (i - 1) * -10 - 4, 0)
      ---@class auria.wheel.action.selection.popup_choice
      local obj = {
         task = task,
         text = text,
      }
      choices[i] = obj
      updateChoiceModel(obj, i == action.value)
   end

   local size = vec(maxWidth + 16, #action.choices * 10 + 6)
   local outline = wheel.lib.makeNineslice(
      wheel.lib.texture,
      vec(8, 32, 5, 5),
      2,
      size
   )
   model:addChild(outline)
   model:setPos(size:augmented(2) * 0.5)
   -- data
   popup.data = {
      startValue = 0,
      lastValue = action.value,
      choices = choices,
      indicator = indicator,
   }
   -- update
   updateIndicatorPos(action)
end

function api.press(action)
   wheel.lib.makeActionPopup(action)
end

---@param action auria.wheel.action.selection
---@param popup auria.wheel.action_popup
---@param mousePos number
---@return number
local function getNewValue(action, popup, mousePos)
   local offset = mousePos - popup.data.mouseStart
   local v = popup.data.startValue
   return clampValue(action, v + math.round(offset / 10))
end

---@param action auria.wheel.action.selection
---@param popup auria.wheel.action_popup
function api.popupOpened(action, popup)
   action.value = clampValue(action, action.value)
   popup.data.startValue = action.value
   popup.data.mouseStart = wheel.lib.getMousePos().y
end

---@param action auria.wheel.action.selection
---@param popup auria.wheel.action_popup
function api.popupClosed(action, popup)
   if popup.data.startValue ~= action.value then
      if action.valueChangeFinish then
         action.valueChangeFinish(action.value, action.choices[action.value])
      end
   end
   popup.data.mouseStart = nil
end

---@param action auria.wheel.action.selection
---@param delta number
function api.actionRender(action, delta)
   local popup = action.renderData.popup
   if not popup then return end
   if not popup.data.mouseStart then return end
   local newValue = getNewValue(action, popup, wheel.lib.getMousePos().y)
   if action.value == newValue then return end
   updateChoiceModel(popup.data.choices[action.value], false)
   updateChoiceModel(popup.data.choices[newValue], true)
   action.value = newValue
   updateIndicatorPos(action)
   if action.valueChange then
      action.valueChange(action.value, action.choices[action.value])
   end
end

---creates new selection
---@return auria.wheel.action.selection
function Page:newSelection()
   local obj = wheel.newAction("selection", self)
   obj.value = 0
   obj.choices = {}
   return obj
end

---sets function which will be called when selection changes
---@param func? fun(i: number, str: string)
---@return auria.wheel.action.selection
function methods:onValueChange(func)
   self.valueChange = func
   return self
end

---sets function which will be called when selection changes
---@param func? fun(i: number, str: string)
---@return auria.wheel.action.selection
function methods:onValueChangeFinish(func)
   self.valueChangeFinish = func
   return self
end

---sets value of this selection
---@param value number|string
---@return auria.wheel.action.selection
function methods:setValue(value)
   if type(value) == "string" then
      self.value = 1
      for i, v in pairs(self.choices) do
         if v == value then
            self.value = i
         end
      end
   else
      self.value = value
   end
   self.value = clampValue(self, self.value)
   return self
end

---@param tbl string[]
---@return auria.wheel.action.selection
function methods:setChoices(tbl)
   self.choices = tbl
   return self
end

wheel.lib.newActionType("selection", api)