Function 0 (tbl2number):
    6:     local result = 0
LOADN R1 0
    7:     local power = 1
LOADN R2 1
    8:     for i = 1, #tbl do
LOADN R5 1
LENGTH R3 R0
LOADN R4 1
FORNPREP R3 L1
    9:         result = result + tbl[i] * power
L0: GETTABLE R7 R0 R5
MUL R6 R7 R2
ADD R1 R1 R6
   10:         power = power * 2
MULK R2 R2 K0
    8:     for i = 1, #tbl do
FORNLOOP R3 L0
   12:     return result
L1: RETURN R1 1

Function 1 (expand):
   16:     local big, small = t1, t2
MOVE R2 R0
MOVE R3 R1
   17:     if(#big < #small) then
LENGTH R4 R2
LENGTH R5 R3
JUMPIFNOTLT R4 R5 L0
   18:         big, small = small, big
MOVE R4 R3
MOVE R3 R2
MOVE R2 R4
   21:     for i = #small + 1, #big do
L0: LENGTH R7 R3
ADDK R6 R7 K0
LENGTH R4 R2
LOADN R5 1
FORNPREP R4 L2
   22:         small[i] = 0
L1: LOADN R7 0
SETTABLE R7 R3 R6
   21:     for i = #small + 1, #big do
FORNLOOP R4 L1
   24: end
L2: RETURN R0 0

Function 2 (??):
   29:     local tbl = to_bits(n)
GETUPVAL R1 0
MOVE R2 R0
CALL R1 1 1
   30:     local size = math.max(#tbl, 32)
LENGTH R3 R1
FASTCALL2K 18 R3 K0 L0
LOADK R4 K0
GETIMPORT R2 3
CALL R2 2 1
   31:     for i = 1, size do
L0: LOADN R5 1
MOVE R3 R2
LOADN R4 1
FORNPREP R3 L4
   32:         if(tbl[i] == 1) then
L1: GETTABLE R6 R1 R5
JUMPXEQKN R6 K4 L2 NOT
   33:         tbl[i] = 0
LOADN R6 0
SETTABLE R6 R1 R5
JUMP L3
   35:         tbl[i] = 1
L2: LOADN R6 1
SETTABLE R6 R1 R5
   31:     for i = 1, size do
L3: FORNLOOP R3 L1
   38:     return tbl2number(tbl)
L4: GETUPVAL R3 1
MOVE R4 R1
CALL R3 1 -1
RETURN R3 -1

Function 3 (??):
   43:     if(n < 0) then
LOADN R1 0
JUMPIFNOTLT R0 R1 L1
   45:         return to_bits(bit_not(math.abs(n)) + 1)
GETUPVAL R1 0
GETUPVAL R3 1
FASTCALL1 2 R0 L0
MOVE R5 R0
GETIMPORT R4 3
CALL R4 1 -1
L0: CALL R3 -1 1
ADDK R2 R3 K0
CALL R1 1 -1
RETURN R1 -1
   48:     local tbl = {}
L1: NEWTABLE R1 0 0
   49:     local cnt = 1
LOADN R2 1
   50:     local last
LOADNIL R3
   51:     while n > 0 do
L2: LOADN R4 0
JUMPIFNOTLT R4 R0 L3
   52:         last      = n % 2
MODK R3 R0 K4
   53:         tbl[cnt]  = last
SETTABLE R3 R1 R2
   54:         n         = (n-last)/2
SUB R4 R0 R3
DIVK R0 R4 K4
   55:         cnt       = cnt + 1
ADDK R2 R2 K0
   51:     while n > 0 do
JUMPBACK L2
   58:     return tbl
L3: RETURN R1 1

Function 4 (??):
   62:     local tbl_m = to_bits(m)
GETUPVAL R2 0
MOVE R3 R0
CALL R2 1 1
   63:     local tbl_n = to_bits(n)
GETUPVAL R3 0
MOVE R4 R1
CALL R3 1 1
   64:     expand(tbl_m, tbl_n)
GETUPVAL R4 1
MOVE R5 R2
MOVE R6 R3
CALL R4 2 0
   66:     local tbl = {}
NEWTABLE R4 0 0
   67:     for i = 1, #tbl_m do
LOADN R7 1
LENGTH R5 R2
LOADN R6 1
FORNPREP R5 L3
   68:         if(tbl_m[i]== 0 and tbl_n[i] == 0) then
L0: GETTABLE R8 R2 R7
JUMPXEQKN R8 K0 L1 NOT
GETTABLE R8 R3 R7
JUMPXEQKN R8 K0 L1 NOT
   69:         tbl[i] = 0
LOADN R8 0
SETTABLE R8 R4 R7
JUMP L2
   71:         tbl[i] = 1
L1: LOADN R8 1
SETTABLE R8 R4 R7
   67:     for i = 1, #tbl_m do
L2: FORNLOOP R5 L0
   75:     return tbl2number(tbl)
L3: GETUPVAL R5 2
MOVE R6 R4
CALL R5 1 -1
RETURN R5 -1

Function 5 (??):
   79:     local tbl_m = to_bits(m)
GETUPVAL R2 0
MOVE R3 R0
CALL R2 1 1
   80:     local tbl_n = to_bits(n)
GETUPVAL R3 0
MOVE R4 R1
CALL R3 1 1
   81:     expand(tbl_m, tbl_n)
GETUPVAL R4 1
MOVE R5 R2
MOVE R6 R3
CALL R4 2 0
   83:     local tbl = {}
NEWTABLE R4 0 0
   84:     for i = 1, #tbl_m do
LOADN R7 1
LENGTH R5 R2
LOADN R6 1
FORNPREP R5 L4
   85:         if(tbl_m[i]== 0 or tbl_n[i] == 0) then
L0: GETTABLE R8 R2 R7
JUMPXEQKN R8 K0 L1
GETTABLE R8 R3 R7
JUMPXEQKN R8 K0 L2 NOT
   86:         tbl[i] = 0
L1: LOADN R8 0
SETTABLE R8 R4 R7
JUMP L3
   88:         tbl[i] = 1
L2: LOADN R8 1
SETTABLE R8 R4 R7
   84:     for i = 1, #tbl_m do
L3: FORNLOOP R5 L0
   92:     return tbl2number(tbl)
L4: GETUPVAL R5 2
MOVE R6 R4
CALL R5 1 -1
RETURN R5 -1

Function 6 (??):
   96:     local high_bit = 0
LOADN R2 0
   97:     if(n < 0) then
LOADN R3 0
JUMPIFNOTLT R0 R3 L1
   99:         n = bit_not(math.abs(n)) + 1
GETUPVAL R3 0
FASTCALL1 2 R0 L0
MOVE R5 R0
GETIMPORT R4 3
CALL R4 1 -1
L0: CALL R3 -1 1
ADDK R0 R3 K0
  100:         high_bit = 0x80000000
LOADK R2 K4
  103:     local floor = math.floor
L1: GETIMPORT R3 6
  104:     print(bits)
GETIMPORT R4 8
MOVE R5 R1
CALL R4 1 0
  105:     for i=1, bits do
LOADN R6 1
MOVE R4 R1
LOADN R5 1
FORNPREP R4 L4
  106:         n = n/2
L2: DIVK R0 R0 K9
  107:         n = bit_or(floor(n), high_bit)
GETUPVAL R7 1
FASTCALL1 12 R0 L3
MOVE R9 R0
MOVE R8 R3
CALL R8 1 1
L3: MOVE R9 R2
CALL R7 2 1
MOVE R0 R7
  108:         print(i, n)
GETIMPORT R7 8
MOVE R8 R6
MOVE R9 R0
CALL R7 2 0
  105:     for i=1, bits do
FORNLOOP R4 L2
  110:     return floor(n)
L4: FASTCALL1 12 R0 L5
MOVE R5 R0
MOVE R4 R3
CALL R4 1 -1
L5: RETURN R4 -1

Function 7 (??):
  115:         return char( bit_and( bit_rshift(i, s), 255))
GETUPVAL R2 0
GETUPVAL R3 1
GETUPVAL R4 2
MOVE R5 R0
CALL R3 2 1
LOADN R4 255
CALL R2 2 -1
FASTCALL 42 L0
GETUPVAL R1 3
CALL R1 -1 -1
L0: RETURN R1 -1

Function 8 (lei2str):
  114:     local f = function(s)
NEWCLOSURE R1 P0
CAPTURE UPVAL U0
CAPTURE UPVAL U1
CAPTURE VAL R0
CAPTURE UPVAL U2
  117:     local l2 = f(0)..f(8)..f(16)..f(24)
MOVE R7 R1
LOADN R8 0
CALL R7 1 1
MOVE R3 R7
MOVE R7 R1
LOADN R8 8
CALL R7 1 1
MOVE R4 R7
MOVE R7 R1
LOADN R8 16
CALL R7 1 1
MOVE R5 R7
MOVE R6 R1
LOADN R7 24
CALL R6 1 1
CONCAT R2 R3 R6
  118:     return l2
RETURN R2 1

Function 9 (??):
    2: string.char, string.byte, string.format, string.rep, string.sub
GETIMPORT R0 2
GETIMPORT R1 4
GETIMPORT R2 6
GETIMPORT R3 8
GETIMPORT R4 10
    3: local bit_or, bit_and, bit_not, bit_xor, bit_rshift, bit_lshift
LOADNIL R5
LOADNIL R6
LOADNIL R7
LOADNIL R8
LOADNIL R9
LOADNIL R10
    5: local function tbl2number(tbl)
DUPCLOSURE R11 K11
   15: local function expand(t1, t2)
DUPCLOSURE R12 K12
   26: local to_bits -- needs to be declared before bit_not
LOADNIL R13
   28: bit_not = function(n)
NEWCLOSURE R7 P2
CAPTURE REF R13
CAPTURE VAL R11
   42: to_bits = function (n)
NEWCLOSURE R13 P3
CAPTURE REF R13
CAPTURE REF R7
   61: bit_or = function(m, n)
NEWCLOSURE R5 P4
CAPTURE REF R13
CAPTURE VAL R12
CAPTURE VAL R11
   78: bit_and = function(m, n)
NEWCLOSURE R6 P5
CAPTURE REF R13
CAPTURE VAL R12
CAPTURE VAL R11
   95: bit_rshift = function(n, bits)
NEWCLOSURE R9 P6
CAPTURE REF R7
CAPTURE REF R5
  113: local function lei2str(i)
NEWCLOSURE R14 P7
CAPTURE REF R6
CAPTURE REF R9
CAPTURE VAL R0
  121: local P = lei2str(bit_and(8*10, 0xFFFFFFFF))
MOVE R15 R14
MOVE R16 R6
LOADN R17 80
LOADK R18 K13
CALL R16 2 -1
CALL R15 -1 1
  122: print(P)
GETIMPORT R16 15
MOVE R17 R15
CALL R16 1 0
  123: return P:sub(1, 1) == "P" and 0 or -1
LOADN R19 1
LOADN R20 1
NAMECALL R17 R15 K9
CALL R17 3 1
JUMPXEQKS R17 K16 L0 NOT
LOADN R16 0
JUMP L1
L0: LOADN R16 -1
L1: CLOSEUPVALS R5
RETURN R16 1

