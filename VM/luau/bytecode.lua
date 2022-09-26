-- https://github.com/Roblox/luau/blob/2daa6497a17348090f6af6716e4f856c44594279/Common/include/Luau/Bytecode.h

local LuauOpcode =
{
    -- NOP: noop
    LOP_NOP = 0,

    -- BREAK: debugger break
    LOP_BREAK = 1,

    -- LOADNIL: sets register to nil
    -- A: target register
    LOP_LOADNIL = 2,

    -- LOADB: sets register to boolean and jumps to a given short offset (used to compile comparison results into a boolean)
    -- A: target register
    -- B: value (0/1)
    -- C: jump offset
    LOP_LOADB = 3,

    -- LOADN: sets register to a number literal
    -- A: target register
    -- D: value (-32768..32767)
    LOP_LOADN = 4,

    -- LOADK: sets register to an entry from the constant table from the proto (number/string)
    -- A: target register
    -- D: constant table index (0..32767)
    LOP_LOADK = 5,

    -- MOVE: move (copy) value from one register to another
    -- A: target register
    -- B: source register
    LOP_MOVE = 6,

    -- GETGLOBAL: load value from global table using constant string as a key
    -- A: target register
    -- C: predicted slot index (based on hash)
    -- AUX: constant table index
    LOP_GETGLOBAL = 7,

    -- SETGLOBAL: set value in global table using constant string as a key
    -- A: source register
    -- C: predicted slot index (based on hash)
    -- AUX: constant table index
    LOP_SETGLOBAL = 8,

    -- GETUPVAL: load upvalue from the upvalue table for the current function
    -- A: target register
    -- B: upvalue index (0..255)
    LOP_GETUPVAL = 9,

    -- SETUPVAL: store value into the upvalue table for the current function
    -- A: target register
    -- B: upvalue index (0..255)
    LOP_SETUPVAL = 10,

    -- CLOSEUPVALS: close (migrate to heap) all upvalues that were captured for registers >= target
    -- A: target register
    LOP_CLOSEUPVALS = 11,

    -- GETIMPORT: load imported global table global from the constant table
    -- A: target register
    -- D: constant table index (0..32767); we assume that imports are loaded into the constant table
    -- AUX: 3 10-bit indices of constant strings that, combined, constitute an import path; length of the path is set by the top 2 bits (1,2,3)
    LOP_GETIMPORT = 12,

    -- GETTABLE: load value from table into target register using key from register
    -- A: target register
    -- B: table register
    -- C: index register
    LOP_GETTABLE = 13,

    -- SETTABLE: store source register into table using key from register
    -- A: source register
    -- B: table register
    -- C: index register
    LOP_SETTABLE = 14,

    -- GETTABLEKS: load value from table into target register using constant string as a key
    -- A: target register
    -- B: table register
    -- C: predicted slot index (based on hash)
    -- AUX: constant table index
    LOP_GETTABLEKS = 15,

    -- SETTABLEKS: store source register into table using constant string as a key
    -- A: source register
    -- B: table register
    -- C: predicted slot index (based on hash)
    -- AUX: constant table index
    LOP_SETTABLEKS = 16,

    -- GETTABLEN: load value from table into target register using small integer index as a key
    -- A: target register
    -- B: table register
    -- C: index-1 (index is 1..256)
    LOP_GETTABLEN = 17,

    -- SETTABLEN: store source register into table using small integer index as a key
    -- A: source register
    -- B: table register
    -- C: index-1 (index is 1..256)
    LOP_SETTABLEN = 18,

    -- NEWCLOSURE: create closure from a child proto; followed by a CAPTURE instruction for each upvalue
    -- A: target register
    -- D: child proto index (0..32767)
    LOP_NEWCLOSURE = 19,

    -- NAMECALL: prepare to call specified method by name by loading function from source register using constant index into target register and copying source register into target register + 1
    -- A: target register
    -- B: source register
    -- C: predicted slot index (based on hash)
    -- AUX: constant table index
    -- Note that this instruction must be followed directly by CALL; it prepares the arguments
    -- This instruction is roughly equivalent to GETTABLEKS + MOVE pair, but we need a special instruction to support custom __namecall metamethod
    LOP_NAMECALL = 20,

    -- CALL: call specified function
    -- A: register where the function object lives, followed by arguments; results are placed starting from the same register
    -- B: argument count + 1, or 0 to preserve all arguments up to top (MULTRET)
    -- C: result count + 1, or 0 to preserve all values and adjust top (MULTRET)
    LOP_CALL = 21,

    -- RETURN: returns specified values from the function
    -- A: register where the returned values start
    -- B: number of returned values + 1, or 0 to return all values up to top (MULTRET)
    LOP_RETURN = 22,

    -- JUMP: jumps to target offset
    -- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
    LOP_JUMP = 23,

    -- JUMPBACK: jumps to target offset; this is equivalent to JUMP but is used as a safepoint to be able to interrupt while/repeat loops
    -- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
    LOP_JUMPBACK = 24,

    -- JUMPIF: jumps to target offset if register is not nil/false
    -- A: source register
    -- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
    LOP_JUMPIF = 25,

    -- JUMPIFNOT: jumps to target offset if register is nil/false
    -- A: source register
    -- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
    LOP_JUMPIFNOT = 26,

    -- JUMPIFEQ, JUMPIFLE, JUMPIFLT, JUMPIFNOTEQ, JUMPIFNOTLE, JUMPIFNOTLT: jumps to target offset if the comparison is true (or false, for NOT variants)
    -- A: source register 1
    -- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
    -- AUX: source register 2
    LOP_JUMPIFEQ = 27,
    LOP_JUMPIFLE = 28,
    LOP_JUMPIFLT = 29,
    LOP_JUMPIFNOTEQ = 30,
    LOP_JUMPIFNOTLE = 31,
    LOP_JUMPIFNOTLT = 32,

    -- ADD, SUB, MUL, DIV, MOD, POW: compute arithmetic operation between two source registers and put the result into target register
    -- A: target register
    -- B: source register 1
    -- C: source register 2
    LOP_ADD = 33,
    LOP_SUB = 34,
    LOP_MUL = 35,
    LOP_DIV = 36,
    LOP_MOD = 37,
    LOP_POW = 38,

    -- ADDK, SUBK, MULK, DIVK, MODK, POWK: compute arithmetic operation between the source register and a constant and put the result into target register
    -- A: target register
    -- B: source register
    -- C: constant table index (0..255)
    LOP_ADDK = 39,
    LOP_SUBK = 40,
    LOP_MULK = 41,
    LOP_DIVK = 42,
    LOP_MODK = 43,
    LOP_POWK = 44,

    -- AND, OR: perform `and` or `or` operation (selecting first or second register based on whether the first one is truthy) and put the result into target register
    -- A: target register
    -- B: source register 1
    -- C: source register 2
    LOP_AND = 45,
    LOP_OR = 46,

    -- ANDK, ORK: perform `and` or `or` operation (selecting source register or constant based on whether the source register is truthy) and put the result into target register
    -- A: target register
    -- B: source register
    -- C: constant table index (0..255)
    LOP_ANDK = 47,
    LOP_ORK = 48,

    -- CONCAT: concatenate all strings between B and C (inclusive) and put the result into A
    -- A: target register
    -- B: source register start
    -- C: source register end
    LOP_CONCAT = 49,

    -- NOT, MINUS, LENGTH: compute unary operation for source register and put the result into target register
    -- A: target register
    -- B: source register
    LOP_NOT = 50,
    LOP_MINUS = 51,
    LOP_LENGTH = 52,

    -- NEWTABLE: create table in target register
    -- A: target register
    -- B: table size, stored as 0 for v=0 and ceil(log2(v))+1 for v!=0
    -- AUX: array size
    LOP_NEWTABLE = 53,

    -- DUPTABLE: duplicate table using the constant table template to target register
    -- A: target register
    -- D: constant table index (0..32767)
    LOP_DUPTABLE = 54,

    -- SETLIST: set a list of values to table in target register
    -- A: target register
    -- B: source register start
    -- C: value count + 1, or 0 to use all values up to top (MULTRET)
    -- AUX: table index to start from
    LOP_SETLIST = 55,

    -- FORNPREP: prepare a numeric for loop, jump over the loop if first iteration doesn't need to run
    -- A: target register; numeric for loops assume a register layout [limit, step, index, variable]
    -- D: jump offset (-32768..32767)
    -- limit/step are immutable, index isn't visible to user code since it's copied into variable
    LOP_FORNPREP = 56,

    -- FORNLOOP: adjust loop variables for one iteration, jump back to the loop header if loop needs to continue
    -- A: target register; see FORNPREP for register layout
    -- D: jump offset (-32768..32767)
    LOP_FORNLOOP = 57,

    -- FORGLOOP: adjust loop variables for one iteration of a generic for loop, jump back to the loop header if loop needs to continue
    -- A: target register; generic for loops assume a register layout [generator, state, index, variables...]
    -- D: jump offset (-32768..32767)
    -- AUX: variable count (1..255) in the low 8 bits, high bit indicates whether to use ipairs-style traversal in the fast path
    -- loop variables are adjusted by calling generator(state, index) and expecting it to return a tuple that's copied to the user variables
    -- the first variable is then copied into index; generator/state are immutable, index isn't visible to user code
    LOP_FORGLOOP = 58,

    -- FORGPREP_INEXT/FORGLOOP_INEXT: FORGLOOP with 2 output variables (no AUX encoding), assuming generator is luaB_inext
    -- FORGPREP_INEXT prepares the index variable and jumps to FORGLOOP_INEXT
    -- FORGLOOP_INEXT has identical encoding and semantics to FORGLOOP (except for AUX encoding)
    LOP_FORGPREP_INEXT = 59,
    LOP_FORGLOOP_INEXT = 60,

    -- FORGPREP_NEXT/FORGLOOP_NEXT: FORGLOOP with 2 output variables (no AUX encoding), assuming generator is luaB_next
    -- FORGPREP_NEXT prepares the index variable and jumps to FORGLOOP_NEXT
    -- FORGLOOP_NEXT has identical encoding and semantics to FORGLOOP (except for AUX encoding)
    LOP_FORGPREP_NEXT = 61,
    LOP_FORGLOOP_NEXT = 62,

    -- GETVARARGS: copy variables into the target register from vararg storage for current function
    -- A: target register
    -- B: variable count + 1, or 0 to copy all variables and adjust top (MULTRET)
    LOP_GETVARARGS = 63,

    -- DUPCLOSURE: create closure from a pre-created function object (reusing it unless environments diverge)
    -- A: target register
    -- D: constant table index (0..32767)
    LOP_DUPCLOSURE = 64,

    -- PREPVARARGS: prepare stack for variadic functions so that GETVARARGS works correctly
    -- A: number of fixed arguments
    LOP_PREPVARARGS = 65,

    -- LOADKX: sets register to an entry from the constant table from the proto (number/string)
    -- A: target register
    -- AUX: constant table index
    LOP_LOADKX = 66,

    -- JUMPX: jumps to the target offset; like JUMPBACK, supports interruption
    -- E: jump offset (-2^23..2^23; 0 means "next instruction" aka "don't jump")
    LOP_JUMPX = 67,

    -- FASTCALL: perform a fast call of a built-in function
    -- A: builtin function id (see LuauBuiltinFunction)
    -- C: jump offset to get to following CALL
    -- FASTCALL is followed by one of (GETIMPORT, MOVE, GETUPVAL) instructions and by CALL instruction
    -- This is necessary so that if FASTCALL can't perform the call inline, it can continue normal execution
    -- If FASTCALL *can* perform the call, it jumps over the instructions *and* over the next CALL
    -- Note that FASTCALL will read the actual call arguments, such as argument/result registers and counts, from the CALL instruction
    LOP_FASTCALL = 68,

    -- COVERAGE: update coverage information stored in the instruction
    -- E: hit count for the instruction (0..2^23-1)
    -- The hit count is incremented by VM every time the instruction is executed, and saturates at 2^23-1
    LOP_COVERAGE = 69,

    -- CAPTURE: capture a local or an upvalue as an upvalue into a newly created closure; only valid after NEWCLOSURE
    -- A: capture type, see LuauCaptureType
    -- B: source register (for VAL/REF) or upvalue index (for UPVAL/UPREF)
    LOP_CAPTURE = 70,

    -- JUMPIFEQK, JUMPIFNOTEQK: jumps to target offset if the comparison with constant is true (or false, for NOT variants)
    -- A: source register 1
    -- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
    -- AUX: constant table index
    LOP_JUMPIFEQK = 71,
    LOP_JUMPIFNOTEQK = 72,

    -- FASTCALL1: perform a fast call of a built-in function using 1 register argument
    -- A: builtin function id (see LuauBuiltinFunction)
    -- B: source argument register
    -- C: jump offset to get to following CALL
    LOP_FASTCALL1 = 73,

    -- FASTCALL2: perform a fast call of a built-in function using 2 register arguments
    -- A: builtin function id (see LuauBuiltinFunction)
    -- B: source argument register
    -- C: jump offset to get to following CALL
    -- AUX: source register 2 in least-significant byte
    LOP_FASTCALL2 = 74,

    -- FASTCALL2K: perform a fast call of a built-in function using 1 register argument and 1 constant argument
    -- A: builtin function id (see LuauBuiltinFunction)
    -- B: source argument register
    -- C: jump offset to get to following CALL
    -- AUX: constant index
    LOP_FASTCALL2K = 75,

    -- FORGPREP: prepare loop variables for a generic for loop, jump to the loop backedge unconditionally
    -- A: target register; generic for loops assume a register layout [generator, state, index, variables...]
    -- D: jump offset (-32768..32767)
    LOP_FORGPREP = 76,

    -- Enum entry for number of opcodes, not a valid opcode by itself!
    LOP__COUNT = 77
};

