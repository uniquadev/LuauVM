LuauVM <img src="https://raw.githubusercontent.com/uniquadev/LuauVM/4a4d2e529fea0952546eba07cc4394b6fa3c3830/luau.png" height="40"> ![CI](https://github.com/uniquadev/LuauVM/workflows/build/badge.svg)
====
LuauVM (lowercase u, /ˈlu.aʊ/) is a fast and small [luau](https://github.com/Roblox/luau) interpreter wrote in luau. It aims to provide sandboxing, arbitrary code execution and "obfuscation" templates.

This software can be used as study material for luau - lua 5.x internals.

## NOTE:
> * This VM won't be maintained constantly over luau updates.
> * This VM doesn't aim to provide a fast bytecode execution.
> * This VM has been tested with scripts like the ones in [MakeTests/src](https://github.com/uniquadev/LuauVM/tree/master/MakeTests/src) folder.

# Usage
```lua
local vm = require("./VM/main"); -- require("LuauVM");
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
1) `python MakeTests\main.py -t` to build tests scripts in Tests directory
  - Tests' scripts must return 0 to pass the check.
2) `python MakeTests\run.py - r` to run all built tests
* `luau "<path/to/test-script>"` to run a specific test script 

# License
[MIT LICENSE](https://github.com/uniquadev/LuauVM/blob/master/LICENSE.txt)
