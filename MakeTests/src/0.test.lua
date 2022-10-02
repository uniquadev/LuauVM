local t = {}

for i = 1, 10 do
    table.insert(t, i)
end

for i, v in next, t do
    print(i, v)
end

return 0