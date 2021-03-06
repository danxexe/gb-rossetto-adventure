; Original template from https://github.com/nezticle/rgbds-template

; gbhw.inc contains the
; 'Hardware Defines' for our program. This has
; address location labels for all of the GameBoy
; Hardware I/O registers. We can 'insert' this file
; into the present EXAMPLE1.ASM file by using the
; assembler INCLUDE command:

INCLUDE "gbhw.inc" ; standard hardware definitions from devrs.com

;  Next we want to include a file that contains a font
; macro. A macro is a portion of code or data that
; gets 'inserted' into your program. At this point,
; we are not actually inserting anything but a macro
; definition into our file. Code or data isn't physically
; inserted into a program until you invoke a macro which
; we will do later. For now, we are just making the macro
; name recognizable by our program.

INCLUDE "ibmpc1.inc" ; ASCII character set from devrs.com

; Next we need to include some code for doing
; RAM copy, RAM fill, etc.

INCLUDE "memory.inc"

; We are going to keep interrupts disabled for this program.
; However, it is good practice to leave the reserved memory locations for interrupts with
; executable code. It make for a nice template as well to fill in code when we use interrupts
; in the future
SECTION	"Vblank",ROM0[$0040]
	reti
SECTION	"LCDC",ROM0[$0048]
	reti
SECTION	"Timer_Overflow",ROM0[$0050]
	reti
SECTION	"Serial",ROM0[$0058]
	reti
SECTION	"p1thru4",ROM0[$0060]
	reti


SECTION "globals", WRAM0
current_frame: ds 1


SECTION "sprites", OAM
player_l_y: ds 1
player_l_x: ds 1
player_l_tile: ds 1
player_l_flags: ds 1
player_r_y: ds 1
player_r_x: ds 1
player_r_tile: ds 1
player_r_flags: ds 1


SECTION "tile data", VRAM

FontTileData_SIZE EQU 8 * 256 ; the ASCII character set: 256 characters, each with 8 bytes of display data
RossettoData_SIZE EQU 64

FontTileData_VRAM:
	ds FontTileData_SIZE
RossettoData1_VRAM:
	ds RossettoData_SIZE
RossettoData2_VRAM:
	ds RossettoData_SIZE

;  Next we need to include the standard GameBoy ROM header
; information that goes at location $0100 in the ROM. (The
; $ before a number indicates that the number is a hex value.)
;
;  ROM location $0100 is also the code execution starting point
; for user written programs. The standard first two commands
; are usually always a NOP (NO Operation) and then a JP (Jump)
; command. This JP command should 'jump' to the start of user
; code. It jumps over the ROM header information as well that
; is located at $104.
;
;  First, we indicate that the following code & data should
; start at address $100 by using the following SECTION assembler
; command:

SECTION	"start", ROM0[$0100]
	nop
	jp	begin

;  To include the standard ROM header information we
; can just use the macro ROM_HEADER. We defined this macro
; earlier when we INCLUDEd "gbhw.inc".
;
;  The ROM_NOMBC just suggests to the complier that we are
; not using a Memory Bank Controller because we don't need one
; since our ROM won't be larger than 32K bytes.
;
;  Next we indicate the cart ROM size and then the cart RAM size.
; We don't need any cart RAM for this program so we set this to 0K.

; ****************************************************************************************
; ROM HEADER and ASCII character set
; ****************************************************************************************
; ROM header
	ROM_HEADER	ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE

;  The NOP and then JP located at $100 in ROM are executed
; which causes the the following code to be executed next.

; ****************************************************************************************
; Main code Initialization:
; set the stack pointer, enable interrupts, set the palette, set the screen relative to the window
; copy the ASCII character table, clear the screen
; ****************************************************************************************
begin:
; First, it's a good idea to Disable Interrupts
; using the following command. We won't be using
; interrupts in this example so we can leave them off.

	di

;  Next, we should initialize our stack pointer. The
; stack pointer holds return addresses (among other things)
; when we use the CALL command so the stack is important to us.
;
;  The CALL command is similar to executing
; a procedure in the C & PASCAL languages.
;
; We shall set the stack to the top of high ram + 1.
;
	ld	sp, $ffff		; set the stack pointer to highest mem location we can use + 1

