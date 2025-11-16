################# CSC258 Assembly Final Project ###################
# Columns game
#
# - Draws the playfield border
# - Spawns a 3-cell column with random colours
# - Handles keyboard control: q, w, a, s, d
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
displayaddress:     .word 0x10008000   # base address of bitmap display

# Base addresses of devices
ADDR_DSPL:
    .word 0x10008000                   # display base address
ADDR_KBRD:
    .word 0xffff0000                   # keyboard base address

# 6 gem colours: red, orange, yellow, green, blue, purple
COLORS:
    .word 0xff0000      # red
    .word 0xff8000      # orange
    .word 0xffff00      # yellow
    .word 0x00ff00      # green
    .word 0x0000ff      # blue
    .word 0x8000ff      # purple

# Column position (top cell) and colours
col_x:  .word 0         # x position of top cell (in units)
col_y:  .word 0         # y position of top cell (in units)
col_c0: .word 0         # colour of top cell
col_c1: .word 0         # colour of middle cell
col_c2: .word 0         # colour of bottom cell

##############################################################################
# Code
##############################################################################
    .text
    .globl main

# Main entry point
main:
    # Load some basic colour constants (not all are used directly here)
    li  $t1, 0xff0000        # $t1 = red
    li  $t2, 0x00ff00        # $t2 = green
    li  $t3, 0x0000ff        # $t3 = blue
    li  $t4, 0x808080        # $t4 = grey (used for drawing border)

    # Load display base address into $s0 (saved register)
    lw  $s0, displayaddress  # $s0 = base of display memory

########################
# Draw playfield border
########################

    # Left vertical line: x = 3, y = 5, width = 1, height = 15
    addi $a0, $zero, 3       # $a0 = 3 (x)
    addi $a1, $zero, 5       # $a1 = 5 (y)
    addi $a2, $zero, 1       # $a2 = 1 (width)
    addi $a3, $zero, 15      # $a3 = 15 (height)
    jal  draw_rect           # draw rectangle for left border

    # Top horizontal line: x = 3, y = 5, width = 8, height = 1
    addi $a0, $zero, 3       # $a0 = 3 (x)
    addi $a1, $zero, 5       # $a1 = 5 (y)
    addi $a2, $zero, 8       # $a2 = 8 (width)
    addi $a3, $zero, 1       # $a3 = 1 (height)
    jal  draw_rect           # draw rectangle for top border

    # Bottom horizontal line: x = 3, y = 19, width = 8, height = 1
    addi $a0, $zero, 3       # $a0 = 3 (x)
    addi $a1, $zero, 19      # $a1 = 19 (y)
    addi $a2, $zero, 8       # $a2 = 8 (width)
    addi $a3, $zero, 1       # $a3 = 1 (height)
    jal  draw_rect           # draw rectangle for bottom border

    # Right vertical line: x = 10, y = 5, width = 1, height = 15
    addi $a0, $zero, 10      # $a0 = 10 (x)
    addi $a1, $zero, 5       # $a1 = 5 (y)
    addi $a2, $zero, 1       # $a2 = 1 (width)
    addi $a3, $zero, 15      # $a3 = 15 (height)
    jal  draw_rect           # draw rectangle for right border

