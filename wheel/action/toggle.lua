local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.page
local Page = wheel.lib.page

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.toggle : auria.wheel.action
---@field value boolean
---@field toggleFunc (fun(value: boolean))?
local methods = {}
api.methods = methods

---@param action auria.wheel.action.toggle
---@param data auria.wheel.action.render
function api.createRenderData(action, data)
   local model = data.model
   local textTask = model.text:getTask("title") --[[@as TextTask]]
   local width = 14
   textTask:setPos(width / 2, 0, 0)
   local offset = client.getTextWidth(textTask:getText() or "") * -0.5
   local bg = wheel.lib.models.toggle_bg:copy("")
   local toggle = wheel.lib.models.toggle:copy("toggle")
   bg:setPos(offset, 0, 0)
   toggle:setPos(offset, 0, 0)
   model.text:addChild(bg):addChild(toggle)

   local pos = action.value and 1 or 0
   data.data = {
      pos = pos,
      oldPos = pos,
      vel = 0,
      offset = offset,
   }
end

---@param action auria.wheel.action.toggle
function api.press(action)
   action.value = not action.value
   if action.toggleFunc then
      action.toggleFunc(action.value)
   end
end

---@param action auria.wheel.action.toggle
---@param data auria.wheel.action.render
function api.actionTick(action, data)
   local myData = data.data
   myData.oldPos = myData.pos
   local target = action.value and 1 or 0
   myData.vel = myData.vel * 0.25 + (target - myData.pos) * 0.75
   myData.pos = myData.pos + myData.vel
end

function api.actionRender(action, data, delta)
   local myData = data.data
   local pos = math.lerp(myData.oldPos, myData.pos, delta)
   data.model.text.toggle:setPos(myData.offset - pos * 4, 0)
end

---creates new toggle
---@return auria.wheel.action.toggle
function Page:newToggle()
   local action = wheel.newAction("toggle", self)
   action.value = false
   return action
end

---sets function that will be run when this toggle is toggled
---@param func? (fun(value: boolean))
---@return auria.wheel.action.toggle
function methods:onToggle(func)
   self.toggleFunc = func
   return self
end

---sets this toggle's toggle state
---@param value boolean
---@return auria.wheel.action.toggle
function methods:setToggled(value)
   self.value = value
   return self
end

wheel.lib.newActionType("toggle", api)