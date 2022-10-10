-- imports
local lobject = require("./VM/luau/lobject");
local bytecode = require("./VM/luau/bytecode");
local lvmload = require("./VM/luau/lvmload");
local lbuiltins = require("./VM/luau/lbuiltins");

local LuauOpcode = bytecode.LuauOpcode;
local LuauCaptureType = bytecode.LuauCaptureType;
local get_op_name = bytecode.get_op_name;
local resolve_import = lvmload.resolve_import;
local fast_functions = lbuiltins.fast_functions;

-- constants
local LUA_MULTRET = -1;

-- globals
local OP_TO_CALL = table.create(90);
local wrap_proto;
local luau_execute;

-- macros
local function SIGNED_INT(int:number) return int - (2 ^ 32); end;

-- retrive instruction opcode
local function LUAU_INSN_OP(inst:lobject.Instruction) return bit32.band(inst, 0xff); end;
-- ABC encoding: three 8-bit values, containing registers or small numbers
local function LUAU_INSN_A(insn:lobject.Instruction) return bit32.band(bit32.rshift(insn, 8), 0xff); end;
local function LUAU_INSN_B(insn:lobject.Instruction) return bit32.band(bit32.rshift(insn, 16), 0xff); end;
local function LUAU_INSN_C(insn:lobject.Instruction) return bit32.band(bit32.rshift(insn, 24), 0xff); end;

-- AD encoding: one 8-bit value, one signed 16-bit value
local function LUAU_INSN_D(insn:lobject.Instruction)
    local s = SIGNED_INT(insn);
    local r =  bit32.rshift(s, 16) -- ty luau
    -- negative
    if bit32.btest(bit32.rshift(r, 15)) then
        return r - 0x10000;
    end
    -- positive
    return r;
end;

-- E encoding: one signed 24-bit value
local function LUAU_INSN_E(insn:lobject.Instruction) return bit32.rshift(SIGNED_INT(insn), 8) end;

local function new_upval(stack, id:number) : lobject.UpVal
    return {
        id = id,
        stack = stack,
        v = stack[id]
    };
end
local function luaF_findupval(state:lobject.ClosureState, id:number) : lobject.UpVal
    local open_list = state.open_list;
    local uv = open_list[id];
    if uv then
        uv.v = state.stack[id];
        return uv;
    end
    uv = new_upval(state.stack, id);
    open_list[id] = uv;
    return uv;
end;

local function luaF_close(state:lobject.ClosureState, level:number)
    local open_list = state.open_list;
    for i, uv in pairs(open_list) do
        if uv.id >= level then
            uv.v = uv.stack[uv.id];
            uv.stack = uv;
            uv.id = 'v';
            open_list[i] = nil;
        end
    end
end;

local function luaG_getline(proto:lobject.Proto, pc:number) : number
    local lineinfo = proto.lineinfo;
    if lineinfo == nil then
        return 0;
    end
    return proto.lineinfo[proto.absoffset + bit32.rshift(pc, proto.linegaplog2)] + proto.lineinfo[pc-1];
end;

-- initialize closure state and wrap it inside a real closure
function wrap_proto(proto:lobject.Proto, env, upsref)
    assert(type(proto) == "table", "wrap_proto: proto is not a table");

    -- solve env
    env = env or getfenv(1); -- get env of the calling function
    -- wrap proto
    return function(...)
        local stack = table.create(proto.maxstacksize);
        local args = table.pack(...);
        local varargs = {};
        -- define closure state
        local state : lobject.ClosureState = {
            run = true,
            proto = proto,
            ret = {},
            pc = 0,
            insn = 0,
            env = env,
            vararg = varargs,
            upsref = upsref,
            open_list = {},
            stack = stack,
            top = -1
        };
        -- load args in stack
        table.move(args, 1, proto.numparams, 0, stack);
        -- solve varargs
        if proto.is_vararg then
            local start = proto.numparams + 1;
            local len = args.n - proto.numparams;

            varargs.n = len;
            table.move(args, start, start + len, 1, varargs);
        end
        -- run closure
        local res = table.pack(pcall(luau_execute, state));
        -- check res integrity
        if res[1] then
            return table.unpack(res, 2);
        end;
        -- execution error handling
        local err = res[2]--:gsub(".*:%d*: ", '');
        local line = luaG_getline(proto, state.pc);
        error(("chunk:%i: %s"):format(line, err));
    end;
