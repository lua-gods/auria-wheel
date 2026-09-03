local wheel = require("wheel.main")

local mainPage = wheel.newPage()
wheel.setPage(mainPage)

local mainGroupSize = 4
local toggle = mainPage:newToggle()
toggle:setTitle("Groups")
   :setIconEmoji(":fox:")
   :onToggle(function(value)
      if value then
         mainPage:setGroupSize(mainGroupSize)
      else
         mainPage:setGroupSize()
      end
   end)
   :onScroll(function(dir)
      mainGroupSize = math.clamp(mainGroupSize + dir, 1, 8)
      if toggle.value then
         mainPage:setGroupSize(mainGroupSize)
      end
   end)

mainPage:newDropdown()
   :setTitle("Dropdown")
   :setChoices({
      "cat",
      "fox",
      "dragon",
   })
   :setIconEmoji(":notepad:")
   :onValueChange(function(i, str)
      host:setActionbar(str)
   end)
   :onValueChangeFinish(function(i, str)
      host:setActionbar("confirmed "..str)
   end)

mainPage:newColorPicker()
   :setColor(vec(1, 0, 0.5))
   :onColorChange(function(color)
      host:setActionbar("changed "..tostring(color))
   end)
   :onColorChangeConfirmed(function(color)
      print("confirmed", color)
   end)
   :onColorChangeFinished(function(color)
      print("finished", color)
   end)

do
   local page2 = wheel.newPage()
   for a = 1, 10 do
      local page3 = wheel.newPage()
      page2:newAction()
         :setPage(page3)
         :setTitle(a.." actions")
      for b = 1, a do
         page3:newToggle()
            :setTitle("action: "..b)
      end
   end
   mainPage:newAction()
      :setPage(page2)
      :setIconEmoji(":dragon:")
end

do
   local btn = mainPage:newSlider()
   btn:setRange(vec(2, 1), vec(2, 1))
      :setBackgroundSize(vec(64, 64))
      :setStep(0.25)
      :onRelease(function()
         host:setActionbar(tostring(vec(btn.value, btn.valueY)))
      end)
end

mainPage:newSlider()
   :onValueChange(function(value, valueY)
      host:setActionbar(tostring(value))
   end)
   :setIconItem("stone", "NONE")

do
   local page = wheel.newPage()
   mainPage:newAction()
      :setPage(page)
      :setIconEmoji(":@auria:")
   for i = 1, 8 do
      local newPage = wheel.newPage()
      newPage:setTitle("Page "..i)
      page:newAction()
         :setPage(newPage)
      page = newPage
   end
end

mainPage:newAction()
   :setTitle("New action")
   :setIconEmoji(":+1:")
   :onPress(function()
      mainPage:newAction()
         :setTitle("remove")
         :setIconEmoji(":zzz:")
         :onPress(function()
            mainPage.actions[#mainPage.actions] = nil
         end)
   end)