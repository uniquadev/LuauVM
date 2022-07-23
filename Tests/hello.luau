-- imports
local vm = require("./VM/main");
local tick = os.clock;
-- data
local bytecode = '\x02\x02\x05print\x0fhello bytecode!\x01\x03\x00\x00\x01\x08A\x00\x00\x00\x0c\x00\x01\x00\x00\x00\x00@\x05\x01\x02\x00\x04\x02\x01\x00\x15\x00\x03\x01\x04\x00\x00\x00\x16\x00\x02\x00\x03\x03\x01\x04\x00\x00\x00@\x03\x02\x00\x01\x00\x01\x18\x00\x00\x00\x00\x00\x00\x01\x00\x01\x00\x00\x00\x00\x00';

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
print(("hello.luau: deserialized in %.3fms"):format(proto_delta * 1000));
print(("hello.luau: executed in %.3fms"):format(call_delta * 1000));

if res[1] then
    -- check return code
    if res[2] ~= 0 then
        print(("hello.luau: execution failed with code %d"):format(res[2]));
    else
        print("hello.luau PASSED");
    end;
else
    print("hello.luau FAILED: " .. res[2]);
end

