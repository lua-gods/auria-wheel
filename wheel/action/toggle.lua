local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.page
local Page = wheel.page

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.toggle : auria.wheel.action
---@field toggleFunc (fun(value: boolean))?
local methods = {}
api.methods = methods

---@param action auria.wheel.action
---@param data auria.wheel.action.render
function api.createRenderData(action, data)
   local model = data.model
   local textTask = model.text:getTask("title") --[[@as TextTask]]
   local width = 14
   textTask:setPos(width / 2, 0, 0)
   local offset = client.getTextWidth(textTask:getText() or "") * -0.5
   local bg = wheel.models.toggle_bg:copy("")
   local toggle = wheel.models.toggle:copy("toggle")
   bg:setPos(offset, 0, 0)
   toggle:setPos(offset, 0, 0)
   model.text:addChild(bg):addChild(toggle)

   data.data = {
      pos = 0,
      oldPos = 0,
   }
end

---@param action auria.wheel.action.toggle
function api.press(action)
   action.value = not action.value
   if action.toggleFunc then
      action.toggleFunc(action.value)
   end
end

function api.actionTick(action, data)
   local myData = data.data
   myData.oldPos = myData.pos
end

function api.actionRender(action, data, delta)
   
end

---@return auria.wheel.action.toggle
function Page:newToggle()
   local action = wheel.newAction("toggle", self)
   action.value = false
   return action
end

---@param func? (fun(value: boolean))
---@return auria.wheel.action.toggle
function methods:onToggle(func)
   self.toggleFunc = func
   return self
end

wheel.newActionType("toggle", api)