########################
# Initialise and draw first column
########################

    # Choose random colour for top cell
    jal rand_color           # get random colour in $v0
    sw  $v0, col_c0          # store as top colour

    # Choose random colour for middle cell
    jal rand_color           # get random colour in $v0
    sw  $v0, col_c1          # store as middle colour

    # Choose random colour for bottom cell
    jal rand_color           # get random colour in $v0
    sw  $v0, col_c2          # store as bottom colour

    # Starting position of top cell inside border (x = 7, y = 6)
    li  $t5, 7               # $t5 = 7 (x)
    li  $t6, 6               # $t6 = 6 (y)
    sw  $t5, col_x           # save x in col_x
    sw  $t6, col_y           # save y in col_y

    # Draw the three cells at the initial position

    # Top cell at (7, 6)
    lw  $t4, col_c0          # $t4 = top colour
    move $a0, $t5            # $a0 = 7 (x)
    move $a1, $t6            # $a1 = 6 (y)
    li   $a2, 1              # $a2 = 1 (line length)
    jal  draw_line           # draw top cell

    # Middle cell at (7, 7)
    addi $t6, $t6, 1         # $t6 = 7 (y + 1)
    lw  $t4, col_c1          # $t4 = middle colour
    move $a0, $t5            # $a0 = 7 (x)
    move $a1, $t6            # $a1 = 7 (y)
    li   $a2, 1              # $a2 = 1
    jal  draw_line           # draw middle cell

    # Bottom cell at (7, 8)
    addi $t6, $t6, 1         # $t6 = 8 (y + 2)
    lw  $t4, col_c2          # $t4 = bottom colour
    move $a0, $t5            # $a0 = 7 (x)
    move $a1, $t6            # $a1 = 8 (y)
    li   $a2, 1              # $a2 = 1
    jal  draw_line           # draw bottom cell

    # Jump into the main game loop
    j   game_loop


##############################################################################
# draw_line
#
# Draws a horizontal line of length $a2 at position ($a0, $a1).
#
# Arguments:
#   $a0 = x coordinate (in units)
#   $a1 = y coordinate (in units)
#   $a2 = line length (in units)
#
# Uses:
#   $t2 = current pixel address
#   $t3 = end pixel address
#   $t4 = colour
##############################################################################
draw_line:
    sll $a0, $a0, 2         # convert x to byte offset: x * 4
    add $t2, $s0, $a0       # $t2 = display base + x offset
    sll $a1, $a1, 7         # convert y to byte offset: y * 128
    add $t2, $t2, $a1       # $t2 = base + x offset + y offset

    sll $a2, $a2, 2         # convert length to bytes: length * 4
    add $t3, $t2, $a2       # $t3 = end address of line

line_loop_start:
    beq $t2, $t3, line_loop_end  # stop if we've reached end address
    sw  $t4, 0($t2)              # store colour at current pixel
    addi $t2, $t2, 4             # move to next pixel in row
    j   line_loop_start          # repeat for the rest of the line

line_loop_end:
    jr  $ra                      # return to caller


##############################################################################
# draw_rect
#
# Draws a rectangle of width $a2 and height $a3 with top-left corner at
# ($a0, $a1). Each row is drawn using draw_line.
##############################################################################
draw_rect:
# Use $a3 as loop counter for number of rows
rect_loop_start:
    beq  $a3, $zero, rect_loop_end   # if no more rows, exit

    addi $sp, $sp, -4                # make space on stack
    sw   $ra, 0($sp)                 # push $ra
    addi $sp, $sp, -4
    sw   $a0, 0($sp)                 # push $a0 (x)
    addi $sp, $sp, -4
    sw   $a1, 0($sp)                 # push $a1 (y)
    addi $sp, $sp, -4
    sw   $a2, 0($sp)                 # push $a2 (width)

    jal  draw_line                   # draw one horizontal row

    lw   $a2, 0($sp)                 # restore $a2 (width)
    addi $sp, $sp, 4                 # pop
    lw   $a1, 0($sp)                 # restore $a1 (y)
    addi $sp, $sp, 4
    lw   $a0, 0($sp)                 # restore $a0 (x)
    addi $sp, $sp, 4
    lw   $ra, 0($sp)                 # restore $ra
    addi $sp, $sp, 4                 # pop

    addi $a1, $a1, 1                 # move y down by 1 row
    addi $a3, $a3, -1                # one less row to draw
    j    rect_loop_start             # draw next row

rect_loop_end:
    jr   $ra                         # return to caller


