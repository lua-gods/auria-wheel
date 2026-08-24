---@class auria.wheel
local mod = {}

mod.blurPostEffect = "blur"
local blurApplied = nil

---@class auria.wheel.page
local Page = {}
Page.__index = Page
mod.page = Page

---@class auria.wheel.action
local Action = {}
Action.__index = Action

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
   mod.models = model -- main models used by library
   for _, v in pairs(mod.models:getChildren()) do
      v:setLight(15, 15)
   end
end

---@type Texture # main texture used by library
mod.texture = textures[(...):gsub(".$", "%1."):gsub("/", ".").."texture"]
local myTextureSize = mod.texture:getDimensions()

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
hudOverlay:setTexture(mod.texture, myTextureSize:unpack())
   :setRegion(1, 1)

local keybind = keybinds:fromVanilla("figura.config.action_wheel_button")
-- local keybind = keybinds:of("Open wheel", "key.keyboard.v")
keybind.press = function()
   isEnabled = true
   host:setUnlockCursor(true)
   return true
end
keybind.release = function()
   if isEnabled then
      host:setUnlockCursor(false)
   end
   isEnabled = false
end
local leftClickKey = keybinds:of("Left click", "key.mouse.left")
local RightClickKey = keybinds:of("Right click", "key.mouse.right")

---@types {[string]: auria.wheel.action_data}
local actionTypes = {}

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

function Page:rebuildActions()
   if renderedPages[self] then
      renderedPages[self].rebuildActions = true
   end
end

local function getMousePos()
   return (client.getMousePos() / client.getWindowSize() - 0.5) * client.getScaledWindowSize()
end

---@generic self
---@param self self
---@param text string
---@return self
function Action:setIconEmoji(text)
   local model = models:newPart(""):remove()
   local task = model:newText("")
   task:setText(text)
      :scale(2)
      :setPos(8, 8, 0)
      :setLight(15, 15)
   self.icon = model
   self.iconRender = function(opacity)
      task:setOpacity(opacity)
   end
   return self
end

---@generic self
---@param self self
---@param texture Texture
---@param pos Vector2
---@param size Vector2
---@return self
function Action:setIconTexture(texture, pos, size)
   local model = mod.models.icon:copy("")
   model:setPrimaryTexture("CUSTOM", texture)
   local texSize = texture:getDimensions()
   local mat = matrices.mat3()
   mat:scale((size / texSize):augmented(1))
   mat:translate(pos / texSize)
   model:setUVMatrix(mat)
   self.icon = model
   self.iconRender = nil
   return self
end

---@generic self
---@param self self
---@param item ItemStack|Minecraft.itemID|string
---@param displayMode? ItemTask.displayMode
---@return self
function Action:setIconItem(item, displayMode)
   local model = models:newPart(""):remove()
   local itemTask = model:newItem("")
   itemTask:setItem(item)
   itemTask:setDisplayMode(displayMode or "GUI")
   self.icon = model
   self.iconRender = nil
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
   }
   setmetatable(obj, Action)
   Action:setIconItem("glass_pane")
   if page then
      table.insert(page.actions, obj)
      page:rebuildActions()
   end
   return obj
end

---@alias auria.wheel.action_data {
---methods: {[string]: function},
---mt: table,
---makePopup: (fun(action: auria.wheel.action, model: ModelPart)),
---}

---@param myType string
---@param data auria.wheel.action_data
function mod.newActionType(myType, data)
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
function mod.getActionData(action)
   return actionTypes[action.type]
end

mod.newActionType("normal", {methods = {}})

---@return auria.wheel.action
function Page:newAction()
   return mod.newAction("normal", self)
end

local function getActionsRotScaleAndOffset(count)
   local rotScale = math.pi * 2 / count
   return rotScale, -rotScale / 2
end

---@returns auria.wheel.action?
local function getSelectedAction()
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
      ---@type auria.wheel.action.render[]
      actions = {},
      rebuildActions = true,
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

