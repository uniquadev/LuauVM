local a = {};
local code = 1;

function a:func()
    print('hello')
    code = 0;
end

a:func();

return code; -- 0