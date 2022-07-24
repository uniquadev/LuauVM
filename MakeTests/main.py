# imports
from asyncio import subprocess
import asyncio
import os
import platform

SYSTEM = platform.system()
LUA_BIN = SYSTEM == "Windows" and "luau.exe" or SYSTEM == "Linux" and "./luau" or "luau"

# read MakeTests/template.luau as TEMPLATE
TEMPLATE = ""
with open("MakeTests/template.luau", "r") as f:
    TEMPLATE = f.read()

# write a luau test file inside Tests folder
async def make_test(file:str):
    # luau compile the test chunk
    proc = await subprocess.create_subprocess_shell(
        f'{LUA_BIN} --compile=binary MakeTests/src/{file}', stdout=subprocess.PIPE
    )
    # read stdout and get the bytecode
    bytecode = await proc.communicate()
    bytecode = bytecode[0].__str__()[1:]
    # write the bytecode inside the test file
    with open("Tests/" + file, "w+") as f:
        src = TEMPLATE.replace('"{bytecode}"', bytecode)
        src = src.replace('{file}', file)
        f.write(src)

# exec "luau --compile=binary MakeTests\scripts\* >> Tests\*.luau"
def main():
    # loop trought src folder
    for file in os.listdir("MakeTests/src"):
        # perform the asyncio task
        asyncio.run(make_test(file))


if __name__ == "__main__":
    main()