local up, up2 = 1, 0;
local t = {1, 2, 3, 4};

local function func()
    print(up2)
    up = up - 1;
end;

local function func2()
    return {
        t[1], t[2], t[3], t[4]
    }
end;

up2 = "hello";
func();
local res = func2();

return up + res[1] + res[2] - res[3]; -- 0