  .inesprg 1    ; 1x 16KB PRG code
  .ineschr 1    ; 1x  8KB CHR data
  .inesmap 0    ; mapper 0 = NROM, no bank swapping
  .inesmir 1    ; background mirroring

  .bank 0
  .org $C000

;;;;;;;;;;;;;;;
;DECLARE SOME VARIABLES here
  .rsset $0000  ;; start variables at ram location 0

player_x  .rs 1   ; reserve 1 byte
player_y  .rs 1
player_info  .rs 1    ; for various player info things. first bit checks for movement. uhh the rest will maybe do stuff later idk
mvt_timer  .rs 1    ;movement timer. caps out at #$03 and resets. used to do walk cycles

;;;;;;;;;;;;;;;

RESET:
  SEI         ; disable IRQs
  CLD         ; disable decimal mode
  LDX #$40
  STX $4017   ; disable APU frame IRQ
  LDX #$FF
  TXS         ; Set up stack
  INX         ; now X = 0
  STX $2000   ; disable NMI
  STX $2001   ; disable rendering
  STX $4010   ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
	BPL vblankwait1

clrmem:
	LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
        BIT $2002
        BPL vblankwait2

LoadPalettes:
  LDA $2002           ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006           ; write the high byte of $3F00 address
  LDA #$00
  STA $2006           ; write the low byte of $3F00 address
  LDX #$00            ; start out at 0

LoadBackgroundPaletteLoop:
  LDA background_palette, X         ; load data from address (palette + value in x)
  STA $2007           ; write to PPU
  INX
  CPX #$10            ; compare X to $10 - copying 16 bytes = 4 sprites
  BNE LoadBackgroundPaletteLoop

  LDX #$00    ;reset x register to zero to load sprite palette colors

LoadSpritePaletteLoop:
  LDA sprite_palette, X     ;load palette byte
  STA $2007         ;write to PPU
  INX
  CPX #$10
  BNE LoadSpritePaletteLoop

  LDX #$00

LoadSpritesLoop:
  LDA sprites, x    ; load data from address (sprites + x)
  STA $0200, x      ; store into RAM address ($0200 + x)
  INX
  CPX #$10
  BNE LoadSpritesLoop

  LDA #%10000000    ; enable NMI, sprites from Pattern table 0
  STA $2000

  LDA #%00010000    ;enable sprites
  STA $2001

  LDA $0200
  STA player_y

  LDA $0203
  STA player_x

Foreverloop:
        JMP Foreverloop

NMI:

  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016         ; tell both controllers to latch buttons

ReadA: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadADone   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

ReadADone:        ; handling this button is done
  
ReadB: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReadBDone   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

ReadBDone:        ; handling this button is done

ReadSelect: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadSelectDone   ; branch to ReadADone if button is NOT pressed (0)

ReadSelectDone:

ReadStart: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadStartDone   ; branch to ReadADone if button is NOT pressed (0)

ReadStartDone:

ReadUp: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BNE DoUp
  BEQ ReadUpDone   ; branch to ReadADone if button is NOT pressed (0)

;move char up
DoUp:
  LDA player_y
  STA $0200
  STA $0204
  TAX
  CLC
  ADC #$08
  STA $0208
  STA $020C
  DEX
  STX player_y

ReadUpDone:

ReadDown: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BNE DoDown
  BEQ ReadDownDone   ; branch to ReadADone if button is NOT pressed (0)

;move char down
DoDown:
  LDA player_y
  STA $0200
  STA $0204
  TAX
  CLC
  ADC #$08
  STA $0208
  STA $020C
  INX
  STX player_y

ReadDownDone:

ReadLeft: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BNE CheckFaceLeft
  JMP ReadLeftDone   ; branch to ReadADone if button is NOT pressed (0)

CheckFaceLeft:
  LDA $0202
  AND #$40
  BEQ FlipLeft
  JMP DoLeft

FlipLeft:
  LDA #%01000000
  STA $0202
  STA $0206
  STA $020A
  STA $020E

;move char to left
DoLeft:
  LDA player_x
  STA $0207
  STA $020F
  TAX
  CLC
  ADC #$08
  STA $0203
  STA $020B
  DEX
  STX player_x

ReadLeftDone:

ReadRight: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BNE CheckFaceRight
  JMP ReadRightDone ; branch to ReadADone if button is NOT pressed (0)

CheckFaceRight:
  LDA $0202
  AND #$40
  BNE FlipRight
  JMP DoRight

FlipRight:
  LDA #%00000000
  STA $0202
  STA $0206
  STA $020A
  STA $020E

;move char to right
DoRight:
  LDA player_x
  STA $0203
  STA $020B
  TAX
  CLC
  ADC #$08
  STA $0207
  STA $020F
  INX
  STX player_x

ReadRightDone:

  RTI

;;;;;;;;;;;;;;;

  .bank 1
  .org $E000

; copying mario 1's overworld palettes

background_palette: 
  .db $22,$29,$1A,$0F   ;background palette 1 (bushes)
  .db $22,$36,$17,$0F   ;background palette 2 (floor tiles)
  .db $22,$30,$21,$0F   ;background palette 3 (clouds)
  .db $22,$27,$17,$0F   ;bg palette 4 (coins)

sprite_palette:
  .db $22,$16,$27,$20   ;sprite palette 1 (shibe)
  .db $22,$1A,$30,$27   ;sprite palette 2 (green koopa/piranha plant/1up)
  .db $22,$16,$30,$27   ;sprite palette 3 (red koopa/super mushroom)
  .db $22,$0F,$36,$17   ;sprite palette 4 (goomba/bricks)

sprites:
    ; vert tile attr horiz
  .db $08, $00, %00000000, $08    ;sprite 0 (top left)
  .db $08, $01, %00000000, $10    ;sprite 1 (top right)
  .db $10, $02, %00000000, $08    ;sprite 2 (bottom left)
  .db $10, $03, %00000000, $10    ;sprite 3 (bottom right)
  .db $10, $04, %00000000, $08    ;bottom left (walk 1)
  .db $10, $05, %00000000, $10    ;bottom right (walk 1)
  .db $10, $06, %00000000, $08    ;bottom left (walk 2)
  .db $10, $07, %00000000, $10    ;bottom right (walk 2)

;;;;;;;;;;;;;;;

  .org $FFFA  ;first of the three vectors starts here
  .dw NMI     ;when an NMI happens (once per frame if enabled) the processor will jump to the label NMI:
  .dw RESET   ;when the processor first turns on or is reset it will jump to the label RESET:
  .dw 0       ;external interrupt IRQ is not used

;;;;;;;;;;;;;;;

  .bank 2
  .org $0000
  .incbin "shibe.chr"   ;includes 8KB graphics file

;;;;;;;;;;;;;;;
