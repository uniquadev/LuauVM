local a = "Hello ";
local b = a .. "World";
local c = false;

if #b == 11 then
  c = true;
elseif c == nil then
  print("nil")
end

if c then
    return 0;
else
    return 1;
end