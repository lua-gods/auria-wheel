---@class auria.wheel.config <partial>
local conf = {
   keybind = keybinds:fromVanilla("figura.config.action_wheel_button"),

   overlayColor = vec(0.2, 0.22, 0.25, 0.5),
   postEffect = "blur", -- set to nil to remove post effect

   ---@type "HOLD"|"MIXED"|"TOGGLE"
   mode = "MIXED",
   holdTime = 250, -- in ms, how long keybinds has to be clicked to be considered held

   animationSpeed = 0.5, -- animation speed, between 0 and 1
   noAnimations = false,
}
return conf