LuauVM <img src="https://raw.githubusercontent.com/Roblox/luau/master/docs/logo.svg" height="40">
====
LuauVM (lowercase u, /ˈlu.aʊ/) is a fast and small [luau](https://github.com/Roblox/luau) interpreter wrote in luau. It aim to provide sandboxing, arbitrary code execution and "obfuscation" templates.

This software can be used as study material for luau - lua 5.x internals. 

# Usage
```lua
local vm = require("./VM/main");
local bytecode = [[BYTECODE]]

-- #1
local proto = vm.luau_load(bytecode);
local closure = vm.wrap_proto(proto);
closure();

-- # 2
local closure = vm.loadstring(bytecode);
closure();
```

> **Note:** only an interpreter is provided and compiled code must be obtained from a supported luau compiler

# License ⚖
[MIT LICENSE](https://github.com/uniquadev/LuauVM/blob/master/LICENSE.txt)