---creates popup for currently seelcted action
local function makeActionPopup()
   local action = getSelectedAction()
   local pageData = getRenderPage(selectedActionPage)
   local actionData = pageData.actions[selectedActionidx]
   if not actionData then return end
   if actionData.popup then return end
   local actionTypeData = mod.getActionData(action)
   if not actionTypeData.makePopup then
      return
   end
   local model = pageData.model:newPart("")
   actionTypeData.makePopup(action, model)
   ---@class auria.wheel.action_popup
   actionData.popup = {
      model = model,
      visible = 0,
      oldVisible = 0,
   }
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
   elseif action == getSelectedAction() then
      makeActionPopup()
   end
   if action.press then
      action.press()
   end
end

function events.tick()
   -- anim
   oldVisibleAnim = visibleAnim
   visibleAnim = math.lerp(visibleAnim, isEnabled and 1 or 0, 0.5)
   -- blur
   local blurToApply = isEnabled and mod.blurPostEffect or nil
   if blurApplied ~= blurToApply then
      blurApplied = blurToApply
      if not pcall(renderer.setPostEffect, renderer, blurToApply) then
         mod.blurPostEffect = nil
         if blurToApply then
            pcall(renderer.setPostEffect, renderer)
         end
      end
   end
   -- skip updating pages when closed
   if (oldVisibleAnim + visibleAnim < 0.05) and not isEnabled then
      return
   end
   -- select
   local isClicked = leftClickKey:isPressed()
   if not isEnabled then
      if isClicked and selectedActionPage then
         mod.clickAction(getSelectedAction(), true)
      end
      selectedActionidx = -1
      selectedActionPage = nil
   elseif not isClicked then
      selectedActionidx = -1
      selectedActionPage = nil
      if currentPage and isEnabled then
         local mousePos = getMousePos()
         getRenderPage(currentPage)
         local actionCount = #currentPage.actions
         local angle = math.atan2(mousePos.x, -mousePos.y)
         local dist = mousePos:length()
         if dist > 50 then
            selectedActionidx = math.floor(((angle / math.pi / 2) % 1) * actionCount) + 1
            selectedActionPage = currentPage
         end
      end
   end
   -- preview
   local previewPage
   local selectedAction = getSelectedAction()
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
      for i, actionData in pairs(data.actions) do
         local action = page.actions[i]
         local myTarget = 0
         if action == selectedAction then
            myTarget = 1
         end
         actionData.oldSelected = actionData.selected
         actionData.selected = math.lerp(actionData.selected, myTarget, 0.5)
         local popup = actionData.popup
         if popup then
            if not isClicked then
               myTarget = 0
            end
            popup.oldVisible = popup.visible
            popup.visible = math.lerp(popup.visible, myTarget, 0.5)
            if popup.visible < 0.0001 then
               popup.model:remove()
               actionData.popup = nil
            end
         end
      end
      if not used and math.abs(data.scale - target) < 0.0001 then
         data.model:remove()
         renderedPages[page] = nil
      end
   end
end

leftClickKey.press = function()
   if not isEnabled then return end
   local action = getSelectedAction()
   if action then
      mod.clickAction(action)
   end
   return true
end
leftClickKey.release = function()
   if not isEnabled then return end
   local action = getSelectedAction()
   if action then
      mod.clickAction(action, true)
   end
end
RightClickKey.press = function()
   if not isEnabled then return end
   mod.previousPage()
   return true
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
   if data.rebuildActions then
      data.rebuildActions = false
      data.model:remove()
      data.model = hudModel:newPart("")
      for i, action in ipairs(page.actions) do
         local model = data.model:newPart("")
         model:addChild(action.icon)
         local textTask = model:newText("title")
         ---@class auria.wheel.action.render
         data.actions[i] = {
            model = model,
            selected = 0,
            oldSelected = 0,
            text = textTask,
            ---@type auria.wheel.action_popup?
            popup = nil,
         }
         textTask:setText(action.title)
            :setPos(0, -12, 0)
            :setAlignment("CENTER")
            :setScale(1 / 1.5)
      end
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

   local rotScale, rotOffset = getActionsRotScaleAndOffset(#data.actions)
   for i, actionData in pairs(data.actions) do
      local rot = i * rotScale + rotOffset
      local pos = vec(-math.sin(rot), math.cos(rot), 0) * posScale
      local selected = math.lerp(actionData.oldSelected, actionData.selected, delta)
      actionData.model:setPos(pos)
         :setScale((1.5 + selected * 0.5) * sizeScale)
      actionData.text:setOpacity(opacity)

      local action = page.actions[i]
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