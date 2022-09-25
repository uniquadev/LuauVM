-- type
export type read_func = (st:ByteStream)->number

export type ByteStream = {
  data: string,
  pos: number,
  size: number,
  read: read_func,
  read_4: read_func,
  read_double: read_func
};

-- double rd_dbl_basic(byte f1..8)
-- @f1..8 - The 8 bytes composing a little endian double
local function rd_dbl_basic(f1, f2, f3, f4, f5, f6, f7, f8)
	local sign = (-1) ^ bit32.rshift(f8, 7)
	local exp = bit32.lshift(bit32.band(f8, 0x7F), 4) + bit32.rshift(f7, 4)
	local frac = bit32.band(f7, 0x0F) * 2 ^ 48
	local normal = 1

	frac = frac + (f6 * 2 ^ 40) + (f5 * 2 ^ 32) + (f4 * 2 ^ 24) + (f3 * 2 ^ 16) + (f2 * 2 ^ 8) + f1 -- help

	if exp == 0 then
		if frac == 0 then
			return sign * 0
		else
			normal = 0
			exp = 1
		end
	elseif exp == 0x7FF then
		if frac == 0 then
			return sign * (1 / 0)
		else
			return sign * (0 / 0)
		end
	end

	return sign * 2 ^ (exp - 1023) * (normal + frac / 2 ^ 52)
end

-- int rd_int_basic(string src, int s, int e, int d)
-- @src - Source binary string
-- @s - Start index of a little endian integer
-- @e - End index of the integer
-- @d - Direction of the loop
local function rd_int_basic(src, s, e, d)
	local num = 0

	for i = s, e, d do
		local mul = 256 ^ math.abs(i - s)

		num = num + mul * string.byte(src, i, i)
	end

	return num
end;

-- functions
local function read(st:ByteStream) : number
    assert(st.pos <= st.size, "Trying to read past end of stream");
    local res = st.data:byte(st.pos, st.pos);
    st.pos += 1;
    return res;
end
local function read_4(st:ByteStream) : number
    assert(st.pos + 3 <= st.size, "Trying to read past end of stream");
    local res = rd_int_basic(st.data, st.pos, st.pos+3, 1);
    st.pos += 4;
    return res;
end;
local function read_double(st:ByteStream) : number
    assert(st.pos + 7 <= st.size, "Trying to read past end of stream");
    local res = rd_dbl_basic(string.byte(st.data, st.pos, st.pos + 7))
    st.pos += 8;
    return res;
end;

-- constructor
local function new(data:string) : ByteStream
    return {
        data = data or "",
        pos = 1,
        size = #data,
        -- methods
        read = read,
        read_4 = read_4,
        read_double = read_double
    }
end

return {
    new = new;
}