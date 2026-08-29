---@class auria.wheel.config <partial>
local conf = {
   keybind = keybinds:fromVanilla("figura.config.action_wheel_button"),
   postEffect = "blur",

   ---@type "HOLD"|"MIXED"|"TOGGLE"
   mode = "MIXED",
   holdTime = 250, -- in ms, how long keybinds has to be clicked to be considered held
}
return conf