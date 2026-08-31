---@class auria.wheel
local mod = {}

---@type auria.wheel.config
mod.conf = require("./conf")
--extra variables and functions used for extending wheel features like custom action types
mod.lib = {}
---@class auria.wheel.page
local Page = {}
Page.__index = Page
mod.lib.page = Page

---@class auria.wheel.action
local Action = {}

local hudModelRoot = models:newPart("", "HUD")
local hudModel = hudModelRoot:newPart("")
hudModelRoot:setOverlay(0, 15)
hudModel:setVisible(false)

local isEnabled = false

do
   local model = models
   for path in (...):gmatch("[^/.]+") do
      model = model[path]
   end
   model:remove()
   ---@type ModelPart
   model = model.model
   mod.lib.models = model -- main models used by library
   for _, v in pairs(mod.lib.models:getChildren()) do
      v:setLight(15, 15)
   end
end

---@type Texture # main texture used by library
mod.lib.texture = textures[(...):gsub(".$", "%1."):gsub("/", ".").."texture"]
local myTextureSize = mod.lib.texture:getDimensions()

---@type auria.wheel.page?
local currentPage = nil
---@type {[auria.wheel.page]: auria.wheel.page.render}
local renderedPages = {}

---@type auria.wheel.page[]
local pageHistory = {}
---@type {[auria.wheel.page]: number}
local pageInHistory = {}

local selectedActionidx = -1
---@type auria.wheel.page
local selectedActionPage = nil

local oldVisibleAnim, visibleAnim = 0, 0

local hudOverlay = hudModel:newSprite("overlay")
local overlayColor = vec(0.2, 0.22, 0.25)
hudOverlay:setTexture(mod.lib.texture, myTextureSize:unpack())
   :setRegion(1, 1)


local leftClickKey = keybinds:of("wheel - Left click", "key.mouse.left")
local RightClickKey = keybinds:of("wheel - Right click", "key.mouse.right")

---@type {[string]: auria.wheel.action_data}
local actionTypes = {}

local blurApplied = nil

local pageAngleOffsets = {
   [1] = math.rad(-90),
   [3] = math.rad(30),
}

function mod.setEnabled(state)
   if state == isEnabled then
      return
   end
   isEnabled = state
   host:setUnlockCursor(state)
end

function mod.isEnabled()
   return isEnabled
end

local f3Key = keybinds:newKeybind('wheel - f3', 'key.keyboard.f3')
do
   local toggleMode = false
   local lastClick = -1
   mod.conf.keybind.press = function()
      if f3Key:isPressed() then return end
      if toggleMode and isEnabled then
         mod.setEnabled(false)
         toggleMode = false
         return true
      end
      mod.setEnabled(true)
      lastClick = client.getSystemTime()
      return true
   end
   mod.conf.keybind.release = function()
      if mod.conf.mode == "HOLD" then
         mod.setEnabled(false)
         return
      elseif mod.conf.mode == "TOGGLE" then
         toggleMode = true
         return
      end
      -- mixed
      local diff = client.getSystemTime() - lastClick
      if diff >= mod.conf.holdTime then
         mod.setEnabled(false)
      else
         toggleMode = true
      end
   end
end

---@return auria.wheel.page
function mod.newPage()
   ---@class auria.wheel.page
   local obj = {
      ---@type auria.wheel.action[]
      actions = {}
   }
   setmetatable(obj, Page)
   return obj
end

---@param page auria.wheel.page
local function setPageRaw(page)
   currentPage = page
end

---@return Vector2
function mod.lib.getMousePos()
   return (client.getMousePos() / client.getWindowSize() - 0.5) * client.getScaledWindowSize()
end

---@generic self
---@param self self
---@return self
function Action:updateModel()
   ---@cast self auria.wheel.action
   if self.renderData then
      self.renderData.update = true
   end
   return self
end

