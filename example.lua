local wheel = require("wheel.main")

local page = wheel.newPage()
wheel.setPage(page)

page:newToggle()
   :setTitle("Hello World")
   :setIconEmoji(":fox:")
   :setToggled(true)
page:newColorPicker()
   :setColor(vec(1, 1, 0.5))
page:newColorPicker()
   :setColor(vec(1, 0, 0.5))
for k = 1, 4 do
   local btn
   if k == 3 then
      btn = page:newSlider()
      btn:onValueChange(function(value, valueY)
         host:setActionbar(tostring(value))
      end)
   elseif k == 2 then
      btn = page:newSlider()
      btn:setRange(vec(2, 1), vec(2, 1))
         :setBackgroundSize(vec(64, 64))
         :setStep(0.25)
         :onRelease(function()
            host:setActionbar(tostring(vec(btn.value, btn.valueY)))
         end)
   else
      btn = page:newAction()
   end
   if k == 4 then
      local page2 = wheel.newPage()
      for a = 1, 8 do
         local btn2 = page2:newAction()
         if a == 8 then
            local page3 = wheel.newPage()
            for _ = 1, 5 do
               page3:newAction()
            end
            btn2:setPage(page3)
            if k == 1 then
               btn2:setIconEmoji(":@auria:")
            end
         end
      end
      btn:setPage(page2)
   elseif k == 1 then
      local page2 = wheel.newPage()
      btn:setPage(page2)
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
   end
   if k == 1 then
      btn:setIconEmoji(":dragon:")
   elseif k == 4 then
      btn:setIconEmoji(":@gn:")
   elseif k == 2 then
      -- btn:setIconTexture(textures["textures.hair"], vec(16, 8), vec(8, 8))
   elseif k == 3 then
      btn:setIconItem("stone", "NONE")
   end
end

page:newAction()
   :setTitle("New action")
   :setIconEmoji(":+1:")
   :onPress(function()
      page:newAction()
         :setTitle("remove")
         :setIconEmoji(":zzz:")
         :onPress(function()
            page.actions[#page.actions] = nil
         end)
   end)