######################## rand_color ########################
# Returns a random colour from the COLORS table in $v0.
#
# Steps:
#   1. Generate random integer r in [0, 6)
#   2. Return COLORS[r]
################################################################
rand_color:
    li  $v0, 42           # syscall 42 = random integer
    li  $a0, 0            # RNG id = 0
    li  $a1, 6            # upper bound (exclusive) = 6
    syscall               # random index r returned in $a0

    la  $t0, COLORS       # $t0 = base address of colour table
    sll $t1, $a0, 2       # $t1 = r * 4 (byte offset)
    add $t0, $t0, $t1     # $t0 = &COLORS[r]
    lw  $v0, 0($t0)       # $v0 = COLORS[r]
    jr  $ra               # return to caller


######################## redraw_column ########################
# Draws the 3-cell column using the current state:
#   position: (col_x, col_y)
#   colours:  col_c0, col_c1, col_c2
#
# Note: there is no "jr $ra" at the end. After drawing, execution
#       continues directly into game_loop.
################################################################
redraw_column:
    # Load current column position
    lw  $t5, col_x        # $t5 = x of top cell
    lw  $t6, col_y        # $t6 = y of top cell

    # Draw top cell
    lw  $t4, col_c0       # $t4 = top cell colour
    move $a0, $t5         # $a0 = x
    move $a1, $t6         # $a1 = y (top)
    li   $a2, 1           # $a2 = 1 (length)
    jal  draw_line        # draw top cell

    # Draw middle cell at y + 1
    addi $t6, $t6, 1      # $t6 = y + 1
    lw  $t4, col_c1       # $t4 = middle cell colour
    move $a0, $t5         # $a0 = x
    move $a1, $t6         # $a1 = y + 1
    li   $a2, 1           # $a2 = 1
    jal  draw_line        # draw middle cell

    # Draw bottom cell at y + 2
    addi $t6, $t6, 1      # $t6 = y + 2
    lw  $t4, col_c2       # $t4 = bottom cell colour
    move $a0, $t5         # $a0 = x
    move $a1, $t6         # $a1 = y + 2
    li   $a2, 1           # $a2 = 1
    jal  draw_line        # draw bottom cell

    # No jr $ra here: fall through into game_loop


##############################################################################
# game_loop
#
# Main control loop. Reads keyboard input and responds to:
#   q : quit
#   w : rotate column colours
#   a : move column left
#   d : move column right
#   s : move column down
##############################################################################
game_loop:
    # Load keyboard base address
    lw  $s1, ADDR_KBRD          # $s1 = &keyboard

    # Read keyboard status: 1 if a key is ready, 0 otherwise
    lw  $t8, 0($s1)             # $t8 = status word
    beq $t8, $zero, no_key      # if 0, skip key handling

    # A key is ready: read its ASCII code
    lw  $t9, 4($s1)             # $t9 = ASCII code, clears ready flag

    # Check for 'q' (0x71)
    li  $t7, 0x71               # $t7 = 'q'
    beq $t9, $t7, quit_game     # if key == 'q', exit program

    # Check for 'w' (0x77)
    li  $t7, 0x77               # $t7 = 'w'
    beq $t9, $t7, handle_w      # rotate colours

    # Check for 'a' (0x61)
    li  $t7, 0x61               # $t7 = 'a'
    beq $t9, $t7, handle_a      # move column left

    # Check for 'd' (0x64)
    li  $t7, 0x64               # $t7 = 'd'
    beq $t9, $t7, handle_d      # move column right

    # Check for 's' (0x73)
    li  $t7, 0x73               # $t7 = 's'
    beq $t9, $t7, handle_s      # move column down

    # Any other key is ignored

no_key:
    # Short delay between polls so the loop is not too fast
    li  $v0, 32                 # syscall 32 = sleep
    li  $a0, 16                 # sleep for ~16 ms
    syscall                     # perform sleep

    j   game_loop               # repeat main loop


######################## handle_w – rotate colours ########################
# Rotation pattern:
#   (top, middle, bottom) -> (middle, bottom, top)
###########################################################################
handle_w:
    # Load current colours
    lw  $t1, col_c0             # $t1 = old top
    lw  $t2, col_c1             # $t2 = old middle
    lw  $t3, col_c2             # $t3 = old bottom

    # Perform rotation
    sw  $t2, col_c0             # new top = old middle
    sw  $t3, col_c1             # new middle = old bottom
    sw  $t1, col_c2             # new bottom = old top

    # Redraw the column with updated colours
    jal  redraw_column          # returns to game_loop by fall-through


