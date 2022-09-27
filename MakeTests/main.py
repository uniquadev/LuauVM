"""
This script is responsible to build/run test scripts and build LuauVM
"""

# imports
from optparse import OptionParser, OptionGroup
from asyncio import subprocess
import asyncio, platform

import utils
from builder import build

# vars
SYSTEM = platform.system()
LUA_BIN = SYSTEM == "Windows" and "luau.exe" or SYSTEM == "Linux" and "./luau" or "luau"

# setup console
parser = OptionParser(
    usage="usage: [options]",
    version= "%prog " + '1.0.0',
)
cli_group = OptionGroup(parser, "CLI Options")
cli_group.add_option(
    "-r",
    "--run",
    dest="run",
    action="store_true",
    help="build tests scripts",
)
cli_group.add_option(
    "-t",
    "--tests",
    dest="tests",
    action="store_true",
    help="build tests scripts",
)
cli_group.add_option(
    "-b",
    "--build",
    dest="build",
    action="store_true",
    help="build LuauVM as LuauVM.lua",
)
parser.add_option_group(cli_group)

# read MakeTests/template.luau as TEMPLATE
TEMPLATE = ""
with open("MakeTests/template.lua", "r") as f:
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

# exec "luau --compile=binary MakeTests\scripts\* >> Tests\*.luau"
def main():
    # parse arguments
    (options, args) = parser.parse_args()
    if options.tests:
        # make Tests folder
        utils.reset_folder("Tests")
        # loop trought src folder
        for file in utils.listdir("MakeTests/src"):
            # perform the asyncio task
            asyncio.run(make_test(file))
    elif options.run:
        # foreach all tests in Tests folder
        for file in utils.listdir("Tests"):
            # perform the asyncio task
            asyncio.run(run_test(file))
    elif options.build:
        # build LuauVM as LuauVM.lua
        build()
    else:
        print("usage: [options]")


if __name__ == "__main__":
    main()