export type Instruction = number; -- 4 bytes data

export type Proto = {
  code: {Instruction},
  k: {any},               -- constants used by the function, TValue is not necessary
  p: {Proto},             -- protos defined inside the proto

  abslineinfo: number?,   -- baseline line info, one entry for each 1<<linegaplog2 instructions; allocated after lineinfo
  lineinfo: {number}?,    -- for each instruction, line number as a delta from baseline

  upvalues: {string},     -- upvalue names, allocated after code
  locvars: {any}?,        -- local variables defined in this proto

  debugname: string?,     -- name of the function for debug purposes

  nups: number,           -- number of upvalues
  numparams: number,      -- number of parameters
  is_vararg: boolean,
  maxstacksize: number,
  linedefined: number
};

export type ClosureState = {
  run: boolean,            -- whether the closure is running
  ret: {any},              -- return value of the function
  proto: Proto,
  insn: Instruction,       -- current instruction
  pc: number,              -- program counter
  env: {any},              -- environment of the function
  vararg: {any},
  ups: {any},              -- upvalues
  stack: {any},            -- aka memory
  top: number              -- top free slot of the stack
};

return {};