end;

-- vm
luau_execute = function(state:lobject.ClosureState)
    local code = state.proto.code;
    -- run until flag is set to false
    while state.run do
        -- retrive instruction
        state.insn = code[state.pc];
        -- call operator handler
        local op = LUAU_INSN_OP(state.insn);
        OP_TO_CALL[op](state);
    end;
    -- unpack return
    return table.unpack(state.ret);
end;


-- default opcode case
local function default_case(state:lobject.ClosureState)
    -- set run flag to false
    state.run = false;
    -- vars
    local name = state.proto.debugname or 'closure'
    local insn = state.insn;
    local oins = state.proto.code[state.pc-1];
    local op = LUAU_INSN_OP(insn);
    local op_name = get_op_name(op);
    -- special error case
    assert(op_name, name .. ": invalid opcode reached, possible wrong pc incrementation in " .. get_op_name(LUAU_INSN_OP(oins)) .. ".");
    -- error message
    error(("%s: unsupported %d:%s opcode detected at %d"):format(
        name,
        op, get_op_name(op),
        state.pc
    ));
end;
setmetatable(OP_TO_CALL, {
    __index = function() return default_case end
});

-- opcodes registration
OP_TO_CALL[LuauOpcode.LOP_NOP] = function(state:lobject.ClosureState)
    state.pc += 1;
end;

OP_TO_CALL[LuauOpcode.LOP_BREAK] = OP_TO_CALL[LuauOpcode.LOP_NOP];

OP_TO_CALL[LuauOpcode.LOP_LOADNIL] = function(state:lobject.ClosureState)
    state.pc += 1;

    local id = LUAU_INSN_A(state.insn);
    state.stack[id] = nil;
end;

OP_TO_CALL[LuauOpcode.LOP_LOADB] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += LUAU_INSN_C(insn) + 1;

    local id = LUAU_INSN_A(insn);
    state.stack[id] = LUAU_INSN_B(insn) ~= 0;
end;

OP_TO_CALL[LuauOpcode.LOP_LOADN] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    state.stack[id] = LUAU_INSN_D(insn);
end;

