local fast_functions = {
    [0] = nil,
    assert,

    math.abs,
    math.acos,
    math.asin,
    math.atan2,
    math.atan,
    math.ceil,
    math.cosh,
    math.cos,
    math.deg,
    math.exp,
    math.floor,
    math.fmod,
    math.frexp,
    math.ldexp,
    math.log10,
    math.log,
    math.max,
    math.min,
    math.modf,
    math.pow,
    math.rad,
    math.sinh,
    math.sin,
    math.sqrt,
    math.tanh,
    math.tan,

    bit32.arshift,
    bit32.band,
    bit32.bnot,
    bit32.bor,
    bit32.bxor,
    bit32.btest,
    bit32.extract,
    bit32.lrotate,
    bit32.lshift,
    bit32.replace,
    bit32.rrotate,
    bit32.rshift,

    type,

    string.byte,
    string.char,
    string.len,

    typeof,

    string.sub,

    math.clamp,
    math.sign,
    math.round,

    rawset,
    rawget,
    rawequal,

    table.insert,
    table.unpack,

    nil, -- vector

    bit32.countlz,
    bit32.countrz,

    select,

    rawlen,
};

return {
    fast_functions = fast_functions
}