;  Here we are going to setup the background tile
; palette so that the tiles appear in the proper
; shades of grey.
;
;  To do this, we need to write the value %11100100 to the
; memory location $ff47. In the 'gbhw.inc' file we
; INCLUDEd there is a definition that rBGP=$ff47 so
; we can use the rGBP label to do this
;
;  The first instruction loads the value %11100100 into the
; 8-bit register A and the second instruction writes
; the value of register A to memory location $ff47.

init:
	ld a, %11100100 	; Window palette colors, from darkest to lightest
	ld [rBGP], a
	ld a, %11100100     ; Sprite palette 0
	ld [rOBP0], a

;  Here we are setting the X/Y scroll registers
; for the tile background to 0 so that we can see
; the upper left corner of the tile background.
;
;  Think of the tile background RAM (which we usually call
; the tile map RAM) as a large canvas. We draw on this
; 'canvas' using 'paints' which consist of tiles and
; sprites (we will cover sprites in another example.)
;
;  We set the scroll registers to 0 so that we can
; view the upper left corner of the 'canvas'.

	ld	a,0			; SET SCREEN TO TO UPPER RIGHT HAND CORNER
	ld	[rSCX], a
	ld	[rSCY], a

;  Next we shall turn the Liquid Crystal Display (LCD)
; off so that we can copy data to video RAM. We can
; copy data to video RAM while the LCD is on but it
; is a little more difficult to do and takes a little
; bit longer. Video RAM is not always available for
; reading or writing when the LCD is on so it is
; easier to write to video RAM with the screen off.
;
;  To turn off the LCD we do a CALL to the StopLCD
; subroutine at the bottom of this file. The reason
; we use a subroutine is because it takes more than
; just writing to a memory location to turn the
; LCD display off. The LCD display should be in
; Vertical Blank (or VBlank) before we turn the display
; off. Weird effects can occur if you don't wait until
; VBlank to do this and code written for the Super
; GameBoy won't work sometimes you try to turn off
; the LCD outside of VBlank.

	call	StopLCD		; YOU CAN NOT LOAD $8000 WITH LCD ON

;  In order to display any text on our 'canvas'
; we must have tiles which resemble letters that
; we can use for 'painting'. In order to setup
; tile memory we will need to copy our font data
; to tile memory using the routine 'mem_CopyMono'
; found in the 'memory.asm' library we INCLUDEd
; earlier.
;
;  For the purposes of the 'mem_CopyMono' routine,
; the 16-bit HL register is used as a source memory
; location, DE is used as a destination memory location,
; and BC is used as a data length indicator.

	ld	hl, FontTileData
	ld	de, FontTileData_VRAM
	ld	bc, FontTileData_SIZE
	call	mem_CopyMono	; load tile data

    ld  hl, RossettoData1
    ld  de, RossettoData1_VRAM
    ld  bc, RossettoData_SIZE
    call    mem_Copy    ; load tile data

    ld  hl, RossettoData2
    ld  de, RossettoData2_VRAM
    ld  bc, RossettoData_SIZE
    call    mem_Copy    ; load tile data


    ; initialize OAM
    ld hl, _OAMRAM
    xor a
REPT 40
    ld [hl+], a ; y
    ld [hl+], a ; x
    ld [hl+], a ; tile
    ld [hl+], a ; flags
ENDR


; We turn the LCD on. Parameters are explained in the I/O registers section of The GameBoy reference under I/O register LCDC
	ld	a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_WIN9C00|LCDCF_BGON|LCDCF_WINOFF|LCDCF_OBJ16|LCDCF_OBJON
	ld	[rLCDC], a

; Next, we clear our 'canvas' to all white by
; 'setting' the canvas to ascii character $20
; which is a white space.

	ld	a, 32		; ASCII FOR BLANK SPACE
	ld	hl, _SCRN0
	ld	bc, SCRN_VX_B * SCRN_VY_B
	call	mem_SetVRAM


; Initialize globals

	xor a
	ld [current_frame], a

	lcd_WaitVRAM
	ld a, 8 * 9
	ld [player_l_y], a
	ld a, 8 * 10
	ld [player_l_x], a
	ld a, 8 * 9
	ld [player_r_y], a
	ld a, 8 * 11
	ld [player_r_x], a