OP_TO_CALL[LuauOpcode.LOP_LOADK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local kv = state.proto.k[LUAU_INSN_D(insn)];
    state.stack[id] = kv;
end;

OP_TO_CALL[LuauOpcode.LOP_MOVE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);

    state.stack[id] = state.stack[id2];
end;

OP_TO_CALL[LuauOpcode.LOP_GETGLOBAL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;
    local aux = state.proto.code[state.pc];
    local kv = state.proto.k[aux];

    local id = LUAU_INSN_A(insn);
    state.stack[id] = state.env[kv];
    state.pc += 1;
end;

OP_TO_CALL[LuauOpcode.LOP_SETGLOBAL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;
    local aux = state.proto.code[state.pc];
    local kv = state.proto.k[aux];
    
    state.env[kv] = state.stack[LUAU_INSN_A(insn)];
    state.pc += 1;
end;

OP_TO_CALL[LuauOpcode.LOP_GETIMPORT] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local kv = state.proto.k[LUAU_INSN_D(insn)];

    if kv then
        state.stack[id] = kv;
        state.pc += 1; -- skip aux instruction
    else
        local aux = state.proto.code[state.pc];
        state.pc += 1;
        local res = table.pack(
            pcall(resolve_import, state.env, state.proto.k, aux)
        );
        -- check integrity and store import to stack
        if res[1] then
            state.stack[id] = res[2];
        end;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_GETTABLE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);
    local idx = LUAU_INSN_C(insn);
    state.stack[id] = state.stack[id2][state.stack[idx]];
end;

OP_TO_CALL[LuauOpcode.LOP_SETTABLE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local src = state.stack[LUAU_INSN_A(insn)];
    local tbl = state.stack[LUAU_INSN_B(insn)];
    local idx = state.stack[LUAU_INSN_C(insn)];
    tbl[idx] = src;
end;

OP_TO_CALL[LuauOpcode.LOP_GETTABLEKS] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local t = state.stack[LUAU_INSN_B(insn)];
    -- local hash = LUAU_INSN_C(insn);

    local aux = state.proto.code[state.pc];
    state.pc += 1;

    local kv = state.proto.k[aux];
    state.stack[id] = t[kv];
end;

OP_TO_CALL[LuauOpcode.LOP_SETTABLEKS] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local src = state.stack[LUAU_INSN_A(insn)];
    local tbl = state.stack[LUAU_INSN_B(insn)];
    -- local hash = LUAU_INSN_C(insn);
    local aux = state.proto.code[state.pc];
    state.pc += 1;

    local idx = state.proto.k[aux];
    tbl[idx] = src;
end;

OP_TO_CALL[LuauOpcode.LOP_GETUPVAL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);
    local uv : lobject.UpVal = state.upsref[id2];

    state.stack[id] = uv.v;
end;

OP_TO_CALL[LuauOpcode.LOP_SETUPVAL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);
    local uv : lobject.UpVal = state.upsref[id2];
    uv.stack[uv.id] = state.stack[id];
    uv.v = state.stack[id];
end;

OP_TO_CALL[LuauOpcode.LOP_CLOSEUPVALS] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local target = LUAU_INSN_A(insn);
    luaF_close(state, target);
end;

OP_TO_CALL[LuauOpcode.LOP_GETTABLEN] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local tbl = state.stack[LUAU_INSN_B(insn)];
    local idx = LUAU_INSN_C(insn) + 1;
    state.stack[id] = tbl[idx];
end;

OP_TO_CALL[LuauOpcode.LOP_SETTABLEN] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local src = state.stack[LUAU_INSN_A(insn)];
    local tbl = state.stack[LUAU_INSN_B(insn)];
    local idx = LUAU_INSN_C(insn) + 1;
    tbl[idx] = src;
end;

OP_TO_CALL[LuauOpcode.LOP_NEWCLOSURE] = function(state:lobject.ClosureState)
    state.pc += 1;

    local id = LUAU_INSN_A(state.insn);
    local proto = state.proto.p[LUAU_INSN_D(state.insn)];
    local upsref = {};

    for i = 0, proto.nups - 1 do
        local uinst = state.proto.code[state.pc];
        state.pc += 1;
        local ctype = LUAU_INSN_A(uinst); -- capture type
        local id2 = LUAU_INSN_B(uinst); -- capture id
        if ctype == LuauCaptureType.LCT_VAL then
            upsref[i] = new_upval(state.stack, id2);
        elseif ctype == LuauCaptureType.LCT_REF then
            upsref[i] = luaF_findupval(state, id2);
        elseif ctype == LuauCaptureType.LCT_UPVAL then
            upsref[i] = state.upsref[id2];
        end
    end;

    

    state.stack[id] = wrap_proto(proto, state.env, upsref);
end;

OP_TO_CALL[LuauOpcode.LOP_NAMECALL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);
    -- local hash = LUAU_INSN_C(insn);
    local aux = state.proto.code[state.pc];
    state.pc += 1;

    local t = state.stack[id2];
    local kv = state.proto.k[aux];
    state.stack[id + 1] = t;
    state.stack[id] = t[kv];
end;

OP_TO_CALL[LuauOpcode.LOP_CALL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;
    local id = LUAU_INSN_A(insn);

    local nparams = LUAU_INSN_B(insn) - 1;
    local nresults = LUAU_INSN_C(insn) - 1;
    
    local params = nparams == LUA_MULTRET and state.top - id or nparams;
    local ret = table.pack(state.stack[id](table.unpack(state.stack, id + 1, id + params)));
    local nres = ret.n;

    if nresults == LUA_MULTRET then
        state.top = id + nres - 1;
    else
        state.top = -1;
        nres = nresults;
    end;

    table.move(ret, 1, nres, id, state.stack);
end;

OP_TO_CALL[LuauOpcode.LOP_RETURN] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.run = false;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local b = LUAU_INSN_B(insn);
    local nresults;

    if b == 0 then
        nresults = state.top - id + 1;
    else
        nresults = b - 1;
    end;

    table.move(state.stack, id, id + nresults - 1, 1, state.ret);
end;

OP_TO_CALL[LuauOpcode.LOP_JUMP] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local offset = LUAU_INSN_D(insn);
    state.pc += offset;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPBACK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local offset = LUAU_INSN_D(insn);
    state.pc += offset;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFNOT] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    if not state.stack[id] then
        state.pc += offset;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFEQ] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];

    if state.stack[id] == state.stack[aux] then
        state.pc += offset;
    else
        state.pc += 1;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFLE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];

    if state.stack[id] <= state.stack[aux] then
        state.pc += offset;
    else
        state.pc += 1;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFLT] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];

    if state.stack[id] < state.stack[aux] then
        state.pc += offset;
    else
        state.pc += 1;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFNOTEQ] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];

    if state.stack[id] ~= state.stack[aux] then
        state.pc += offset;
    else
        state.pc += 1;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFNOTLE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];

    if state.stack[id] > state.stack[aux] then
        state.pc += offset;
    else
        state.pc += 1;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFNOTLT] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];

    if state.stack[id] >= state.stack[aux] then
        state.pc += offset;
    else
        state.pc += 1;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_FASTCALL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;
    local bfid = LUAU_INSN_A(insn);
    local skip = LUAU_INSN_C(insn);

    local call = state.proto.code[state.pc + skip];
    assert(LUAU_INSN_OP(call) == LuauOpcode.LOP_CALL);

    local id = LUAU_INSN_A(call);

    local nparams = LUAU_INSN_B(call) - 1;
    local nresults = LUAU_INSN_C(call) - 1;

    local params = nparams == LUA_MULTRET and state.top - id or nparams;
    local func = fast_functions[bfid];
    local ret = table.pack(func(table.unpack(state.stack, id + 1, id + params)));
    local nres = ret.n;

    if nresults == LUA_MULTRET then
        state.top = id + nres - 1;
    else
        state.top = -1;
        nres = nresults;
    end;
    
    if ret.n >= 0 then
        state.pc += skip + 1;  -- skip instructions that compute function as well as CALL
        table.move(ret, 1, nres, id, state.stack);
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_CAPTURE] = function(state:lobject.ClosureState)
    error("CAPTURE is a pseudo-opcode and must be executed as part of NEWCLOSURE");
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFEQK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];
    state.pc += 1;
    
    local const = state.proto.k[aux];

    if state.stack[id] == const then
        state.pc += offset;
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPIFNOTEQK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];
    state.pc += 1;
    
    local const = state.proto.k[aux];

    if state.stack[id] ~= const then
        state.pc += offset;
    end;