local function get_op_name(op:number) : string?
    for name, op2 in next, LuauOpcode do
        if op2 == op then
            return name
        end
    end;
    return;
end;

-- Bytecode version; runtime supports [MIN, MAX], compiler emits TARGET by default but may emit a higher version when flags are enabled
local LBC_VERSION_MIN = 2;
local LBC_VERSION_MAX = 3;
local LBC_VERSION_TARGET = 3; -- (tested on)

-- Bytecode tags, used internally for bytecode encoded as a string
local LuauBytecodeTag =
{
    -- Types of constant table entries
    LBC_CONSTANT_NIL = 0,
    LBC_CONSTANT_BOOLEAN = 1,
    LBC_CONSTANT_NUMBER = 2,
    LBC_CONSTANT_STRING = 3,
    LBC_CONSTANT_IMPORT = 4,
    LBC_CONSTANT_TABLE = 5,
    LBC_CONSTANT_CLOSURE = 6
};
local LuauCaptureType =
{
    LCT_VAL = 0,
    LCT_REF = 1,
    LCT_UPVAL = 2
};

return {
    get_op_name = get_op_name,
    LuauOpcode = LuauOpcode,
    LuauBytecodeTag = LuauBytecodeTag,
    LuauCaptureType = LuauCaptureType,
    LBC_VERSION_MIN = LBC_VERSION_MIN,
    LBC_VERSION_MAX = LBC_VERSION_MAX,
    LBC_VERSION_TARGET = LBC_VERSION_TARGET
};