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

local breadcrumbsModel = hudModel:newPart("")
local breadcrumbLen = 0
local breadcrumbOldLen = 0
---@type auria.wheel.breadcrumb[]
local breadcrumbs = {}
local breadcrumbsEllipsis = breadcrumbsModel:newText("")
local breadcrumbsEllipsisWidth = 0
do
   local text = "..."
   breadcrumbsEllipsis:setText(text)
   breadcrumbsEllipsisWidth = client.getTextWidth(text) + 12
end

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
      actions = {},
      ---@type function?
      openFunc = nil,
      ---@type function?
      closeFunc = nil,
      ---@type number?
      groupSize = nil,
      ---@type number
      currentGroup = 1,
   }
   setmetatable(obj, Page)
   return obj
end

---sets function with will be run when page is opened
---@param func function
---@return auria.wheel.page
function Page:onOpen(func)
   self.openFunc = func
   return self
end

---sets function with will be run when page is closed
---@param func function
---@return auria.wheel.page
function Page:onClose(func)
   self.closeFunc = func
   return self
end

---@param page? auria.wheel.page
local function setPageRaw(page)
   if currentPage and currentPage.closeFunc then
      currentPage.closeFunc()
   end
   currentPage = page
   if currentPage and currentPage.openFunc then
      currentPage.openFunc()
   end
end

---@return Vector2
function mod.lib.getMousePos()
   return (client.getMousePos() / client.getWindowSize() - 0.5) * client.getScaledWindowSize()
end

---@param tex Texture
---@param pos Vector2
---@param size Vector2
function mod.lib.makeUVMat(tex, pos, size)
   local texSize = tex:getDimensions()
   local mat = matrices.mat3()
   mat:scale((size / texSize):augmented(1))
   mat:translate(pos / texSize)
   return mat
end

do
   ---@param rootModel ModelPart
   ---@param tex Texture
   ---@param pos Vector2
   ---@param uvSize Vector2
   ---@param size Vector2
   ---@return ModelPart
   local function makePart(rootModel, tex, pos, uvSize, size)
      local model = mod.lib.models.nineslice:copy("")
      rootModel:addChild(model)
      model:setUVMatrix(mod.lib.makeUVMat(tex, pos, uvSize))
         :setScale(size.x, size.y, 1)
      return model
   end
   ---@param tex Texture
   ---@param uv Vector4 # pos, size
   ---@param gap number
   ---@param size Vector2
   ---@param center? ModelPart
   ---@return ModelPart
   function mod.lib.makeNineslice(tex, uv, gap, size, center)
      local model = models:newPart(""):remove()
      model:setPrimaryTexture("CUSTOM", tex)
      local gap2 = vec(gap, gap)
      local uvSize = uv.zw
      ---@cast uvSize Vector2
      local uvEnd = uv.xy + uvSize
      local uvCenterSize = uvSize - gap * 2
      local centerSize = size - gap * 2
      local centerCorner = gap2 - size
      -- corners
      makePart(model, tex, uv.xy, gap2, gap2)
      makePart(model, tex, vec(uvEnd.x - gap, uv.y), gap2, gap2)
         :setPos(centerCorner.x, 0, 0)
      makePart(model, tex, vec(uv.x, uvEnd.y - gap), gap2, gap2)
         :setPos(0, centerCorner.y, 0)
      makePart(model, tex, uvEnd - gap, gap2, gap2)
         :setPos(centerCorner.x, centerCorner.y, 0)
      -- edges
      makePart(model, tex, vec(uv.x + gap, uv.y), vec(uvCenterSize.x, gap), vec(centerSize.x, gap))
         :setPos(-gap, 0, 0)
      makePart(model, tex, vec(uv.x + gap, uvEnd.y - gap), vec(uvCenterSize.x, gap), vec(centerSize.x, gap))
         :setPos(-gap, centerCorner.y, 0)
      makePart(model, tex, vec(uv.x, uv.y + gap), vec(gap, uvCenterSize.y), vec(gap, centerSize.y))
         :setPos(0, -gap, 0)
      makePart(model, tex, vec(uvEnd.x - gap, uv.y + gap), vec(gap, uvCenterSize.y), vec(gap, centerSize.y))
         :setPos(centerCorner.x, -gap, 0)
      -- center
      if center then
         model:addChild(center)
      else
         center = makePart(model, tex, uv.xy + gap, uvSize - gap * 2, centerSize)
      end
      center:setScale(centerSize.x, centerSize.y, 0)
      center:setPos(-gap, -gap, 0)
      return model
   end
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
   model:setUVMatrix(mod.lib.makeUVMat(texture, pos, size))
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

