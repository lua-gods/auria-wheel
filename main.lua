local wheel = require("wheel.main")

local page = wheel.newPage()
wheel.setPage(page)

for k = 1, 6 do
   local btn = page:newAction()
   if k == 1 then
      btn.type = "colorpicker"
   elseif k == 2 then
      btn.type = "hue"
   end
   if k == 6 or k == 3 then
      local page2 = wheel.newPage()
      for a = 1, 8 do
         local btn2 = page2:newAction()
         if (k == 3 and a == 2) or (k == 6 and a == 8) then
            local page3 = wheel.newPage()
            for _ = 1, 5 do
               page3:newAction()
            end
            btn2.page = page3
            if k == 3 then
               btn2:setIconEmoji(":@auria:")
            end
         end
      end
      btn.page = page2
   end
   if k == 2 then
      btn:setIconEmoji(":cat:")
   elseif k == 3 then
      btn:setIconEmoji(":dragon:")
   elseif k == 6 then
      btn:setIconEmoji(":@gn:")
   elseif k == 4 then
      -- btn:setIconTexture(textures["textures.hair"], vec(16, 8), vec(8, 8))
   end
end
-- page:newButton()
-- page:newButton()
-- page:newButton()