; \1: Map (_SCRN0 or _SCRN1)
; \2: Tile index data
; \3: X
; \4: Y
; \5: W
; \6: H
SetMapTiles: MACRO
ROW SET 0
OFFSET SET 0
REPT \6
	ld hl, \2 + OFFSET
	ld de, \1 + \3 + (SCRN_VY_B * (\4 + ROW))
	ld bc, \5
	call mem_CopyVRAM
ROW SET ROW + 1
OFFSET SET OFFSET + \5
ENDR
ENDM


; Display title
TITLE_STRING EQUS "\"ROSSETTO ADVENTURE\""
TITLE_SIZE EQU STRLEN(TITLE_STRING)
Title:
	db TITLE_STRING
	lcd_WaitVRAM
	SetMapTiles _SCRN0, Title, 1, 12, TITLE_SIZE, 1

MainLoop:

.check_input:
	; only check input every 8 frames
	ld a, [current_frame]
	and a, %111
	jr nz, .end_check

	call pad_Read
	ld b, a ; backup a, since `and` destroys it

.check_right:
	and a, PADF_RIGHT
	jr z, .check_left
	ld hl, player_l_x
	inc [hl]
	ld hl, player_r_x
	inc [hl]
.check_left:
	ld a, b
	and a, PADF_LEFT
	jr z, .check_up
	ld hl, player_l_x
	dec [hl]
	ld hl, player_r_x
	dec [hl]
.check_up
	ld a, b
	and a, PADF_UP
	jr z, .check_down
	ld hl, player_l_y
	dec [hl]
	ld hl, player_r_y
	dec [hl]
.check_down:
	ld a, b
	and a, PADF_DOWN
	jr z, .end_check
	ld hl, player_l_y
	inc [hl]
	ld hl, player_r_y
	inc [hl]
.end_check:

	call waitForVBlank

	ld a, [current_frame]

	and a
	jr z, .frame1

	cp 128
	jr z, .frame2

	jr .endOfFrame

.frame1:
	ld a, $80
	ld [player_l_tile], a
	ld a, $82
	ld [player_r_tile], a

    jr .endOfFrame

.frame2:
	ld a, $84
	ld [player_l_tile], a
	ld a, $86
	ld [player_r_tile], a

    jr .endOfFrame

.endOfFrame:
    ld hl, current_frame
    inc [hl]

jp MainLoop


; ****************************************************************************************
; Tile Map
; ****************************************************************************************
Rossetto:
	db 128,129,130,131
Rossetto2:
    db 132,133,134,135

; ****************************************************************************************
; StopLCD:
; turn off LCD if it is on
; and wait until the LCD is off
; ****************************************************************************************
StopLCD:
	ld a, [rLCDC]
	rlca                    ; Put the high bit of LCDC into the Carry flag
	ret nc                  ; Screen is off already. Exit.

call waitForVBlank

	; Turn off the LCD
	ld a, [rLCDC]
	res 7, a             ; Reset bit 7 of LCDC
	ld [rLCDC], a

	ret

waitForVBlank:
	ld a, [rLY]
	cp 144                ; Is display on scan line 145 yet?
	jr c, waitForVBlank  ; no, keep waiting
	ret


;  Next, let's actually include font tile data into the ROM
; that we are building. We do this by invoking the chr_IBMPC1
; macro that was defined earlier when we INCLUDEd "ibmpc1.inc".
;
;  The 1 & 8 parameters define that we want to include the
; whole IBM-PC font set and not just parts of it.
;
;  Right before invoking this macro we define the label
; TileData. Whenever a label is defined with a colon
; it is given the value of the current ROM location.
;  As a result, TileData now has a memory location value that
; is the same as the first byte of the font data that we are
; including. We shall use the label TileData as a "handle" or
; "reference" for locating our font data.

FontTileData:
    chr_IBMPC1  1,8 ; LOAD ENTIRE CHARACTER SET
RossettoData1:
	INCBIN "data/rossetto-1.2bpp"
RossettoData2:
    INCBIN "data/rossetto-2.2bpp"