---@generic self
---@param self self
---@param text string
---@return self
function Action:setIconEmoji(text)
   ---@cast self auria.wheel.action
   local model = models:newPart(""):remove()
   local task = model:newText("")
   task:setText(text)
      :scale(2)
      :setAlignment("CENTER")
      :setPos(0, 8, 0)
      :setLight(15, 15)
   self.icon = model
   self.iconRender = function(opacity)
      task:setOpacity(opacity)
   end
   self:updateModel()
   return self
end

---@generic self
---@param self self
---@param texture Texture
---@param pos Vector2
---@param size Vector2
---@return self
function Action:setIconTexture(texture, pos, size)
   ---@cast self auria.wheel.action
   local model = mod.lib.models.icon:copy("")
   model:setPrimaryTexture("CUSTOM", texture)
   local texSize = texture:getDimensions()
   local mat = matrices.mat3()
   mat:scale((size / texSize):augmented(1))
   mat:translate(pos / texSize)
   model:setUVMatrix(mat)
   self.icon = model
   self.iconRender = nil
   self:updateModel()
   return self
end

---@generic self
---@param self self
---@param item ItemStack|Minecraft.itemID|string
---@param displayMode? ItemTask.displayMode
---@return self
function Action:setIconItem(item, displayMode)
   ---@cast self auria.wheel.action
   local model = models:newPart(""):remove()
   local itemTask = model:newItem("")
   itemTask:setItem(item)
   itemTask:setDisplayMode(displayMode or "GUI")
   self.icon = model
   self.iconRender = nil
   self:updateModel()
   return self
end

---sets function that will be run when this action is pressed
---@generic self
---@param self self
---@param func function
---@return self
function Action:onPress(func)
   self.press = func
   return self
end

---sets function that will be run when this action is released
---@generic self
---@param self self
---@param func function
---@return self
function Action:onRelease(func)
   self.release = func
   return self
end

---sets title of this action
---@generic self
---@param self self
---@param text string
---@return self
function Action:setTitle(text)
   ---@cast self auria.wheel.action
   self.title = text
   self:updateModel()
   return self
end

---sets page that will be opened when this action is clicked
---@generic self
---@param self self
---@param page auria.wheel.page
---@return self
function Action:setPage(page)
   self.page = page
   return self
end

---makes action with specified type
---@param myType string
---@param page? auria.wheel.page
---@return auria.wheel.action|any
function mod.newAction(myType, page)
   ---@class auria.wheel.action
   local obj = {
      title = "Hello!",
      ---@type ModelPart
      icon = nil,
      ---@type (fun(opacity: number))?
      iconRender = nil,
      ---@type auria.wheel.page?
      page = nil,
      ---@type function?
      press = nil,
      ---@type function?
      release = nil,
      type = myType,
      ---@type auria.wheel.action.render?
      renderData = nil,
   }
   setmetatable(obj, actionTypes[myType].mt)
   obj:setIconItem("glass_pane")
   if page then
      table.insert(page.actions, obj)
   end
   return obj
end

---@alias auria.wheel.action_data {
---methods: {[string]: function},
---mt: table,
---createPopup: (fun(action: auria.wheel.action, popup: auria.wheel.action_popup)),
---press: (fun(action: auria.wheel.action)),
---popupOpened: (fun(action: auria.wheel.action, popup: auria.wheel.action_popup)),
---popupClosed: (fun(action: auria.wheel.action, popup: auria.wheel.action_popup)),
---actionTick: (fun(action: auria.wheel.action)),
---actionRender: (fun(action: auria.wheel.action, delta: number)),
---createRenderData: (fun(action: auria.wheel.action)),
---updateRenderModel: (fun(action: auria.wheel.action)),
---}

---@param myType string
---@param data auria.wheel.action_data
function mod.lib.newActionType(myType, data)
   local emptyFunc = function() end
   data.press = data.press or emptyFunc
   data.actionTick = data.actionTick or emptyFunc
   data.actionRender = data.actionRender or emptyFunc
   data.createRenderData = data.createRenderData or emptyFunc
   data.updateRenderModel = data.updateRenderModel or emptyFunc
   -- add built in methods
   data.methods = data.methods or {}
   local methods = data.methods
   for i, v in pairs(Action) do
      if not methods[i] then
         methods[i] = v
      end
   end
   local mt = {__index = methods}
   data.mt = mt

   actionTypes[myType] = data
