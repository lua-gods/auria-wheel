local wheel = require("../core") ---@class auria.wheel
---@class auria.wheel.action_maker
local ActionMaker = wheel.actions

---@type auria.wheel.action_data
local api = {}

---@class auria.wheel.action.toggle : auria.wheel.action
---@field value boolean
---@field toggleFunc (fun(value: boolean))?
local methods = {}
api.methods = methods

---@param action auria.wheel.action.toggle
function api.createRenderData(action)
   local data = action.renderData
   local model = data.model
   local bg = wheel.lib.models.toggle_bg:copy("bg")
   local toggle = wheel.lib.models.toggle:copy("toggle")
   model.text:addChild(bg):addChild(toggle)

   local pos = action.value and 1 or 0
   data.data = {
      pos = pos,
      oldPos = pos,
      vel = 0,
      offset = 0,
   }
end

---@param action auria.wheel.action.toggle
function api.updateRenderModel(action)
   local data = action.renderData
   local model = data.model
   local textTask = model.text:getTask("title") --[[@as TextTask]]
   local width = 14
   local offset = client.getTextWidth(textTask:getText() or "") * -0.5
   offset = math.floor(offset)
   textTask:setPos(width / 2, 0, 0)
   model.text.bg:setPos(offset, 0, 0)
   data.data.offset = offset
end

---@param action auria.wheel.action.toggle
function api.press(action)
   action.value = not action.value
   if action.toggleFunc then
      action.toggleFunc(action.value)
   end
end

---@param action auria.wheel.action.toggle
function api.actionTick(action)
   local myData = action.renderData.data
   myData.oldPos = myData.pos
   local target = action.value and 1 or 0
   myData.vel = myData.vel * 0.25 + (target - myData.pos) * 0.75
   myData.pos = myData.pos + myData.vel
end

function api.actionRender(action, delta)
   local data = action.renderData
   local myData = data.data
   local pos = math.lerp(myData.oldPos, myData.pos, delta)
   data.model.text.toggle:setPos(myData.offset - pos * 4, 0)
end

---creates new toggle
---@return auria.wheel.action.toggle
function ActionMaker:newToggle()
   local action = wheel.lib.newAction("toggle", self)
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