-- imports
local vm = require("./VM/main");
local tick = os.clock;
-- data
local bytecode = "{bytecode}";

-- timer
local proto_delta, call_delta;
local clock = tick();

-- load bytecode
local proto = vm.luau_load(bytecode);
proto_delta = tick() - clock;
clock = tick();

-- wrap proto in a callable closure 
local closure = vm.wrap_proto(proto);
-- call closure
local res = table.pack(pcall(closure));
call_delta = tick() - clock;

-- execution time
print(("{file}: deserialized in %.3fms"):format(proto_delta * 1000));
print(("{file}: executed in %.3fms"):format(call_delta * 1000));

if res[1] then
    -- check return code
    if res[2] ~= 0 then
        print(("{file}: execution failed with code %s"):format(tostring(res[2])));
    else
        print("{file} PASSED");
    end;
else
    print("{file} FAILED: " .. res[2]);
end