end;


OP_TO_CALL[LuauOpcode.LOP_FASTCALL1] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    -- we consider safe all non vararg functions
    if state.proto.is_vararg == false then
        local bfid = LUAU_INSN_A(insn);
        local skip = LUAU_INSN_C(insn);
        -- local aux = state.proto.code[state.pc];

        local call = state.proto.code[state.pc + skip];
        assert(LUAU_INSN_OP(call) == LuauOpcode.LOP_CALL);

        local id = LUAU_INSN_A(call);
        local nresults = LUAU_INSN_C(call) - 1;

        local func = fast_functions[bfid];
        local arg1 = state.stack[LUAU_INSN_B(insn)];

        local ret = table.pack(func(arg1));
        local nres = ret.n;

        if nresults == LUA_MULTRET then
            state.top = id + nres - 1;
        else
            state.top = -1;
            nres = nresults;
        end;

        state.pc += skip + 1;  -- skip instructions that compute function as well as CALL
        table.move(ret, 1, nres, id, state.stack);
    end
end;

OP_TO_CALL[LuauOpcode.LOP_FASTCALL2] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    -- we consider safe all non vararg functions
    if state.proto.is_vararg == false then
        local bfid = LUAU_INSN_A(insn);
        local skip = LUAU_INSN_C(insn);
        local aux = state.proto.code[state.pc];

        local call = state.proto.code[state.pc + skip];
        assert(LUAU_INSN_OP(call) == LuauOpcode.LOP_CALL);

        local id = LUAU_INSN_A(call);
        local nresults = LUAU_INSN_C(call) - 1;

        local func = fast_functions[bfid];
        local arg1 = state.stack[LUAU_INSN_B(aux)];
        local arg2 = state.stack[aux];
        local ret = table.pack(func(arg1, arg2));
        local nres = ret.n;

        if nresults == LUA_MULTRET then
            state.top = id + nres - 1;
        else
            state.top = -1;
            nres = nresults;
        end;
        
        state.pc += skip + 1;  -- skip instructions that compute function as well as CALL
        table.move(ret, 1, nres, id, state.stack);
    else
        state.pc += 1; -- skip aux
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_FASTCALL2K] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    -- we consider safe all non vararg functions
    if state.proto.is_vararg == false then
        local bfid = LUAU_INSN_A(insn);
        local skip = LUAU_INSN_C(insn);
        local aux = state.proto.code[state.pc];

        local call = state.proto.code[state.pc + skip];
        assert(LUAU_INSN_OP(call) == LuauOpcode.LOP_CALL);

        local id = LUAU_INSN_A(call);
        local nresults = LUAU_INSN_C(call) - 1;

        local func = fast_functions[bfid];
        local arg1 = state.stack[LUAU_INSN_B(insn)];
        local arg2 = state.proto.k[aux];
        local ret = table.pack(func(arg1, arg2));
        local nres = ret.n;

        if nresults == LUA_MULTRET then
            state.top = id + nres - 1;
        else
            state.top = -1;
            nres = nresults;
        end;
        
        state.pc += skip + 1;  -- skip instructions that compute function as well as CALL
        table.move(ret, 1, nres, id, state.stack);
    else
        state.pc += 1; -- skip aux
    end;