######################## handle_a – move column left #######################
# Column x is kept in [4, 9] so it stays inside the border.
###########################################################################
handle_a:
    # Load current position
    lw  $t5, col_x              # $t5 = current x
    lw  $t6, col_y              # $t6 = current y (top)

    # If already at left limit (4), do not move
    li  $t0, 4                  # left boundary
    beq $t5, $t0, back_to_loop_a

    # Erase old column by drawing black at its current position
    li  $t4, 0                  # $t4 = 0 (background colour)

    # Erase top cell
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over top cell

    # Erase middle cell at y + 1
    addi $t6, $t6, 1            # $t6 = y + 1
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y + 1
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over middle cell

    # Erase bottom cell at y + 2
    addi $t6, $t6, 1            # $t6 = y + 2
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y + 2
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over bottom cell

    # Move column one step left
    lw  $t5, col_x              # reload x
    addi $t5, $t5, -1           # x = x - 1
    sw  $t5, col_x              # store new x

    # Draw column at new position
    jal  redraw_column          # draws and falls into game_loop

back_to_loop_a:
    j   game_loop               # return to main loop


######################## handle_d – move column right ######################
# Column x is kept in [4, 9] so it stays inside the border.
###########################################################################
handle_d:
    # Load current position
    lw  $t5, col_x              # $t5 = current x
    lw  $t6, col_y              # $t6 = current y (top)

    # If already at right limit (9), do not move
    li  $t0, 9                  # right boundary
    beq $t5, $t0, back_to_loop_d

    # Erase old column by drawing black at its current position
    li  $t4, 0                  # $t4 = 0 (background colour)

    # Erase top cell
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over top cell

    # Erase middle cell at y + 1
    addi $t6, $t6, 1            # $t6 = y + 1
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y + 1
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over middle cell

    # Erase bottom cell at y + 2
    addi $t6, $t6, 1            # $t6 = y + 2
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y + 2
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over bottom cell

    # Move column one step right
    lw  $t5, col_x              # reload x
    addi $t5, $t5, 1            # x = x + 1
    sw  $t5, col_x              # store new x

    # Draw column at new position
    jal  redraw_column          # draws and falls into game_loop

back_to_loop_d:
    j   game_loop               # return to main loop


######################## handle_s – move column down #######################
# Column top y is kept in [6, 16] so the 3-cell column stays inside border.
###########################################################################
handle_s:
    # Load current position
    lw  $t5, col_x              # $t5 = current x
    lw  $t6, col_y              # $t6 = current y (top)

    # If already at lower limit (y = 16), do not move
    li  $t0, 16                 # lowest allowed top y
    beq $t6, $t0, back_to_loop_s

    # Erase old column by drawing black at its current position
    li  $t4, 0                  # $t4 = 0 (background colour)

    # Erase top cell
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over top cell

    # Erase middle cell at y + 1
    addi $t6, $t6, 1            # $t6 = y + 1
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y + 1
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over middle cell

    # Erase bottom cell at y + 2
    addi $t6, $t6, 1            # $t6 = y + 2
    move $a0, $t5               # $a0 = x
    move $a1, $t6               # $a1 = y + 2
    li   $a2, 1                 # $a2 = 1
    jal  draw_line              # draw black over bottom cell

    # Move column one step down
    lw  $t6, col_y              # reload y
    addi $t6, $t6, 1            # y = y + 1
    sw  $t6, col_y              # store new y

    # Draw column at new position
    jal  redraw_column          # draws and falls into game_loop

back_to_loop_s:
    j   game_loop               # return to main loop


######################## quit_game #########################################
# Exits the program.
###########################################################################
quit_game:
    li  $v0, 10                 # syscall 10 = exit
    syscall
