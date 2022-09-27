import re

MAIN_IMPORTS = """-- imports
local lvmload = require("./VM/luau/lvmload");
local lvmexecute = require("./VM/luau/lvmexecute");
"""
VMLOAD_IMPORTS = """-- imports
local lobject = require("./VM/luau/lobject");
local bytecode = require("./VM/luau/bytecode");
local stream = require("./VM/stream");
"""
VMEXEC_IMPORTS = """-- imports
local lobject = require("./VM/luau/lobject");
local bytecode = require("./VM/luau/bytecode");
local lvmload = require("./VM/luau/lvmload");
local lbuiltins = require("./VM/luau/lbuiltins");
"""

def build():
    res : str = ""
    
    # main
    with open("VM/main.lua") as f:
        res = f.read().replace(MAIN_IMPORTS, "")

    # solve lvmexecute
    with open("VM/luau/lvmexecute.lua") as f:
        lvmexecute = f.read().replace(VMEXEC_IMPORTS, "")
        res = re.sub(r'return {\n.*wrap_proto =', "local lvmexecute = { wrap_proto =", lvmexecute) + res


    # solve lvmload
    with open("VM/luau/lvmload.lua") as f:
        vmload = f.read().replace(VMLOAD_IMPORTS, "")

        res = re.sub(r'return {\n.*luau_load =', "local lvmload = { luau_load =", vmload) + res

    # stream, bytecode, lobject, lbuiltins
    with open("VM/stream.lua") as f:
        stream = f.read()
        res = re.sub(r'return {\n.*new =', "local stream = { new =", stream) + res
    with open("VM/luau/bytecode.lua") as f:
        bytecode = f.read()
        res = re.sub(r'return {\n.*get_op_name =', "local bytecode = { get_op_name =", bytecode) + res
    with open("VM/luau/lbuiltins.lua") as f:
        lbuiltins = f.read()
        res = re.sub(r'return {\n.*fast_functions =', "local lbuiltins = { fast_functions =", lbuiltins) + res
    with open("VM/luau/lobject.lua") as f:
        res = f.read().replace('return {};', '') + res

    res = res.replace('lobject.', '')
    
    # save
    with open("LuauVM.lua", "w+") as o:
        o.write(res)