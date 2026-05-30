; ============================================================
;  Sudoku solver  --  16-bit MASM (DOS / real mode)
;  Recursive backtracking, exactly the algorithm we walked through:
;    find an empty cell -> try 1..9 that don't conflict ->
;    place & recurse -> on dead end, erase (undo) and back up.
;  Assemble with MASM/ML 6.x or TASM; run under DOSBox.
; ============================================================

.MODEL SMALL
.STACK 1000h

.DATA
; The board is 81 bytes, row-major. 0 = empty.
; This is the classic puzzle (has a single unique solution).
board   db 5,3,0, 0,7,0, 0,0,0
        db 6,0,0, 1,9,5, 0,0,0
        db 0,9,8, 0,0,0, 0,6,0
        db 8,0,0, 0,6,0, 0,0,3
        db 4,0,0, 8,0,3, 0,0,1
        db 7,0,0, 0,2,0, 0,0,6
        db 0,6,0, 0,0,0, 2,8,0
        db 0,0,0, 4,1,9, 0,0,5
        db 0,0,0, 0,8,0, 0,7,9

; Scratch used only inside isValid. Safe as globals because
; isValid never recurses and always returns before solve recurses.
vDigit  db 0
vRow    db 0
vCol    db 0
vBR     db 0          ; box row start
vBC     db 0          ; box col start

okMsg   db 13,10,'Solved:',13,10,13,10,'$'
noMsg   db 13,10,'No solution.',13,10,'$'

.CODE

; ------------------------------------------------------------
;  isValid:  BX = cell index (0..80), AL = digit (1..9)
;  Returns:  AL = 1 if the digit may be placed, else AL = 0
;  Preserves BX, CX, DX, SI
; ------------------------------------------------------------
isValid PROC
        push bx
        push cx
        push dx
        push si

        mov  vDigit, al
        mov  ax, bx
        mov  cl, 9
        div  cl                 ; AL = row (cell/9), AH = col (cell mod 9)
        mov  vRow, al
        mov  vCol, ah

        ; --- row scan: indices row*9 .. row*9+8 ---
        mov  al, vRow
        mov  bl, 9
        mul  bl                 ; AX = row*9
        mov  si, ax
        mov  cx, 9
rowLp:  mov  al, board[si]
        cmp  al, vDigit
        je   ivBad
        inc  si
        loop rowLp

        ; --- column scan: indices col, col+9, col+18, ... ---
        mov  al, vCol
        xor  ah, ah
        mov  si, ax
        mov  cx, 9
colLp:  mov  al, board[si]
        cmp  al, vDigit
        je   ivBad
        add  si, 9
        loop colLp

        ; --- 3x3 box scan ---
        mov  al, vRow           ; boxRowStart = (row/3)*3
        xor  ah, ah
        mov  bl, 3
        div  bl
        mov  ah, 0
        mov  bl, 3
        mul  bl
        mov  vBR, al
        mov  al, vCol           ; boxColStart = (col/3)*3
        xor  ah, ah
        mov  bl, 3
        div  bl
        mov  ah, 0
        mov  bl, 3
        mul  bl
        mov  vBC, al
        mov  al, vBR            ; base index = boxRowStart*9 + boxColStart
        mov  bl, 9
        mul  bl
        mov  bl, vBC
        xor  bh, bh
        add  ax, bx
        mov  si, ax
        mov  dl, 3              ; 3 rows in the box
boxRow: mov  cx, 3             ; 3 cols in the box
        push si
boxCol: mov  al, board[si]
        cmp  al, vDigit
        je   boxBad
        inc  si
        loop boxCol
        pop  si
        add  si, 9             ; drop to next row of the same box
        dec  dl
        jnz  boxRow

        mov  al, 1             ; passed row, col and box -> legal
        jmp  ivDone
boxBad: pop  si
ivBad:  xor  al, al
ivDone: pop  si
        pop  dx
        pop  cx
        pop  bx
        ret
isValid ENDP

; ------------------------------------------------------------
;  solve:  recursive backtracking driver
;  Returns AL = 1 if the board is fully solved, else AL = 0
;  Preserves SI, CX, BX, so the caller's loop state (the empty
;  cell and the digit it is trying) survives the recursive call.
; ------------------------------------------------------------
solve   PROC
        push si
        push cx
        push bx

        xor  si, si            ; scan for the first empty cell
findE:  cmp  si, 81
        jae  allFull
        cmp  byte ptr board[si], 0
        je   cellE
        inc  si
        jmp  findE
allFull:
        mov  al, 1             ; no empty cells left -> solved
        jmp  sDone
cellE:  mov  cl, 1             ; try digits 1..9 in this cell
tryD:   cmp  cl, 9
        ja   sFail
        mov  bx, si
        mov  al, cl
        call isValid
        or   al, al
        jz   nextD
        mov  al, cl            ; legal -> place it
        mov  board[si], al
        call solve             ; recurse to fill the rest
        or   al, al
        jnz  sOk               ; deeper search succeeded -> keep it
        mov  byte ptr board[si], 0   ; dead end -> erase (undo)
nextD:  inc  cl
        jmp  tryD
sFail:  xor  al, al           ; no digit worked -> fail, back up
        jmp  sDone
sOk:    mov  al, 1
sDone:  pop  bx
        pop  cx
        pop  si
        ret
solve   ENDP

; ------------------------------------------------------------
main    PROC
        mov  ax, @data
        mov  ds, ax

        call solve
        or   al, al
        jz   showNo

        mov  dx, OFFSET okMsg  ; print "Solved:" header
        mov  ah, 09h
        int  21h

        xor  si, si            ; print the 9x9 grid
pLoop:  cmp  si, 81
        jae  pEnd
        mov  dl, board[si]
        add  dl, '0'
        mov  ah, 02h
        int  21h
        mov  dl, ' '           ; space between numbers
        mov  ah, 02h
        int  21h
        inc  si
        mov  ax, si            ; newline after every 9 cells
        mov  bl, 9
        div  bl                ; AH = si mod 9
        cmp  ah, 0
        jne  pLoop
        mov  dl, 13
        mov  ah, 02h
        int  21h
        mov  dl, 10
        mov  ah, 02h
        int  21h
        jmp  pLoop

showNo: mov  dx, OFFSET noMsg
        mov  ah, 09h
        int  21h
pEnd:   mov  ax, 4C00h         ; return to DOS
        int  21h
main    ENDP
        END  main