end

---@param action auria.wheel.action
---@return auria.wheel.action_data
function mod.lib.getActionData(action)
   return actionTypes[action.type]
end

mod.lib.newActionType("normal", {})

---@return auria.wheel.action
function Page:newAction()
   return mod.newAction("normal", self)
end

local function getActionsRotScaleAndOffset(count)
   local rotScale = math.pi * 2 / count
   return rotScale, -rotScale / 2 + (pageAngleOffsets[count] or 0)
end

---@returns auria.wheel.action?
function mod.getSelectedAction()
   return selectedActionPage and selectedActionPage.actions[selectedActionidx] or nil
end

---@param page auria.wheel.page
---@return auria.wheel.page.render, boolean
local function getRenderPage(page)
   local data = renderedPages[page]
   if data then
      return data, false
   end
   ---@class auria.wheel.page.render
   data = {
      oldScale = 0,
      scale = 0,
      model = hudModel:newPart(""),
      ---@type {[auria.wheel.action]: auria.wheel.action.render}
      actions = {},
   }
   renderedPages[page] = data
   return data, true
end

---@param page auria.wheel.page
function mod.setPage(page)
   pageHistory = {}
   pageInHistory = {[page] = 1}
   table.insert(pageHistory, page)
   setPageRaw(page)
   local data = getRenderPage(page)
   data.oldScale = 1
   data.scale = 1
end

