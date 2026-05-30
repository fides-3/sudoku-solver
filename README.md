# Sudoku Solver (16-bit MASM)

A DOS real-mode Sudoku solver written in 16-bit MASM assembly. It holds a set
of puzzles, solves each one with recursive backtracking, and prints the
completed grid. The current build (`sudoku2_paged.asm`) ships with two puzzles
and pauses for a keypress between them so each fits on the 80×25 screen.

## Quick start

Assemble and link with MASM (ML 6.x):

```
ML /AT sudoku2_paged.asm
```

Or with TASM:

```
TASM sudoku2_paged.asm
TLINK sudoku2_paged.obj
```

Then run the resulting `.exe` inside DOSBox (or any 8086/DOS environment):

```
sudoku2_paged.exe
```

You'll see "Puzzle 1", its solved grid, a "Press any key" prompt, then the
screen clears and "Puzzle 2" appears the same way.

## How it works

The program is built around one idea: **recursive backtracking**. It fills the
grid one empty cell at a time, and whenever a choice leads to a dead end it
erases that choice and tries the next one. Three pieces cooperate to make this
work.

### The board

The grid is 81 bytes in memory, stored row by row, where `0` marks an empty
cell and `1`–`9` are filled values. Cell `i` sits at row `i / 9` and column
`i % 9`. There is one working array, `board`, that the solver always operates
on; each puzzle is copied into it before solving.

### `solve` — the backtracking search

`solve` scans `board` for the first empty cell. If there isn't one, the grid is
full and it reports success. Otherwise it tries digits 1 through 9 in that cell.
For each candidate it asks `isValid` whether the digit is legal; if so, it
writes the digit and calls itself to fill the rest of the grid. If that deeper
call eventually succeeds, the puzzle is solved. If the digit leads nowhere, the
line `mov byte ptr board[si], 0` erases it — this is the *undo* — and the loop
moves on to the next digit. When no digit fits, `solve` returns failure, which
hands control back to the previous cell so it can try its own next option.

`solve` returns `AL = 1` on success and `AL = 0` on failure.

### `isValid` — the legality check

Given a cell index and a candidate digit, `isValid` returns true only if the
digit does not already appear in that cell's row, column, or 3×3 box. It runs
three scans: across the row (starting at `row*9`, stepping by 1), down the
column (starting at `col`, stepping by 9), and through the box (snap the row and
column down to the nearest multiple of 3, then walk the 3×3 region). Any match
means the digit is illegal.

### Register discipline (the part that's easy to get wrong)

Because the solver mutates a single shared `board` rather than copying it, two
rules keep the search from corrupting itself:

1. **Undo on backtrack.** Every digit that's placed must be erased if its branch
   fails, so the grid always reflects only the choices still in play.
2. **Preserve loop state across recursion.** `solve` pushes `SI`, `CX`, and `BX`
   on entry and restores them on exit. That means when a recursive call returns,
   the parent's *current empty-cell index* and *digit being tried* are exactly
   as it left them, so its loop continues correctly. `isValid` likewise
   preserves the registers it touches.

The scratch variables `vRow`, `vCol`, `vBR`, `vBC`, and `vDigit` are globals
rather than stack locals. That's safe only because `isValid` never recurses and
always returns before `solve` recurses, so no two `isValid` calls are ever live
at the same time.

### Output and paging

A standard DOS text screen is 80 columns by 25 rows. Several solved grids in a
row print more than 25 lines, so earlier puzzles scroll off the top. To avoid
that, the program clears the screen (`INT 10h`, mode `03h`) before each puzzle
and waits for a keypress (`INT 21h`, function `08h`) after each one. Printing
uses DOS teletype output (`INT 21h`, function `02h` for a character, `09h` for a
`$`-terminated string).

## Program structure

| Procedure    | Role                                                        |
|--------------|-------------------------------------------------------------|
| `main`       | Sets up segments, loops over the puzzles, drives I/O        |
| `copyPuzzle` | Copies the selected puzzle into `board` (`rep movsb`)       |
| `solve`      | Recursive backtracking search                               |
| `isValid`    | Row / column / box conflict check                           |
| `printGrid`  | Prints `board` as a spaced 9×9 grid                         |
| `clrScreen`  | Resets text mode to clear the screen                        |

Puzzles are stored as labelled 81-byte blocks (`puzzle1`, `puzzle2`). The word
array `ptrTbl` holds their addresses, and `pIdx` tracks which puzzle is current.

## Adding or changing puzzles

To replace a puzzle, edit the 81 bytes after its label. Keep it to 9 rows of 9
values, use `0` for blanks, and make sure the puzzle is actually solvable.

To add another puzzle:

1. Define a new block, e.g. `puzzle3 db ...` (81 bytes).
2. Add it to the address table: `ptrTbl dw puzzle1, puzzle2, puzzle3`.
3. Raise the loop bound in `main` from `cmp word ptr pIdx, 2` to `3`.

## Troubleshooting

If the build prints garbled digits or a corrupted grid, suspect the undo step or
the register preservation in `solve` — that's the usual failure mode for
backtracking in assembly. If it prints "No solution." for a puzzle you know is
solvable, the index math in `isValid` (the row/column/box address calculations)
is the place to look. If the keypress pause or screen clear does nothing, your
emulator may not implement `INT 10h` mode-set or `INT 21h` keyboard input;
removing the `call clrScreen` line and relying on scrolling is a safe fallback.

## Requirements

- MASM (ML 6.x) or TASM to assemble
- DOSBox or another 8086/DOS real-mode environment to run