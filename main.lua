local wheel = require("wheel.main")

local page = wheel.newPage()
wheel.setPage(page)

do
   local slider = page:newSlider()
      :setIconEmoji(":cat:")
   slider:setBackground(wheel.texture, vec(6.5, 0.5), vec(1, 1), "BLURRY")
      :setBackgroundSize(vec(128, 128))
      :setRange(vec(0, 1), vec(0, 1))
      :setValue(0.5, 0.75)
end
do
   local slider = page:newSlider()
      :setIconEmoji(":cat:")
      :setLoop(true)
   slider:setBackground(wheel.texture, vec(9.5, 0.5), vec(6, 0), "BLURRY")
end
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
   if k == 1 or k == 4 then
      local page2 = wheel.newPage()
      for a = 1, 8 do
         local btn2 = page2:newAction()
         if (k == 1 and a == 2) or (k == 4 and a == 8) then
            local page3 = wheel.newPage()
            for _ = 1, 5 do
               page3:newAction()
            end
            btn2.page = page3
            if k == 1 then
               btn2:setIconEmoji(":@auria:")
            end
         end
      end
      btn.page = page2
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
-- page:newButton()
-- page:newButton()
-- page:newButton()

-- page:newToggle()
--    :setTitle("cat")
--    :setValue(true)
--    :setOnChange(function(value)
--       print(value)
--    end)
--    :setIconEmoji(":cat:")