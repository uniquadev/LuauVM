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
local OP_TO_CALL = table.create(#bytecode.LuauOpcode);
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

local function luaF_findupval(state:lobject.ClosureState, id:number) : lobject.UpVal
    local open_list = state.open_list;
    local uv = open_list[id];
    if uv then
        return uv;
    end
    uv = {
        id = id,
        stack = state.stack
    };
    open_list[id] = uv;
    return uv;
end;

local function luaF_close(state:lobject.ClosureState, level:number)
    local open_list = state.open_list;
    for i, uv in pairs(open_list) do
        if uv.id >= level then
            uv.stack = uv;
            uv.id = '_';
            open_list[i] = nil;
        end
    end
end;

-- initialize closure state and wrap it inside a real closure
function wrap_proto(proto:lobject.Proto, env, ups)
    assert(type(proto) == "table", "wrap_proto: proto is not a table");

    -- solve env
    env = env or getfenv(1); -- get env of the calling function
    -- wrap proto
    return function(...)
        -- solve vararg
        local args = {unpack({...}, 1, proto.numparams)};
        -- define closure state
        local state : lobject.ClosureState = {
            run = true,
            proto = proto,
            ret = {},
            pc = 0,
            insn = 0,
            env = env,
            vararg = args,
            ups = ups,
            open_list = {},
            stack = table.create(proto.maxstacksize),
            top = -1
        };
        -- load args in stack
        for i = 1, #args do
            state.stack[i-1] = args[i];
        end;
        -- run closure
        local res = table.pack(pcall(luau_execute, state));
        -- check res integrity
        if res[1] then
            return table.unpack(res, 2);
        end;
        -- execution error handling
        error(res[2]); -- TODO lineinfo etc.
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
    local uv : lobject.UpVal = state.ups[id2];
    state.stack[id] = uv.stack[uv.id];
end;

OP_TO_CALL[LuauOpcode.LOP_SETUPVAL] = function(state:lobject.ClosureState)
    local insn = state.insn;
    state.pc += 1;

    local id = LUAU_INSN_A(insn);
    local id2 = LUAU_INSN_B(insn);
    local uv : lobject.UpVal = state.ups[id2];
    uv.stack[uv.id] = state.stack[id];
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

OP_TO_CALL[LuauOpcode.LOP_NEWCLOSURE] = function(state:lobject.ClosureState)
    state.pc += 1;

    local id = LUAU_INSN_A(state.insn);
    local proto = state.proto.p[LUAU_INSN_D(state.insn)];
    local ups = {};

    for i = 0, proto.nups - 1 do
        local uinst = state.proto.code[state.pc];
        state.pc += 1;
        local ctype = LUAU_INSN_A(uinst); -- capture type
        local id = LUAU_INSN_B(uinst); -- capture id
        if ctype == LuauCaptureType.LCT_VAL then
            ups[i] = state.stack[id];
        elseif ctype == LuauCaptureType.LCT_REF then
            ups[i] = luaF_findupval(state, id);
        elseif ctype == LuauCaptureType.LCT_UPVAL then
            ups[i] = state.ups[id];
        end
    end;
    state.stack[id] = wrap_proto(proto, state.env, ups);
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

    if nresults == 0 then
        state.top = id + nres - 1;
    else
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

    if b == LUA_MULTRET then
        nresults = state.top - id + 1;
    else
        nresults = id + b - 1;
    end;    

    state.ret = table.pack(table.unpack(state.stack, id, id + nresults-1));
end;

OP_TO_CALL[LuauOpcode.LOP_JUMP] = function(state:lobject.ClosureState)
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

    if ret.n >= 0 then
        state.top = nresults == LUA_MULTRET and id + ret.n or -1;
        state.pc += skip + 1;  -- skip instructions that compute function as well as CALL
        table.move(ret, 1, nresults, id, state.stack);
    end;
end;

OP_TO_CALL[LuauOpcode.LOP_CAPTURE] = function(state:lobject.ClosureState)
    error("CAPTURE is a pseudo-opcode and must be executed as part of NEWCLOSURE");
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

OP_TO_CALL[LuauOpcode.LOP_DUPCLOSURE] = function(state:lobject.ClosureState)
    state.pc += 1;
    local id = LUAU_INSN_A(state.insn);
    local id2 = LUAU_INSN_D(state.insn);

    local nproto = state.proto.k[id2];
    state.stack[id] = wrap_proto(nproto, state.env);

    state.pc += nproto.nups;
end;

OP_TO_CALL[LuauOpcode.LOP_PREPVARARGS] = function(state:lobject.ClosureState)
    state.pc += 1;
    local nparams = LUAU_INSN_A(state.insn);

    assert(state.top+1 >= nparams);

    for i = 0, nparams do
        state.stack[i] = nil;
    end
end;

OP_TO_CALL[LuauOpcode.LOP_JUMPXEQKN] = function(state:lobject.ClosureState)
    state.pc += 1;
    local aux = state.proto.code[state.pc];
    local id = LUAU_INSN_A(state.insn);
    local kv = state.proto.k[bit32.band(aux, 0xffffff)];
    -- assert(type(kv) == 'number');

    local b = bit32.rshift(aux, 31) == 1;
    if (state.stack[id] == kv) ~= b then
        state.pc += LUAU_INSN_D(aux);
    else
        state.pc += 1;
    end
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