local function test(c, ...)
    local args = {...}
    table.foreach(args, print)
    local b = args[1];
    print(b)
    local a = select(2, ...)
    print(a)
    return a, b, c
end

local a, b, c = test(1, 2, 0)
return a == 0 and b == 2 and c == 1 and 0 or -1;