import os
from shutil import rmtree
import re

def reset_folder(path:str):
    if os.path.exists(path):
        rmtree(path)
    os.makedirs(path)

def listdir(dir: str):
    res = os.listdir(dir)
    # sort list by its first character byte value inverse
    res.sort(key=lambda x: int(re.match(r'^(\d+)\.', x).group(1)))
    return res