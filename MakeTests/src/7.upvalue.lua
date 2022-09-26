local up, up2 = 1, 0;

local function func()
    print(up2)
    up = up - 1;
end;

up2 = "hello";
func();

return up;