---@generic self
---@param self self
---@param model ModelPart
---@return self
function Action:setIconModel(model)
   ---@cast self auria.wheel.action
   self.icon = model
   self.iconRender = nil
   self:updateModel()
   return self
end

---sets function that will be run when this action is pressed
---@generic self
---@param self self
---@param func? function
---@return self
function Action:onPress(func)
   self.press = func
   return self
end

---sets function that will be run when this action is released
---@generic self
---@param self self
---@param func? function
---@return self
function Action:onRelease(func)
   self.release = func
   return self
end

---sets function that will be run when this action is selected
---@generic self
---@param self self
---@param func? function
---@return self
function Action:onSelect(func)
   self.select = func
   return self
end

---sets function that will be run when this action is deselected
---@generic self
---@param self self
---@param func? function
---@return self
function Action:onDeselect(func)
   self.deselect = func
   return self
end

---sets function that will be run when this action is scrolled
---@generic self
---@param self self
---@param func? fun(dir: number)
---@return self
function Action:onScroll(func)
   self.scroll = func
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
---@param page? auria.wheel.page
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
      ---@type function?
      select = nil,
      ---@type function?
      deselect = nil,
      ---@type fun(dir: number)?
      scroll = nil,
      type = myType,
      ---@type auria.wheel.action.render?
      renderData = nil,
   }
   setmetatable(obj, actionTypes[myType].mt)
   obj:setIconModel(mod.lib.models.default_icon)
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
---release: (fun(action: auria.wheel.action)),
---select: (fun(action: auria.wheel.action)),
---deselect: (fun(action: auria.wheel.action)),
---scroll: (fun(action: auria.wheel.action, dir: number)),
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
   data.release = data.release or emptyFunc
   data.select = data.select or emptyFunc
   data.deselect = data.deselect or emptyFunc
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
---@param i number
---@return number
local function clampGroupI(page, i)
   if not page.groupSize then
      return 1
   end
   i = math.floor(i)
   local limit = math.ceil(#page.actions / page.groupSize)
   i = math.min(i, limit)
   i = math.max(i, 1)
   return i
end

---@param page auria.wheel.page
local function updatePageGroupIndicator(page)
   local data = renderedPages[page]
   if not data then
      return
   end
   if not page.groupSize then
      data.groupIndicator:setVisible(false)
      return
   end
   local groups = math.ceil(#page.actions / page.groupSize)
   if groups <= 1 then
      data.groupIndicator:setVisible(false)
      return
   end
   local current = page.currentGroup
   local text = toJson{
      "Page ",
      {text = tostring(current), color = "#ffaaee"},
      " of ",
      {text = tostring(groups), color = "#ffaaee"},
   }
   local width = math.ceil(client.getTextWidth(text) / 2)
   data.groupIndicator:setVisible(true)
   data.groupIndicatorText:setText(text)
   data.groupIndicator.up:setPos(width, 0, 0)
      :setVisible(current > 1)
   data.groupIndicator.down:setPos(-width, 0, 0)
      :setVisible(current < groups)
end

---@param page auria.wheel.page
---@return auria.wheel.page.render, boolean
local function getRenderPage(page)
   local data = renderedPages[page]
   if data then
      return data, false
   end
   local model = hudModel:newPart("")
   local groupIndicator = model:newPart("")
   groupIndicator:setPos(0, -128, 0)
      :addChild(mod.lib.models.group_arrow_up  :copy("up"  ))
      :addChild(mod.lib.models.group_arrow_down:copy("down"))
   local textTask = groupIndicator:newText("")
   textTask:setAlignment("CENTER")
   ---@class auria.wheel.page.render
   data = {
      oldScale = 0,
      scale = 0,
      model = model,
      groupIndicator = groupIndicator,
      groupIndicatorText = textTask,
      ---@type {[auria.wheel.action]: auria.wheel.action.render}
      actions = {},
      ---@type auria.wheel.page.group[]
      groups = {},
   }
   renderedPages[page] = data
   page.currentGroup = clampGroupI(page, page.currentGroup)
   updatePageGroupIndicator(page)
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

---@param obj auria.wheel.breadcrumb
local function updateBreadcrumb(obj)
   if obj.page then
      obj.text = obj.page.title
   end
   local text = obj.text or obj.fallback
   local width = client.getTextWidth(text)
   obj.width = width + obj.extraWidth
   obj.textTask:setText(text)
end

---@param i number
---@param fallback string?
local function makeBreadcrumb(i, fallback)
   if i == 1 then
      fallback = fallback or "Home"
   else
      fallback = fallback or "Page"
   end
   local page = pageHistory[i]
   if breadcrumbs[i] then
      local obj = breadcrumbs[i]
      obj.fallback = fallback
      obj.page = page
      updateBreadcrumb(obj)
      return
   end
   local model = breadcrumbsModel:newPart("")
   local textTask = model:newText("")
   ---@class auria.wheel.breadcrumb
   local obj = {
      model = model,
      textTask = textTask,
      width = 0,
      ---@type string?
      text = nil,
      fallback = fallback,
      extraWidth = 12,
      ---@type auria.wheel.page?
      page = page,
   }
   if i == 1 then
      model:addChild(mod.lib.models.breadcrumb_icon)
   else
      model:addChild(mod.lib.models.breadcrumb_arrow)
   end
   textTask:setPos(-obj.extraWidth, 0, 0)
   breadcrumbs[i] = obj
   updateBreadcrumb(obj)
end


---sets title of this page
---@param text string?
---@return auria.wheel.page
function Page:setTitle(text)
   self.title = text
   local lastPage = pageHistory[#pageHistory]
   if lastPage == currentPage then
      local obj = breadcrumbs[#pageHistory]
      if obj then
         updateBreadcrumb(obj)
      end
   end
   return self
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
      local typeData = mod.lib.getActionData(action)
      typeData.release(action)
      if action.release then
         action.release()
      end
      return
   end
   if action.page then
      mod.setAndPushToHistory(action.page)
      makeBreadcrumb(#pageHistory, action.title)
   end
   mod.lib.getActionData(action).press(action)
   if action.press then
      action.press()
   end
end

---@param page auria.wheel.page
---@param i number
---@return number, number
local function getGroupSize(page, i)
   local min = 1
   local max = #page.actions
   if page.groupSize then
      min = (i - 1) * page.groupSize + 1
      max = min + page.groupSize - 1
   end
   return min, max
end

---@param group auria.wheel.page.group
---@param page auria.wheel.page
---@param i number
local function updatePageGroup(group, page, i)
   local min, max = getGroupSize(page, i)
   group.min = min
   group.max = max
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
---@param group auria.wheel.page.group
---@param k number
local function rebuildGroupActions(page, group, k)
   updatePageGroup(group, page, k)
   local lastAction = math.min(group.max, #page.actions)
   local rotScale, rotOffset = getActionsRotScaleAndOffset(lastAction - group.min + 1)
   local j = 0
   for i = group.min, lastAction do
      j = j + 1
      local action = page.actions[i]
      if not action.renderData then
         makePageAction(page, i)
      end
      local myData = action.renderData
      local rot = j * rotScale + rotOffset
      local dir = vec(-math.sin(rot), math.cos(rot), 0)
      myData.dir = dir
   end
end

---@param page auria.wheel.page
---@param i number
local function makePageGroup(page, i)
   local data = getRenderPage(page)
   if data.groups[i] then
      return
   end
   ---@class auria.wheel.page.group
   local group = {
      min = 1,
      max = 0,
      count = 0,
      rot = 0,
      oldRot = 0,
   }
   updatePageGroup(group, page, i)
   rebuildGroupActions(page, group, i)
   data.groups[i] = group
end

---@param page auria.wheel.page
local function rebuildPageActions(page)
   page.currentGroup = clampGroupI(page, page.currentGroup)
   local pageData = getRenderPage(page)
   for k, group in pairs(pageData.groups) do
      rebuildGroupActions(page, group, k)
   end
   updatePageGroupIndicator(page)
end

---@param page? auria.wheel.page
---@param i number
local function setSelectedAction(page, i)
   if page == selectedActionPage and selectedActionidx == i then
      return
   end
   local oldAction = mod.getSelectedAction()
   if oldAction then
      local typeData = mod.lib.getActionData(oldAction)
      typeData.deselect(oldAction)
      if oldAction.deselect then
         oldAction.deselect()
      end
   end
   selectedActionPage = page
   selectedActionidx = i
   local action = mod.getSelectedAction()
   if action then
      local typeData = mod.lib.getActionData(action)
      typeData.select(action)
      if action.select then
         action.select()
      end
   end
end

---@param n number
---@return auria.wheel.page
function Page:setCurrentGroup(n)
   n = clampGroupI(self, n)
   local old = self.currentGroup
   self.currentGroup = n
   if old ~= n and renderedPages[self] then
      makePageGroup(self, n)
      local data = getRenderPage(self)
      local group = data.groups[n]
      local rot = n - old
      group.rot = rot
      group.oldRot = rot
   end
   updatePageGroupIndicator(self)
   return self
end

---sets amount of actions per group (subpage)
---@param n number?
---@return auria.wheel.page
function Page:setGroupSize(n)
   self.groupSize = n
   self.currentGroup = clampGroupI(self, self.currentGroup)
   if renderedPages[self] then
      local pageData = getRenderPage(self)
      local limit = #self.actions
      for _, group in pairs(pageData.groups) do
         for i = group.min, math.min(group.max, limit) do
            local action = pageData.actions[ self.actions[i] ]
            action.model:setVisible(false)
         end
      end
      rebuildPageActions(self)
   end
   updatePageGroupIndicator(self)
   return self
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
      setSelectedAction(nil, -1)
   elseif not isClicked then
      local newIdx = -1
      local newPage = nil
      if currentPage and isEnabled then
         local mousePos = mod.lib.getMousePos()
         getRenderPage(currentPage)
         local dist = mousePos:length()
         if dist > 50 then
            local min, max = getGroupSize(currentPage, currentPage.currentGroup)
            local actionCount = math.min(max, #currentPage.actions) - min + 1
            local angle = math.atan2(mousePos.x, -mousePos.y) - (pageAngleOffsets[actionCount] or 0)
            local i = ((angle / math.pi / 2) % 1) * actionCount
            local center = math.floor(i) + 0.5
            local diff = math.abs(center - i) / actionCount * 360
            local idx = math.floor(i) + min
            if diff < 70 and currentPage.actions[idx] then
               newIdx = idx
               newPage = currentPage
            end
         end
      end
      setSelectedAction(newPage, newIdx)
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
   -- update pages
   for page, data in pairs(renderedPages) do
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
      for i, group in pairs(data.groups) do
         group.oldRot = group.rot
         local myTarget = (i - page.currentGroup) * 1.2
         group.rot = math.lerp(group.rot, myTarget, 0.5)
      end
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
   -- update breadcrumbs
   breadcrumbOldLen = breadcrumbLen
   local target = #pageHistory
   breadcrumbLen = math.lerp(breadcrumbLen, target, 0.5)
   local loaded = math.max(target, math.ceil(breadcrumbLen))
   for i = #breadcrumbs, loaded + 1, -1 do
      local v = breadcrumbs[i]
      breadcrumbs[i] = nil
      v.model:remove()
   end
   for i = #breadcrumbs + 1, loaded do
      makeBreadcrumb(i)
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
RightClickKey.release = function()
end

local scrollOffset = 0
function events.mouse_scroll(dirRaw)
   if not isEnabled then return end
   dirRaw = math.clamp(dirRaw, -1, 1)
   dirRaw = dirRaw + scrollOffset
   scrollOffset = dirRaw % 1
   dirRaw = math.floor(dirRaw)
   if dirRaw == 0 then return end
   local dir = dirRaw > 0 and 1 or -1
   local action = mod.getSelectedAction()
   if action then
      local typeData = mod.lib.getActionData(action)
      if typeData.scroll then
         typeData.scroll(action, dir)
      end
      if action.scroll then
         action.scroll(dir)
      end
      if action.scroll or typeData.scroll or leftClickKey:isPressed() then
         return true
      end
   end
   if not currentPage then
      return
   end
   currentPage:setCurrentGroup(currentPage.currentGroup - dir)
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

   data.groupIndicator:setOpacity(opacity)
      :setScale(sizeScale)

   makePageGroup(page, page.currentGroup)

   local maxActions = #page.actions
   for k, group in pairs(data.groups) do
      local groupRot = math.lerp(group.oldRot, group.rot, delta)
      local myVisible = 1 - math.min(math.abs(groupRot), 1)
      local myOpacity = myVisible * opacity
      local mySizeScale = myVisible * sizeScale
      groupRot = groupRot * 30
      local posMat = matrices.rotation3(0, 0, groupRot)
      local groupMax = page.groupSize and math.min(group.max, maxActions) or maxActions
      for i = group.min, groupMax do
         local action = page.actions[i]
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
         actionData.model:setPos(pos * posMat)
            :setScale(scale * mySizeScale)
            :setRot(0, 0, groupRot)
            :setVisible(myVisible > 0.02)
         actionData.text:setOpacity(myOpacity)

         if action.iconRender then
            action.iconRender(myOpacity)
         end
         local popup = actionData.popup
         if popup then
            local popupVisible = math.lerp(popup.oldVisible, popup.visible, delta) * myVisible
            popup.model:setScale(popupVisible)
               :setPos(pos - vec(0, 0, 50))
               :setOpacity(popupVisible)
         end
         local typeData = mod.lib.getActionData(action)
         typeData.actionRender(action, delta)
      end
      if myVisible == 0 and page.currentGroup ~= k then
         data.groups[k] = nil
      end
   end
end

---@param delta number
---@param globalVisible number
local function renderBreadcrumbs(delta, globalVisible)
   local len = math.lerp(breadcrumbOldLen, breadcrumbLen, delta)
   len = len + 1

   local ellipsisVisible = math.clamp(len - 6, 0, 1)
   breadcrumbsEllipsis:setOpacity(ellipsisVisible)
   breadcrumbsEllipsis:setVisible(ellipsisVisible > 0.05)

   local width = 0

   for i, v in pairs(breadcrumbs) do
      local offset = len - i
      local visible = math.clamp(offset, 0, 1)
      if i >= 4 then
         visible = visible * math.clamp(3 - offset, 0, 1)
      end
      local opacity = visible * globalVisible
      opacity = opacity * opacity
      v.model:setOpacity(opacity)
         :setVisible(opacity > 0.05)
         :setPos(-width, (visible - 1) * 2, 0)
      local textOpacity = opacity
      if i == 3 then
         textOpacity = textOpacity * (1 - ellipsisVisible)
         breadcrumbsEllipsis:setPos(-width - 12, 0, 0)
      end
      v.textTask:setOpacity(textOpacity)
         :setVisible(textOpacity > 0.05)
      local myWidth = 0
      if i == 1 then
         myWidth = v.width
      else
         myWidth = v.width * visible
      end
      if i == 3 then
         myWidth = math.lerp(myWidth, breadcrumbsEllipsisWidth, ellipsisVisible)
      end
      width = width + myWidth
   end

   local pos = vec(math.round(width / 2), 124, 0)
   breadcrumbsModel:setScale(globalVisible)
      :setPos(pos * globalVisible)
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
   renderBreadcrumbs(delta, globalVisible)
end

return mod