function mod.previousPage()
   if #pageHistory >= 2 then
      local oldPage = table.remove(pageHistory)
      pageInHistory[oldPage] = (pageInHistory[oldPage] or 0) - 1
      if pageInHistory[oldPage] <= 0 then
         pageInHistory[oldPage] = nil
      end
      local page = pageHistory[#pageHistory]
      setPageRaw(page)
      local data, new = getRenderPage(page)
      if new then
         data.oldScale = 2
         data.scale = 2
      end
   end
end

---@param page auria.wheel.page
function mod.setAndPushToHistory(page)
   table.insert(pageHistory, page)
   pageInHistory[page] = (pageInHistory[page] or 0) + 1
   setPageRaw(page)
end

---creates popup for action
---@param action auria.wheel.action
---@return auria.wheel.action_popup?
function mod.lib.makeActionPopup(action)
   local pageData = getRenderPage(selectedActionPage)
   local actionData = action.renderData
   if not actionData then return end
   local actionTypeData = mod.lib.getActionData(action)
   if not actionTypeData.createPopup then
      return
   end
   if not actionData.popup then
      local model = pageData.model:newPart("")
      ---@class auria.wheel.action_popup
      actionData.popup = {
         model = model,
         visible = 0,
         oldVisible = 0,
         isOpen = false,
         data = {},
      }
      actionTypeData.createPopup(action, actionData.popup)
   end
   local popup = actionData.popup
   if not popup.isOpen then
      popup.isOpen = true
      if actionTypeData.popupOpened then
         actionTypeData.popupOpened(action, actionData.popup)
      end
   end
   return popup
end

---@param action auria.wheel.action
---@param release boolean?
function mod.clickAction(action, release)
   if release then
      if action.release then
         action.release()
      end
      return
   end
   if action.page then
      mod.setAndPushToHistory(action.page)
   end
   mod.lib.getActionData(action).press(action)
   if action.press then
      action.press()
   end
end

---@param page auria.wheel.page
---@param i number
local function makePageAction(page, i)
   local data = getRenderPage(page)
   local action = page.actions[i]

   local model = data.model:newPart("")
   local textGroup = model:newPart("text")
   local textTask = textGroup:newText("title")

   ---@class auria.wheel.action.render
   local myData = {
      model = model,
      scale = 1,
      oldScale = 1,
      text = textTask,
      ---@type auria.wheel.action_popup?
      popup = nil,
      dir = vec(1, 0, 0),
      data = {},
      time = 2,
      update = true,
   }
   action.renderData = myData
   data.actions[action] = myData
   textGroup:setPos(0, -12, 0)
      :setScale(1 / 1.5)
   textTask:setAlignment("CENTER")

   local typeData = mod.lib.getActionData(action)
   typeData.createRenderData(action)
end

---@param page auria.wheel.page
local function rebuildPageActions(page)
   local rotScale, rotOffset = getActionsRotScaleAndOffset(#page.actions)
   for i, action in pairs(page.actions) do
      if not action.renderData then
         makePageAction(page, i)
      end
      local myData = action.renderData
      local rot = i * rotScale + rotOffset
      local dir = vec(-math.sin(rot), math.cos(rot), 0)
      myData.dir = dir
   end
end

function events.tick()
   -- anim
   oldVisibleAnim = visibleAnim
   visibleAnim = math.lerp(visibleAnim, isEnabled and 1 or 0, 0.5)
   -- blur
   local blurToApply = isEnabled and mod.conf.postEffect or nil
   if blurApplied ~= blurToApply then
      blurApplied = blurToApply
      if not pcall(renderer.setPostEffect, renderer, blurToApply) then
         mod.conf.postEffect = nil
         if blurToApply then
            pcall(renderer.setPostEffect, renderer)
         end
      end
   end
   -- disable in gui
   if isEnabled and mod.conf.mode ~= "HOLD" and host:getScreen() then
      mod.setEnabled(false)
   end
   -- skip updating pages when closed
   if (oldVisibleAnim + visibleAnim < 0.05) and not isEnabled then
      return
   end
   -- select
   local isClicked = leftClickKey:isPressed()
   if not isEnabled then
      if isClicked and selectedActionPage then
         mod.clickAction(mod.getSelectedAction(), true)
      end
      selectedActionidx = -1
      selectedActionPage = nil
   elseif not isClicked then
      selectedActionidx = -1
      selectedActionPage = nil
      if currentPage and isEnabled then
         local mousePos = mod.lib.getMousePos()
         getRenderPage(currentPage)
         local dist = mousePos:length()
         if dist > 50 then
            local actionCount = #currentPage.actions
            local angle = math.atan2(mousePos.x, -mousePos.y) - (pageAngleOffsets[actionCount] or 0)
            local i = ((angle / math.pi / 2) % 1) * actionCount
            local center = math.floor(i) + 0.5
            local diff = math.abs(center - i) / actionCount * 360
            local idx = math.floor(i + 1)
            if diff < 70 and currentPage.actions[idx] then
               selectedActionidx = idx
               selectedActionPage = currentPage
            end
         end
      end
   end
   -- preview
   local previewPage
   local selectedAction = mod.getSelectedAction()
   if selectedAction and selectedActionPage == currentPage then
      previewPage = selectedAction.page
      if previewPage then
         getRenderPage(previewPage)
      end
   end
   -- update
   local rendered = 0
   for page, data in pairs(renderedPages) do
      rendered = rendered + 1
      local target = 0
      if page == currentPage then
         target = previewPage and 1.1 or 1
      elseif page == previewPage then
         target = 0.4
      end
      local used = target ~= 0
      if target == 0 and pageInHistory[page] then
         target = 2
      end
      data.oldScale = data.scale
      data.scale = math.lerp(data.scale, target, 0.5)
      local removePage = false
      local removedAnyAction = false
      if not used and math.abs(data.scale - target) < 0.0001 then
         removePage = true
         data.model:remove()
         renderedPages[page] = nil
      end
      for i, action in pairs(page.actions) do
         if action.renderData then
            action.renderData.time = 2
         end
      end
      for action, actionData in pairs(data.actions) do
         local typeData = mod.lib.getActionData(action)
         local popup = actionData.popup
         local myTarget = 1.5
         if action == selectedAction then
            myTarget = 2
            if isClicked and not popup then
               myTarget = 1.9
            end
         end
         actionData.oldScale = actionData.scale
         actionData.scale = math.lerp(actionData.scale, myTarget, 0.5)
         typeData.actionTick(action)
         if popup then
            local popupTarget = 0
            if action == selectedAction and isClicked then
               popupTarget = 1
            end
            popup.oldVisible = popup.visible
            popup.visible = math.lerp(popup.visible, popupTarget, 0.5)
            if popup.visible < 0.0001 then
               popup.model:remove()
               actionData.popup = nil
               popupTarget = 0
            end
            if popupTarget == 0 and popup.isOpen then
               popup.isOpen = false
               if typeData.popupClosed then
                  typeData.popupClosed(action, popup)
               end
            end
         end
         actionData.time = actionData.time - 1
         if removePage or actionData.time <= 0 then
            action.renderData = nil
            actionData.model:remove()
            data.actions[action] = nil
            removedAnyAction = true
         end
      end
      if removedAnyAction and not removePage then
         rebuildPageActions(page)
      end
   end
end

leftClickKey.press = function()
   if not isEnabled then return end
   local action = mod.getSelectedAction()
   if action then
      mod.clickAction(action)
   end
   return true
end
leftClickKey.release = function()
   if not isEnabled then return end
   local action = mod.getSelectedAction()
   if action then
      mod.clickAction(action, true)
   end
end
RightClickKey.press = function()
   if not isEnabled then return end
   mod.previousPage()
   return true
end

---@param action auria.wheel.action
local function updateActionModel(action)
   local data = action.renderData
   if not data then return end

   data.text:setText(action.title)
   if data.model.icon then
      data.model.icon:remove()
   end
   data.model:newPart("icon")
      :addChild(action.icon)

   local typeData = mod.lib.getActionData(action)
   typeData.updateRenderModel(action)
end

---@param page auria.wheel.page
---@param delta number
---@param globalVisible number
local function renderPage(page, delta, globalVisible)
   local data = getRenderPage(page)
   local visible = math.lerp(data.oldScale, data.scale, delta)
   if visible < 0.05 then
      data.model:setVisible(false)
      return
   end
   local opacity = 1 - math.abs(visible - 1)
   opacity = math.clamp(opacity, 0.1, 1)
   opacity = opacity * globalVisible
   data.model:setVisible(true)
      :setScale(math.min(visible, 1) * globalVisible)
      :setOpacity(globalVisible)

   local posScale = math.max(visible, 1)
   posScale = math.lerp(posScale, 1, 0.25) * 80
   local sizeScale = math.clamp(2 - visible, 0, 1)

   for i, action in pairs(page.actions) do
      if not action.renderData then
         rebuildPageActions(page)
      end
      local actionData = action.renderData
      if actionData.update then
         actionData.update = false
         updateActionModel(action)
      end
      local pos = actionData.dir * posScale
      local scale = math.lerp(actionData.oldScale, actionData.scale, delta)
      actionData.model:setPos(pos)
         :setScale(scale * sizeScale)
      actionData.text:setOpacity(opacity)

      if action.iconRender then
         action.iconRender(opacity)
      end
      local popup = actionData.popup
      if popup then
         local myVisible = math.lerp(popup.oldVisible, popup.visible, delta)
         popup.model:setScale(myVisible)
            :setPos(pos - vec(0, 0, 50))
            :setOpacity(myVisible)
      end
      local typeData = mod.lib.getActionData(action)
      typeData.actionRender(action, delta)
   end
end

hudModelRoot.preRender = function(delta)
   local globalVisible = math.lerp(oldVisibleAnim, visibleAnim, delta)
   if globalVisible < 0.05 then
      hudModel:setVisible(false)
      return
   end
   hudModel:setVisible(true)
   local winSize = client.getScaledWindowSize()
   local centerOffset = vec(-winSize.x * 0.5, -winSize.y * 0.5, 0)
   hudModel:setPos(centerOffset)
   hudOverlay:setPos(vec(0, 0, 50) - centerOffset)
      :setScale((winSize / myTextureSize):augmented(0))
      :setColor(overlayColor:augmented(globalVisible * 0.5))
   if currentPage then
      getRenderPage(currentPage)
   end
   for page in pairs(renderedPages) do
      renderPage(page, delta, globalVisible)
   end
end

return mod