local a = {}
local t = {}

for i = 1, 10 do
    table.insert(a, i)
end

for i = #a, 1,-1 do
    t[i] = a[i];
end
assert(t[1] == 1)

for i, v in next, t do
    print(i, v)
end

local i = 1;
local sum = 0;
while t[i] do
    sum += t[i]
    i = i + 1;
end;

i = 1;
repeat
    sum -= t[i]
    i = i + 1;
until not t[i]

print(sum)
return sum;