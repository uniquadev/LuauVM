-- imports
local lobject = require("./VM/luau/lobject");
local bytecode = require("./VM/luau/bytecode");
local lvmload = require("./VM/luau/lvmload");
local lbuiltins = require("./VM/luau/lbuiltins");

local LuauOpcode = bytecode.LuauOpcode;
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
local function SIGNED_INT(int:number) return int - 2 ^ 32; end;

-- retrive instruction opcode
local function LUAU_INSN_OP(inst:lobject.Instruction) return bit32.band(inst, 0xff); end;
-- ABC encoding: three 8-bit values, containing registers or small numbers
local function LUAU_INSN_A(insn:lobject.Instruction) return bit32.band(bit32.rshift(insn, 8), 0xff); end;
local function LUAU_INSN_B(insn:lobject.Instruction) return bit32.band(bit32.rshift(insn, 16), 0xff); end;
local function LUAU_INSN_C(insn:lobject.Instruction) return bit32.band(bit32.rshift(insn, 24), 0xff); end;

-- AD encoding: one 8-bit value, one signed 16-bit value
local function LUAU_INSN_D(insn:lobject.Instruction) return bit32.rshift(SIGNED_INT(insn), 16) end;

-- E encoding: one signed 24-bit value
local function LUAU_INSN_E(insn:lobject.Instruction) return bit32.rshift(SIGNED_INT(insn), 8) end;

-- initialize closure state and wrap it inside a real closure
function wrap_proto(proto:lobject.Proto, env, upval)
    -- solve env
    env = env or getfenv(1); -- get env of the calling function
    -- wrap proto
    return function(...)
        -- solve vararg
        local args = {...};
        if proto.numparams < #args then
            args = {unpack(args, 1, proto.numparams)};
        end;
        -- define closure state
        local state : lobject.ClosureState = {
            run = true,
            proto = proto,
            ret = {},
            pc = 0,
            insn = 0,
            env = env,
            vararg = args,
            stack = table.create(proto.maxstacksize),
            top = -1
        };
        -- run closure
        local res = table.pack(pcall(luau_execute, state, env, upval));
        -- check res integrity
        if res[1] then
            return table.unpack(res, 2);
        end;
        -- execution error handling
        error(res[2]); -- TODO lineinfo etc.
    end;
end;

-- vm
luau_execute = function(state:lobject.ClosureState, env, upval)
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
    local op = LUAU_INSN_OP(insn);
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
        nres = nresults - 1;
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

OP_TO_CALL[LuauOpcode.LOP_PREPVARARGS] = function(state:lobject.ClosureState)
    state.pc += 1;
end;

return {
    wrap_proto = wrap_proto
};