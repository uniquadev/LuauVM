LuauVM <img src="https://raw.githubusercontent.com/Roblox/luau/master/docs/logo.svg" height="40"> ![CI](https://github.com/uniquadev/LuauVM/workflows/build/badge.svg)
====
LuauVM (lowercase u, /ˈlu.aʊ/) is a fast and small [luau](https://github.com/Roblox/luau) interpreter wrote in luau. It aims to provide sandboxing, arbitrary code execution and "obfuscation" templates.

This software can be used as study material for luau - lua 5.x internals.

> NOTE: This VM is still work in progress and it can execute scripts like the ones in [MakeTests/src](https://github.com/uniquadev/LuauVM/tree/master/MakeTests/src) folder.

# Usage
```lua
local vm = require("./VM/main");
local bytecode = [[BYTECODE]]

-- #1 way
local proto = vm.luau_load(bytecode);
local closure = vm.wrap_proto(proto);
closure();

-- #2 way
local closure = vm.loadstring(bytecode);
closure();
```

> **Note:** only an interpreter is provided and compiled code must be obtained from a supported luau compiler

# Tests
1) Run `python MakeTests\main.py`
2) Run `python MakeTests\run.py`

# License
[MIT LICENSE](https://github.com/uniquadev/LuauVM/blob/master/LICENSE.txt)
