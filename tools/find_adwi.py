# MIT License
# 
# Copyright (c) 2024 Sam F.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# In order to have the jump table for the boot loader instructions,
# We need to find an operation to find a way to compress them to 4 bits

REGISTERS = [
    {"name": "STK_LOAD_ADDRESS", "value": 0x55, "generic": False},
    {"name": "STK_PROG_PAGE", "value": 0x64, "generic": False},
    {"name": "STK_READ_SIGN", "value": 0x75, "generic": False},
    {"name": "STK_LEAVE_PROGMODE", "value": 0x51, "generic": False},
    {"name": "STK_SYNC", "value": 0x30, "generic": True},
    {"name": "STK_PARAMETER", "value": 0x41, "generic": False},
    {"name": "STK_SET_DEVICE", "value": 0x42, "generic": True},
    {"name": "STK_EXT_PARAMS", "value": 0x45, "generic": True},
    {"name": "SCK_PROG_ENABLE", "value": 0x50, "generic": True},
]

def generate_jump_table(addend, bit, addend2, bit2):
    jump_table = {}

    for register in REGISTERS:
        value = register["value"]

        if (value & (1<<bit)) > 0:
                value = value + addend

        if (value & (1<<bit2)) > 0:
                value = value + addend2

        value = value & 0b111

        if value in jump_table: # Attempt merge
            if register["generic"] and jump_table[value]["generic"]:
                continue
            else:
                return None
        else:
            jump_table[value] = register
    
    return jump_table

for bit in range(4,8):
    for i in range(64):
        for bit2 in range(4,8):
            for i2 in range(64):
                table = generate_jump_table(i, bit, i2, bit2)

                if table == None:
                    continue

                print(str(bit) + " " + str(i) + " " + str(bit2) + " " + str(i2) + " has a valid configuration.")
                print(table)