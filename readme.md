# Auria's wheel
A fancy animated action wheel as alternative to figura's built-in one

To see all functions easily in your code editor its reccomended to use sumneko's lua language server and GS's vscode docs
## Download and install
Click green `Code` button and click `download ZIP`

and then copy `auria_wheel` folder to your avatar
## Setup and examples
Require `main` file of library
```lua
local wheel = require("auria_wheel.main")
```
like figura's action wheel, you need to create a page and set it to show actions
```lua
-- create a page
local page = wheel.newPage()
-- set it
wheel.setPage(page)
```
while you can use `onPress` and `onScroll`, this one have different action types for different uses, here are some examples:
```lua
-- generic action with no extra features
page:newAction()
   :setTitle("button")
page:newToggle()
   :setTitle("show armor")
   :setToggled(true)
   :onToggle(function(value)
      vanilla_model.ARMOR:setVisible(value)
   end)
```
See [`example.lua`](example.lua) for more examples