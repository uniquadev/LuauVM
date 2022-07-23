-- imports
local lundump = require("./VM/luau/lvmload");
local lvmexecute = require("./VM/luau/lvmexecute");

-- luau_load luau_execute wrapper
local function loadstring(bytecode:string)
    local proto = lundump.luau_load(bytecode);
    local closure = lvmexecute.wrap_proto(proto);
    return closure;
end;

return {
    luau_load = lundump.luau_load,
    wrap_proto = lvmexecute.wrap_proto,
    loadstring = loadstring
};