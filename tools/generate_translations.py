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

#
# Generates the lookup tables needed to operate UwU-Uno Loader
#

def crc16(data: str) -> int:
    crc = 0xFFFF
    for byte in data.encode('utf-8'):
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc

KEY_WORD_TABLE = []
TRANSLATIONS = []
LETTER_TABLE = {}

def get_letter_index(letter):
    if letter in LETTER_TABLE:
        return LETTER_TABLE[letter]
    else:
        if len(LETTER_TABLE) < 8:
            LETTER_TABLE[letter] = len(LETTER_TABLE)
            return LETTER_TABLE[letter]
        else:
            raise Exception("Letter table cant have more than 8 entries. Too many unique letters?")

def add_translation(before: str, after: str):
    if len(KEY_WORD_TABLE) >= 16:
        raise Exception("Cant have more than 16 translations.")

    if len(before) != len(after):
        raise Exception("Translations must match length")

    before = before.lower()
    after = after.lower()

    name = before.upper()

    KEY_WORD_TABLE.append({
        "checksum": crc16(before),
        "word_length": len(before), 
        "index": len(TRANSLATIONS)
    })

    translation_count = 0
    for i in range(len(before)):
        translation_count = translation_count + 1
        if before[i] != after[i]:
            letter_offset = (len(before) - i) + 1
            if letter_offset > 15:
                raise Exception("Letter offset cant be more than 15. Word too long?")
            
            letter_id = get_letter_index(after[i])

            TRANSLATIONS.append(letter_offset | (letter_id << 4))

    if translation_count == 0:
        raise Exception("No translation in list!")

    TRANSLATIONS[len(TRANSLATIONS) - 1] |= 0x80

def serialize_letter_table():
    table = []
    output = "UWU_LETTER_TABLE:\n\t.db "

    for key in LETTER_TABLE:
        table.append(ord(key))
    
    for i in range(8-len(table)):
        table.append(0)
    
    for i in range(8):
        output = output + str(table[i])
        if i != 7:
            output = output + ", "
    
    output = output + "\n"
    
    return output

def serialize_translations():
    output = "UWU_TRANSLATIONS:\n\t.db "

    translation_count = 0
    table = TRANSLATIONS
    for i in range(len(table)):
        translation_count = translation_count + 1
        output = output + str(table[i])
        if i != len(table) - 1 or translation_count != len(TRANSLATIONS):
            output = output + ", "
    
    return output

def serialize_key_words():
    output = "UWU_KEY_WORDS:"

    table = []

    for entry in KEY_WORD_TABLE:
        crc16_sum = entry["checksum"]
        word_length = entry["word_length"]
        index = entry["index"]

        table.append(str(crc16_sum & 0xFF))
        table.append(str(crc16_sum >> 8))

        table.append(str(word_length))

        table.append("((UWU_TRANSLATIONS << 1)&0xFF) + " + str(index))
    
    for i in range(0, len(table), 4):
        output = output + "\n\t.db " + table[i+0] + ", " + table[i+1] + ", " + table[i+2] + ", " + table[i+3]
    
    return output


add_translation("Hello", "Hewwo")
add_translation("LED", "UwU")
add_translation("Button", "Bwuton")
add_translation("Sensor", "Swensr")
add_translation("Temperature", "Tempwwature")
add_translation("Voltage", "Wowtage")
add_translation("Error", "Euwou")
add_translation("Press", "Pwess")
add_translation("Release", "Welease")
add_translation("Motor", "Wotor")
add_translation("World", "Wurld")
add_translation("Loop", "Woop")
add_translation("Start", "Stawt")
add_translation("Stop", "Stwp")
add_translation("Connected", "Cownected")
add_translation("Setup", "Sewup")

print(serialize_key_words())
print(serialize_translations())
print(serialize_letter_table())