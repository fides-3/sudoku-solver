; ============================================================
;  Sudoku solver  --  16-bit MASM (DOS / real mode)
;  Solves THREE boards. Clears the screen and waits for a key
;  between puzzles so each fits on the 80x25 screen.
;  Assemble with MASM/ML 6.x or TASM; run under DOSBox.
; ============================================================

.MODEL SMALL
.STACK 1000h

.DATA
board    db 81 dup(0)          ; working grid the solver operates on

puzzle1  db 5,3,0, 0,7,0, 0,0,0
         db 6,0,0, 1,9,5, 0,0,0
         db 0,9,8, 0,0,0, 0,6,0
         db 8,0,0, 0,6,0, 0,0,3
         db 4,0,0, 8,0,3, 0,0,1
         db 7,0,0, 0,2,0, 0,0,6
         db 0,6,0, 0,0,0, 2,8,0
         db 0,0,0, 4,1,9, 0,0,5
         db 0,0,0, 0,8,0, 0,7,9

puzzle2  db 0,0,3, 0,2,0, 6,0,0
         db 9,0,0, 3,0,5, 0,0,1
         db 0,0,1, 8,0,6, 4,0,0
         db 0,0,8, 1,0,2, 9,0,0
         db 7,0,0, 0,0,0, 0,0,8
         db 0,0,6, 7,0,8, 2,0,0
         db 0,0,2, 6,0,9, 5,0,0
         db 8,0,0, 2,0,3, 0,0,9
         db 0,0,5, 0,1,0, 3,0,0

ptrTbl   dw puzzle1, puzzle2
pIdx     dw 0

vDigit   db 0
vRow     db 0
vCol     db 0
vBR      db 0
vBC      db 0

hdr      db '--- Puzzle ','$'
tail     db ' ---',13,10,13,10,'$'
noMsg    db 13,10,'No solution.',13,10,'$'
prompt   db 13,10,'Press any key for the next puzzle...','$'

.CODE

; ------------------------------------------------------------
;  isValid:  BX = cell index (0..80), AL = digit (1..9)
;  Returns AL = 1 if legal, else 0.  Preserves BX,CX,DX,SI.
; ------------------------------------------------------------
isValid PROC
        push bx
        push cx
        push dx
        push si

        mov  vDigit, al
        mov  ax, bx
        mov  cl, 9
        div  cl                 ; AL = row, AH = col
        mov  vRow, al
        mov  vCol, ah

        mov  al, vRow           ; row scan
        mov  bl, 9
        mul  bl
        mov  si, ax
        mov  cx, 9
rowLp:  mov  al, board[si]
        cmp  al, vDigit
        je   ivBad
        inc  si
        loop rowLp

        mov  al, vCol           ; column scan
        xor  ah, ah
        mov  si, ax
        mov  cx, 9
colLp:  mov  al, board[si]
        cmp  al, vDigit
        je   ivBad
        add  si, 9
        loop colLp

        mov  al, vRow           ; 3x3 box scan
        xor  ah, ah
        mov  bl, 3
        div  bl
        mov  ah, 0
        mov  bl, 3
        mul  bl
        mov  vBR, al
        mov  al, vCol
        xor  ah, ah
        mov  bl, 3
        div  bl
        mov  ah, 0
        mov  bl, 3
        mul  bl
        mov  vBC, al
        mov  al, vBR
        mov  bl, 9
        mul  bl
        mov  bl, vBC
        xor  bh, bh
        add  ax, bx
        mov  si, ax
        mov  dl, 3
boxRow: mov  cx, 3
        push si
boxCol: mov  al, board[si]
        cmp  al, vDigit
        je   boxBad
        inc  si
        loop boxCol
        pop  si
        add  si, 9
        dec  dl
        jnz  boxRow

        mov  al, 1
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
;  solve:  recursive backtracking. Returns AL=1 if solved.
;  Preserves SI,CX,BX so loop state survives the recursion.
; ------------------------------------------------------------
solve   PROC
        push si
        push cx
        push bx

        xor  si, si
findE:  cmp  si, 81
        jae  allFull
        cmp  byte ptr board[si], 0
        je   cellE
        inc  si
        jmp  findE
allFull:
        mov  al, 1
        jmp  sDone
cellE:  mov  cl, 1
tryD:   cmp  cl, 9
        ja   sFail
        mov  bx, si
        mov  al, cl
        call isValid
        or   al, al
        jz   nextD
        mov  al, cl
        mov  board[si], al
        call solve
        or   al, al
        jnz  sOk
        mov  byte ptr board[si], 0
nextD:  inc  cl
        jmp  tryD
sFail:  xor  al, al
        jmp  sDone
sOk:    mov  al, 1
sDone:  pop  bx
        pop  cx
        pop  si
        ret
solve   ENDP

; ------------------------------------------------------------
;  copyPuzzle:  copy puzzle[pIdx] into board.  Needs ES = DS.
; ------------------------------------------------------------
copyPuzzle PROC
        push si
        push di
        push cx
        mov  bx, pIdx
        shl  bx, 1
        mov  si, ptrTbl[bx]
        mov  di, OFFSET board
        mov  cx, 81
        cld
        rep  movsb
        pop  cx
        pop  di
        pop  si
        ret
copyPuzzle ENDP

; ------------------------------------------------------------
;  clrScreen:  reset to text mode 80x25, which clears it and
;  homes the cursor (so each puzzle starts at the top).
; ------------------------------------------------------------
clrScreen PROC
        mov  ax, 0003h         ; AH=00 set mode, AL=03 = 80x25 color text
        int  10h
        ret
clrScreen ENDP

; ------------------------------------------------------------
;  printGrid:  print the working board as a spaced 9x9 grid.
; ------------------------------------------------------------
printGrid PROC
        xor  si, si
pgLoop: cmp  si, 81
        jae  pgEnd
        mov  dl, board[si]
        add  dl, '0'
        mov  ah, 02h
        int  21h
        mov  dl, ' '
        mov  ah, 02h
        int  21h
        inc  si
        mov  ax, si
        mov  bl, 9
        div  bl
        cmp  ah, 0
        jne  pgLoop
        mov  dl, 13
        mov  ah, 02h
        int  21h
        mov  dl, 10
        mov  ah, 02h
        int  21h
        jmp  pgLoop
pgEnd:  ret
printGrid ENDP

; ------------------------------------------------------------
main    PROC
        mov  ax, @data
        mov  ds, ax
        mov  es, ax

        mov  word ptr pIdx, 0
nextPuz:
        cmp  word ptr pIdx, 2
        jae  allDone

        call clrScreen         ; fresh screen for this puzzle

        mov  dx, OFFSET hdr     ; "--- Puzzle N ---"
        mov  ah, 09h
        int  21h
        mov  ax, pIdx
        add  al, '1'
        mov  dl, al
        mov  ah, 02h
        int  21h
        mov  dx, OFFSET tail
        mov  ah, 09h
        int  21h

        call copyPuzzle
        call solve
        or   al, al
        jz   pNo
        call printGrid
        jmp  pAfter
pNo:    mov  dx, OFFSET noMsg
        mov  ah, 09h
        int  21h

pAfter: ; pause for a key (so the screen isn't wiped before you read it)
        mov  dx, OFFSET prompt
        mov  ah, 09h
        int  21h
        mov  ah, 08h           ; read one key, no echo
        int  21h

        inc  word ptr pIdx
        jmp  nextPuz

allDone:
        mov  ax, 4C00h
        int  21h
main    ENDP
        END  main