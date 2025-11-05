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
player_info  .rs 1    ; for various player info things. first bit checks for walking.
                      ; second bit checks for jumping. third bit checks if peak of jump has been reached
mvt_timer  .rs 1    ;movement timer. caps out at #$03 and resets. used to do walk cycles
max_jump_speed  .rs 1   ; speed jumps start at/falling caps out at
jump_speed  .rs 1 

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

  LDA $0200         ;set y pos of sprite 0
  STA player_y

  LDA $0203         ;set x pos of sprite 0
  STA player_x

Foreverloop:
  JMP Foreverloop

NMI:

  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  LDA #$00
  STA player_info

  LDA #$05
  STA max_jump_speed

LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016         ; tell both controllers to latch buttons

ReadA: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BNE Jump
  BEQ ReadADone   ; branch to ReadADone if button is NOT pressed (0)
  
Jump:
  CLC
  LDA player_info
  ADC #%00000010
  STA player_info

  LDX player_y
  DEX
  STX player_y

ReadADone:        ; handling this button is done
  
ReadB: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReadBDone   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

ReadBDone:        ; handling this button is done

ReadSelect: 
  LDA $4016       ; player 1 - Select
  AND #%00000001  ; only look at bit 0
  BEQ ReadSelectDone   ; branch to ReadSelectDone if button is NOT pressed (0)

ReadSelectDone:

ReadStart: 
  LDA $4016       ; player 1 - Start
  AND #%00000001  ; only look at bit 0
  BEQ ReadStartDone   ; branch to ReadStartDone if button is NOT pressed (0)

ReadStartDone:

ReadUp: 
  LDA $4016       ; player 1 - Up
  AND #%00000001  ; only look at bit 0
  BEQ ReadUpDone   ; branch to ReadUpDone if button is NOT pressed (0)

ReadUpDone:

ReadDown: 
  LDA $4016       ; player 1 - Down
  AND #%00000001  ; only look at bit 0
  BEQ ReadDownDone   ; branch to ReadDownDone if button is NOT pressed (0)

ReadDownDone:

ReadLeft: 
  LDA $4016       ; player 1 - Left
  AND #%00000001  ; only look at bit 0
  BEQ ReadLeftDone   ; branch to ReadLeftDone if button is NOT pressed (0)
  JSR CheckFaceLeft

;move char to left
DoLeft:
  CLC
  LDA player_x
  SBC #$00
  STA player_x

  CLC
  LDA player_info
  BIT #%00000001
  BNE ReadLeftDone
  ADC #%00000001
  STA player_info

ReadLeftDone:

ReadRight: 
  LDA $4016       ; player 1 - Right
  AND #%00000001  ; only look at bit 0
  BEQ ReadRightDone ; branch to ReadRightDone if button is NOT pressed (0)
  JSR CheckFaceRight

;move char to right
DoRight:
  CLC
  LDA player_x
  ADC #$01
  STA player_x

  CLC
  LDA player_info
  BIT #%00000001
  BNE ReadRightDone
  ADC #%00000001
  STA player_info

ReadRightDone:

GameLogic:
  JSR UpdateShibePosition
  JSR ShibeAnimations

End:
  RTI

CheckFaceLeft:
  LDA $0202
  BIT #%00000100
  BEQ FlipLeft
  RTS

FlipLeft:   
  LDA #%01000000
  STA $0202
  STA $0206
  STA $020A
  STA $020E
  RTS

CheckFaceRight:
  LDA $0202
  AND #$40
  BNE FlipRight
  RTS

FlipRight:
  LDA #%00000000
  STA $0202
  STA $0206
  STA $020A
  STA $020E
  RTS

UpdateShibePosition:
  JMP UpdateSpriteX

UpdateSpriteX:
  LDA $0202
  BIT #%00000100
  BNE UpdateLeft
  JMP UpdateRight

UpdateLeft:
  LDA player_x
  STA $0207
  STA $020F
  TAX
  CLC
  ADC #$08
  STA $0203
  STA $020B
  JMP UpdateSpriteY

UpdateRight:
  LDA player_x
  STA $0203
  STA $020B
  TAX
  CLC
  ADC #$08
  STA $0207
  STA $020F

UpdateSpriteY:
  LDA player_y
  STA $0200
  STA $0204
  TAX
  CLC
  ADC #$08
  STA $0208
  STA $020C
  RTS

  ShibeAnimations:
  LDA player_info
  AND #%00000010
  BNE JumpHandler

  LDA player_info
  BEQ StandStill
  INC mvt_timer
  LDA mvt_timer
  AND #%00001000
  BEQ WalkFrame1
  BNE WalkFrame2
  RTS

WalkFrame1:
  LDA #$04
  STA $0209
  LDA #$05
  STA $020D
  RTS

WalkFrame2:
  LDA #$06
  STA $0209
  LDA #$07
  STA $020D
  RTS

StandStill:
  LDA #$00
  STA mvt_timer
  LDA #$02
  STA $0209
  LDA #$03
  STA $020D
  RTS

JumpHandler:
  LDA #$08
  STA $0209
  LDA #$09
  STA $020D
  RTS

;;;;;;;;;;;;;;;

  .bank 1
  .org $E000

background_palette: 
  .db $22,$29,$1A,$0F   ;background palette 1

sprite_palette:
  .db $22,$16,$27,$20   ;sprite palette 1 (shibe)
  .db $22,$1A,$15,$16   ;ground tile palette (i think ground tiles need to be in the background?? but i dont know how to do that yet. sooooo theyre going in the sprite layer)

sprites:
    ; vert, tile, attr, horiz
  .db $C0, $00, %00000000, $08    ;sprite 0 (top left)
  .db $C0, $01, %00000000, $10    ;sprite 1 (top right)
  .db $C8, $02, %00000000, $08    ;sprite 2 (bottom left)
  .db $C8, $03, %00000000, $10    ;sprite 3 (bottom right)

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