end;

-- ADD, SUB, MUL, DIV, MOD, POW: compute arithmetic operation between two source registers
OP_TO_CALL[LuauOpcode.LOP_ADD] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.stack[LUAU_INSN_C(insn)];

    state.stack[id] = b + c;
end;

OP_TO_CALL[LuauOpcode.LOP_SUB] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.stack[LUAU_INSN_C(insn)];

    state.stack[id] = b - c;
end;

OP_TO_CALL[LuauOpcode.LOP_MUL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.stack[LUAU_INSN_C(insn)];

    state.stack[id] = b * c;
end;

OP_TO_CALL[LuauOpcode.LOP_DIV] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.stack[LUAU_INSN_C(insn)];

    state.stack[id] = b / c;
end;

OP_TO_CALL[LuauOpcode.LOP_MOD] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.stack[LUAU_INSN_C(insn)];

    state.stack[id] = b % c;
end;

OP_TO_CALL[LuauOpcode.LOP_POW] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.stack[LUAU_INSN_C(insn)];

    state.stack[id] = b ^ c;
end;

-- ADDK, SUBK, MULK, DIVK, MODK, POWK: compute arithmetic operation between the source register and a constant and put the result into target register
OP_TO_CALL[LuauOpcode.LOP_ADDK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.proto.k[LUAU_INSN_C(insn)];

    state.stack[id] = b + c;
end;

OP_TO_CALL[LuauOpcode.LOP_SUBK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.proto.k[LUAU_INSN_C(insn)];

    state.stack[id] = b - c;
end;

OP_TO_CALL[LuauOpcode.LOP_MULK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.proto.k[LUAU_INSN_C(insn)];

    state.stack[id] = b * c;
end;

OP_TO_CALL[LuauOpcode.LOP_DIVK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.proto.k[LUAU_INSN_C(insn)];

    state.stack[id] = b / c;
end;

OP_TO_CALL[LuauOpcode.LOP_MODK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.proto.k[LUAU_INSN_C(insn)];

    state.stack[id] = b % c;
end;

OP_TO_CALL[LuauOpcode.LOP_POWK] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = state.stack[LUAU_INSN_B(insn)];
    local c = state.proto.k[LUAU_INSN_C(insn)];

    state.stack[id] = b ^ c;
end;

OP_TO_CALL[LuauOpcode.LOP_CONCAT] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);

    local b = LUAU_INSN_B(insn);
    local c = LUAU_INSN_C(insn);

    local str = "";

    for i = b, c do
        str = str .. state.stack[i];
    end

    state.stack[id] = str;
end;

OP_TO_CALL[LuauOpcode.LOP_NOT] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local operand = state.stack[LUAU_INSN_B(insn)];

    state.stack[id] = not operand;
end;

OP_TO_CALL[LuauOpcode.LOP_MINUS] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local operand = state.stack[LUAU_INSN_B(insn)];

    state.stack[id] = -operand;
end;

OP_TO_CALL[LuauOpcode.LOP_LENGTH] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local operand = state.stack[LUAU_INSN_B(insn)];

    state.stack[id] = #operand;
end;

OP_TO_CALL[LuauOpcode.LOP_NEWTABLE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local nhash = LUAU_INSN_B(insn);
    local aux = state.proto.code[state.pc];
    state.pc += 1;

    state.stack[id] = table.create(aux);
end;

OP_TO_CALL[LuauOpcode.LOP_DUPTABLE] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local c = state.proto.k[LUAU_INSN_D(insn)];

    state.stack[id] = table.clone(c);
end;

OP_TO_CALL[LuauOpcode.LOP_SETLIST] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);
    local c = LUAU_INSN_C(insn) - 1;
    local idx = state.proto.code[state.pc];
    state.pc += 1;

    if c == LUA_MULTRET then
        c = state.top - id2;
    end

    local t = state.stack[id];
    --[[ DEBUG PURPOSE
    for i = 0, c - 1 do
        print(idx + i, state.stack[id2 + i])
        t[idx + i - 1] = state.stack[id2 + i - 1];
    end]]
    table.move(state.stack, id2, id2 + c, idx, t);
end;

OP_TO_CALL[LuauOpcode.LOP_FORNPREP] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);

    local limit = state.stack[id];
    local step = state.stack[id + 1];
    local index = state.stack[id + 2];
    
    state.pc += ((step > 0 and index <= limit) or limit <= index) and 0 or offset;
    if (step > 0) then
        if index > limit then
            state.pc += offset;
        end
    elseif limit > index then
        state.pc += offset;
    end
end;

OP_TO_CALL[LuauOpcode.LOP_FORNLOOP] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);

    local limit = state.stack[id];
    local step = state.stack[id + 1];
    local index = state.stack[id + 2] + step;
    state.stack[id + 2] = index;

    if step > 0 then
        if index <= limit then
            state.pc += offset;
        end
    elseif limit <= index  then
        state.pc += offset;
    end
end;

OP_TO_CALL[LuauOpcode.LOP_FORGLOOP] = function(state:lobject.ClosureState)
    local insn = state.insn;
    local stack = state.stack;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local offset = LUAU_INSN_D(insn);
    local aux = state.proto.code[state.pc];
    local nres = bit32.band(aux, 0xf);

    local generator = stack[id];
    local h =  state.stack[id + 1];
    local index = state.stack[id + 2];

    local vars = table.pack(generator(h, index));
    table.move(vars, 1, nres, id + 3, stack);

    -- update index
    stack[id + 2] = vars[1];
    
    if stack[id + 3] == nil then
        state.pc += 1;
    else
        state.pc += offset;
    end
end;

OP_TO_CALL[LuauOpcode.LOP_FORGPREP_INEXT] = function(state:lobject.ClosureState)
    state.pc += 1;
    state.pc += LUAU_INSN_D(state.insn);
end;

OP_TO_CALL[LuauOpcode.LOP_FORGPREP_NEXT] = function(state:lobject.ClosureState)
    state.pc += 1;
    state.pc += LUAU_INSN_D(state.insn);
end;

OP_TO_CALL[LuauOpcode.LOP_GETVARARGS] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local n = LUAU_INSN_B(insn) - 1;
    local vararg = state.vararg;

    if n == LUA_MULTRET then
        n = vararg.n;
        state.top = id + n;
    end

    table.move(vararg, 1, n, id, state.stack);
end;

OP_TO_CALL[LuauOpcode.LOP_DUPCLOSURE] = function(state:lobject.ClosureState)
    state.pc += 1;
    local id = LUAU_INSN_A(state.insn);
    local id2 = LUAU_INSN_D(state.insn);

    local nproto = state.proto.k[id2];
    local upsref = table.create(nproto.nups);

    for i = 0, nproto.nups-1 do
        local uinsn = state.proto.code[state.pc + i];
        assert(LUAU_INSN_OP(uinsn) == LuauOpcode.LOP_CAPTURE);

        local uv;
        if LUAU_INSN_A(uinsn) == LuauCaptureType.LCT_VAL then
            uv = new_upval(state.stack, LUAU_INSN_B(uinsn));
        else
            uv = state.proto.upvalues[LUAU_INSN_B(uinsn)];
        end
        upsref[i] = uv;
    end;

    state.pc += nproto.nups;
    state.stack[id] = wrap_proto(nproto, state.env, upsref);
end;

OP_TO_CALL[LuauOpcode.LOP_PREPVARARGS] = function(state:lobject.ClosureState)
    state.pc += 1;
    -- local nparams = LUAU_INSN_A(state.insn);
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPXEQKN] = function(state:lobject.ClosureState)
    state.pc += 1;
    local aux = state.proto.code[state.pc];
    local id = LUAU_INSN_A(state.insn);
    local kv = state.proto.k[bit32.band(aux, 0xffffff)];
    -- assert(type(kv) == 'number');

    local b = bit32.rshift(aux, 31) == 1;
    if (state.stack[id] == kv) ~= b then
        state.pc += LUAU_INSN_D(state.insn);
    else
        state.pc += 1;
    end
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPXEQKNIL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;
    -- local aux = state.proto.code[state.pc];
    state.pc += 1;

    local v = state.stack[LUAU_INSN_A(insn)];
    state.pc += (v == nil) and LUAU_INSN_D(insn) or 0;
end;


OP_TO_CALL[LuauOpcode.LOP_JUMPXEQKS] = function(state:lobject.ClosureState)
    state.pc += 1;
    local aux = state.proto.code[state.pc];
    local id = LUAU_INSN_A(state.insn);
    local kv = state.proto.k[bit32.band(aux, 0xffffff)];
    -- assert(type(kv) == 'string');

    local b = bit32.rshift(aux, 31) == 1;
    if (state.stack[id] == kv) ~= b then
        state.pc += LUAU_INSN_D(state.insn);
    else
        state.pc += 1;
    end
end;

return {
    wrap_proto = wrap_proto
};