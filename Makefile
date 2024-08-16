MCU = atmega328p

SRC = uwu-uno_loader.asm

OBJ = $(SRC:.asm=.hex)

ASSEMBLER = avra

ASMFLAGS =

all: build

build: $(OBJ)

$(OBJ): $(SRC)
	$(ASSEMBLER) $(ASMFLAGS) $(SRC)

clean:
	rm -f $(OBJ) *.obj *.cof *.eep.hex *.map *.sym *.eep *.lst

.PHONY: all build flash clean
