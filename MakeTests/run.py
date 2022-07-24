# NOTE: this file is run by the test workflow on ubuntu
# imports
from asyncio import subprocess
import os
import asyncio
import platform

SYSTEM = platform.system()
LUA_BIN = SYSTEM == "Windows" and "luau.exe" or SYSTEM == "Linux" and "./luau" or "luau"

# run the test
async def run_test(file):
    # luau execute the file
    proc = await subprocess.create_subprocess_shell(
        f'{LUA_BIN} Tests/{file}', stdout=subprocess.PIPE
    )
    # read stdout and get the output
    output = await proc.communicate()
    output = output[0].decode("utf-8")
    # print out
    print(output)
    # check if out contain FAILED
    if not ("PASSED" in output):
        exit(400)

async def main():
    # foreach all tests in Tests folder
    for file in os.listdir("Tests"):
        # perform the asyncio task
        await run_test(file)
    exit(0)

if __name__ == "__main__":
    res = asyncio.run(main())