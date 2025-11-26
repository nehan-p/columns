################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Raphael Ramesar, 1011069736
# Student 2: Nehan Punjani, 1010928141
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data
##############################################################################
# Immutable Data
##############################################################################

# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL: .word 0x10008000

# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD: .word 0xffff0000

# The colours used in the game
RED: .word 0xff0000
BLUE: .word 0x0000ff
GREEN: .word 0x00674f
ORANGE: .word 0xff8000
YELLOW: .word 0xffff00
PURPLE: .word 0x6f2da8
GREY: .word 0x808080
BLACK: .word 0x000000
WHITE:  .word 0xffffff
OUTLINE: .word 0x333333


# An array of the gem colours
GEM_COLOURS:
        .word 0xff0000
        .word 0x0000ff
        .word 0x00674f
        .word 0xff8000
        .word 0xffff00
        .word 0x6f2da8

# The boundaries for the playing field
LEFT_BOUNDARY: .word 4 # the x coordinate for the left wall
RIGHT_BOUNDARY: .word 11 # the x coordinate for the right wall
TOP_BOUNDARY: .word 14 # the y coordinate for the ceiling
BOTTOM_BOUNDARY: .word 28 # the y coordinate for the floor


gravity_counter: .word 0          # counts ticks until next automatic drop
gravity_speed:        .word 60     # current number of ticks between drops
gravity_min_speed:    .word 15     # fastest allowed speed (smaller = faster)
gravity_level_timer:  .word 0      # counts ticks until we speed up gravity

# Gravity difficulty settings (ticks between automatic drops)
EASY_TICKS:      .word 80     # slowest
MEDIUM_TICKS:    .word 60     # normal
HARD_TICKS:      .word 40     # fastest

# Prompt string for console
DIFF_PROMPT: .asciiz "Select difficulty: 1 = Easy, 2 = Medium, 3 = Hard\n"

    .align 2                 # ensure next label is word-aligned (2^2 = 4 bytes)

##############################################################################
# Mutable Data
##############################################################################

current_column: .space 20 # the coloumn will be represented with 5 pieces of information: x position, y position, colour1, colour2 and colour3

can_move_left: .word 0x0 # keeps track of whether the current column can move left
can_move_right: .word 0x0 # keeps track of whether the current column can move right
has_landed: .word 0x0 # keeps track of whether the current column has either reached the floor or landed on a past column
    
bitmap_copy: .space 4096     # stores a mirror of the bitmap in memory

next_colours: .space 60 # stores the colours for the next five columns

##############################################################################
# Code
##############################################################################
.text
.globl main

# Run the game.
main:
# Initialize the game

lw $s0, ADDR_DSPL # save the starting address of the bitmap since we will be referencing it a lot
la $s1, bitmap_copy # similarly, save the starting address of the bitmap copy 
la $s2, GEM_COLOURS # save the starting address of the array storing the gem colours

# clear the display and the bitmap_copy so restart is clean
jal clear_bitmap
jal clear_bitmap_copy

# reset state flags / counters
sw $zero, can_move_left
sw $zero, can_move_right
sw $zero, has_landed
sw $zero, gravity_counter
sw $zero, gravity_level_timer
# gravity_speed will be overwritten by choose_difficulty anyway, so we don't strictly need to set it here

# let the player choose difficulty
jal choose_difficulty

## Draw the Grid ##
jal draw_grid

## Draw the preview panel ##
jal initialize_next_colours
jal draw_preview_grid

## Initialize a column at the top middle of the playing field ##
jal initialize_player_column

## Draw the column and the outline ##
jal draw_current_column
jal draw_outline

game_loop:
# 1a. Check if key has been pressed 

lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
lw $t8, 0($t0)                  # Load first word from keyboard
beq $t8, 1, keyboard_input      # If first word 1, key is pressed

j keyboard_input_processed      # no key was pressed so we can skip the processing logic

# 1b. Check which key has been pressed

keyboard_input:                     # A key is pressed
lw $a0, 4($t0)                      # Load second word from keyboard, the ascii-encoded value for the key that was pressed

beq $a0, 0x71, respond_to_Q         # Check if the key q was pressed
beq $a0, 0x77, respond_to_W         # Check if the key w was pressed
beq $a0, 0x61, respond_to_A         # Check if the key a was pressed
beq $a0, 0x73, respond_to_S         # Check if the key s was pressed
beq $a0, 0x64, respond_to_D         # Check if the key d was pressed
beq $a0, 0x70, respond_to_P         # Check if the key p was pressed

keyboard_input_processed:           # finished checking if a key was pressed and responded accordingly

# 2a. Check for collisions
jal check_left                      # Check if the column can move left
jal check_right                     # Check if the column can move right
jal check_landed                    # Check if the column has reached the floor or 

# 2b. Respond to collisions

## Check if column has landed ##
lw $t0, has_landed                  # Store whether the players column has reached the floor or landed on a past column
bne $t0, 1, skip_landing_logic      # If column has not reached the floor or landed on a past column, skip this part

## Check for matches (a column landing signals that a match could have been formed) ##

match_checking_loop_start:
jal find_all_horizontal_matches         # find and mark all the horizontal matches in the bitmap copy
jal find_all_vertical_matches           # find and mark all the vertical matches in the bitmap copy
jal find_all_diagonal_matches           # find and mark all the diagonal matches in the bitmap copy
jal check_for_no_matches                # check if there are no matches (value returned in $v0)

beq $v0, 1, match_checking_loop_end     # if $v0 == 1 then there are no matches so we can stop checking 

jal remove_marked_locations             # if $v0 == 0 then there are matches, so remove those gems
jal drop_all_rows                       # drop all of the unsupported gems
j match_checking_loop_start             # we repeat this process in case dropping the unsupported gems formed new matches

match_checking_loop_end:
jal initialize_player_column            # Initialize a new column 
jal draw_current_column                 # Draw this new column to the screen
jal draw_outline                        # Draw the outline for the new column

skip_landing_logic:

# Gradually speed up gravity over time (Easy Feature 2)
jal update_gravity_speed

# Apply gravity automatically each tick (Easy Feature 1)
jal apply_gravity

# Sleep
li $v0, 32
li $a0, 17
syscall

# Go back to Step 1
j game_loop

##############################################################################
# The Helper Functions
##############################################################################

###############################################################################################################
##  The draw_line function
##  - Draws a horizontal line from a given X and Y coordinate 
#
# $a0 = the x coordinate of the line
# $a1 = the y coordinate of the line
# $a2 = the length of the line
# $t1 = the colour for this line (red)
# $t0 = the top left corner of the bitmap display
# $t2 = the starting location for the line.
# $t3 = location for line drawing to stop.

draw_line:

sll $a0, $a0, 2         # multiply the X coordinate by 4 to get the horizontal offset
add $t2, $t0, $a0       # add this horizontal offset to $t0, store the result in $t2
sll $a1, $a1, 7         # multiply the Y coordinate by 128 to get the vertical offset
add $t2, $t2, $a1       # add this vertical offset to $t2

# Make a loop to draw a line.
sll $a2, $a2, 2         # calculate the difference between the starting value for $t2 and the end value.
add $t3, $t2, $a2       # set stopping location for $t2
line_loop_start:
beq $t2, $t3, line_loop_end  # check if $t0 has reached the final location of the line
sw $t1, 0( $t2 )             # paint the current pixel red
addi $t2, $t2, 4             # move $t0 to the next pixel in the row.
j line_loop_start            # jump to the start of the loop
line_loop_end:
jr $ra                  # return to the calling program.

###############################################################################################################

##  The draw_rect function
##  - Draws a rectangle at a given X and Y coordinate 
#
# $a0 = the x coordinate of the line
# $a1 = the y coordinate of the line
# $a2 = the width of the rectangle
# $a3 = the height of the rectangle

draw_rect:

# no registers to initialize (use $a3 as the loop variable)
rect_loop_start:
beq $a3, $zero, rect_loop_end   # test if the stopping condition has been satisfied
addi $sp, $sp, -4               # move the stack pointer to an empty location
sw $ra, 0($sp)                  # push $ra onto the stack
addi $sp, $sp, -4               # move the stack pointer to an empty location
sw $a0, 0($sp)                  # push $a0 onto the stack
addi $sp, $sp, -4               # move the stack pointer to an empty location
sw $a1, 0($sp)                  # push $a1 onto the stack
addi $sp, $sp, -4               # move the stack pointer to an empty location
sw $a2, 0($sp)                  # push $a2 onto the stack

jal draw_line                   # call the draw_line function.

lw $a2, 0($sp)                  # pop $a2 from the stack
addi $sp, $sp, 4                # move the stack pointer to the top stack element
lw $a1, 0($sp)                  # pop $a1 from the stack
addi $sp, $sp, 4                # move the stack pointer to the top stack element
lw $a0, 0($sp)                  # pop $a0 from the stack
addi $sp, $sp, 4                # move the stack pointer to the top stack element
lw $ra, 0($sp)                  # pop $ra from the stack
addi $sp, $sp, 4                # move the stack pointer to the top stack element
addi $a1, $a1, 1                # move the Y coordinate down one row in the bitmap
addi $a3, $a3, -1               # decrement loop variable $a3 by 1
j rect_loop_start               # jump to the top of the loop.
rect_loop_end:
jr $ra                          # return to the calling program.

###############################################################################################################

## The draw_grid function
## - draws the grid which outlines the 6x13 playing field

draw_grid:

lw $t0, ADDR_DSPL      # configure the base address
lw $t1, GREY           # set the colour of the grid 

addi $sp, $sp, -4      # move the stack pointer to an empty location
sw $ra, 0($sp)         # push $ra onto the stack (this is the address that takes us back to our main game loop)

# Draw top horizontal
lw $a0, LEFT_BOUNDARY      # set X coordinate to 4
lw $a1, TOP_BOUNDARY       # set Y coordinate to 14
addi $a2, $zero, 8         # set rect length to 8
addi $a3, $zero, 1         # set rect height to 1
jal draw_rect              # call the rectangle drawing code

# Draw left vertical
lw $a0, LEFT_BOUNDARY      # set X coordinate to 4
lw $a1, TOP_BOUNDARY       # set Y coordinate to 14
addi $a2, $zero, 1         # set rect length to 1
addi $a3, $zero, 15        # set rect height to 15
jal draw_rect              # call the rectangle drawing code

# Draw bottom horizontal
lw $a0, LEFT_BOUNDARY      # set X coordinate to 4
lw $a1, BOTTOM_BOUNDARY    # set Y coordinate to 28
addi $a2, $zero, 8         # set rect length to 8
addi $a3, $zero, 1         # set rect height to 1
jal draw_rect              # call the rectangle drawing code

# Draw right vertical 
lw $a0, RIGHT_BOUNDARY     # set X coordinate to 11
lw $a1, TOP_BOUNDARY       # set Y coordinate to 14
addi $a2, $zero, 1         # set rect length to 1
addi $a3, $zero, 15        # set rect height to 15
jal draw_rect              # call the rectangle drawing code

lw $ra, 0($sp)             # pop $ra from the stack (this is the address that takes us back to our main game loop)
addi $sp, $sp, 4           # move the stack pointer to the top stack element

jr $ra                     # return to the calling program    

###############################################################################################################

## The get_random_colour function
## - stores a random selection of red, green, blue, orange, yellow or purple into $t1

get_random_colour:

# configure the program to generate a random number between 0 and 5 and store it in $a0
li $v0, 42
li $a0, 0
li $a1, 6
syscall

# Put the corresponding colour in $t0 based on the number generated
# 0 -> red, 1 -> green, 2 -> blue, 3 -> orange, 4 -> yellow, 5 -> pruple

check_red: bne $a0, 0, check_green          # if $a0 != 0 then check the case for green
           lw $t1, RED                      # else set  $t1 to RED
           j colour_selected                # jump to end
           
check_green: bne $a0, 1, check_blue         # if $a0 != 1 then check the case for blue
             lw $t1, GREEN                  # else set  $t1 to GREEN
             j colour_selected              # jump to end
             
check_blue: bne $a0, 2, check_orange        # if $a0 != 2 then check the case for orange
            lw $t1, BLUE                    # else set  $t1 to BLUE
            j colour_selected               # jump to end
            
check_orange: bne $a0, 3, check_yellow      # if $a0 != 3 then check the case for yellow
              lw $t1, ORANGE                # else set  $t1 to ORANGE
              j colour_selected             # jump to end
              
check_yellow: bne $a0, 4, check_purple      # if $a0 != 4 then check the case for purple
              lw $t1, YELLOW                # else set  $t1 to YELLOW
              j colour_selected             # jump to end
              
check_purple: lw $t1, PURPLE                # program only reaches here if and only if $a0 == 5
                                            # so set $t1 to PURPLE
colour_selected:    
jr $ra                                      # return to the calling program

###############################################################################################################

## The initialize_player_column function
## - initializes a new column at the top middle of the playing area with three random colours

initialize_player_column:
addi $sp, $sp, -4               # move the stack pointer to an empty location
sw $ra, 0($sp)                  # push $ra onto the stack (this is the address that takes us back to our main game loop)

# first we set the x,y position of the column to roughly the top center of playing field

la $t2, current_column          # $t2 holds the address of the current column struct
lw $t3, LEFT_BOUNDARY           # $t3 holds the x position of the left boundary
addi $t3, $t3, 4                # add 4 to $t3 so it now holds an x position roughly in the middle of the playing field
sw $t3, 0($t2)                  # store this value of $t3 as the x position of the column
lw $t3, TOP_BOUNDARY            # $t3 holds the y position of the ceiling
addi $t3, $t3, 1                # add 1 to $t3 so it now holds an y position of the top of the playing field
sw $t3, 4($t2)                  # store this value of $t3 as the y position of the column

# second we need to set the colours of the column to the first three colours in the colours_array

la $t0, next_colours            # load the starting address of the next_colours array into $t0
lw $t1, 0($t0)                  # load the first colour in the next_colours array into $t1
sw $t1, 8($t2)                  # store this as the first colour of the column
lw $t1, 4($t0)                  # load the second colour in the next_colours array into $t1
sw $t1, 12($t2)                 # store this as the second colour of the column
lw $t1, 8($t0)                  # load the third colour in the next_colours array into $t1
sw $t1, 16($t2)                 # store this as the third colour of the column

jal generate_next_colours       # generate 3 new colours in colours_array
jal draw_preview_columns        # Draw the updated preview columns to the screen

lw $ra, 0($sp)                  # pop $ra from the stack (this is the address that takes us back to our main game loop)
addi $sp, $sp, 4                # move the stack pointer to the top stack element
jr $ra                          # return to the game loop

###############################################################################################################

## The draw_current_column function
## - draws the current column struct stored in memory to the bitmap

draw_current_column:

# first we convert the x, y positions of the column into a bitmap address

lw $t0, ADDR_DSPL               # configure the base address 
la $t1, current_column          # $t1 holds the address of the column struct
lw $t2, 0($t1)                  # load the x position of the column into $t2
sll $t2, $t2, 2                 # multiply the x position by 4 to get the horizontal offset
add $t3, $t0, $t2               # add this horizontal offset to $t0, store the result in $t3
lw $t2, 4($t1)                  # load the y position of the column into $t2
sll $t2, $t2, 7                 # multiply the y position by 128 to get the vertical offset
add $t3, $t3, $t2               # add this vertical offset to $t3, $t3 now stores the bitmap address for the first gem in the column

# second we draw the three gems using the random colours stored in the column struct

lw $t2, 8($t1)                  # load the first colour of the column into $t2 
sw $t2, 0($t3)                  # paint the first gem to the bitmap
lw $t2, 12($t1)                 # load the second colour of the column into $t2 
sw $t2, 128($t3)                # paint the second gem to the bitmap
lw $t2, 16($t1)                 # load the third colour of the column into $t2 
sw $t2, 256($t3)                # paint the third gem to the bitmap

jr $ra                          # return to the calling program

###############################################################################################################

## The erase_current_column function
## - erases the current column from the bitmap

erase_current_column:

# first we convert the x, y positions of the column into a bitmap address

lw $t0, ADDR_DSPL               # configure the base address 
la $t1, current_column          # $t1 holds the address of the column struct
lw $t2, 0($t1)                  # load the x position of the column into $t2
sll $t2, $t2, 2                 # multiply the x position by 4 to get the horizontal offset
add $t3, $t0, $t2               # add this horizontal offset to $t0, store the result in $t3
lw $t2, 4($t1)                  # load the y position of the column into $t2
sll $t2, $t2, 7                 # multiply the y position by 128 to get the vertical offset
add $t3, $t3, $t2               # add this vertical offset to $t3, $t3 now stores the bitmap address for the first gem in the column

# second we erase the three gems from the bitmap by painting them black

lw $t2, BLACK                   # load the first colour of the column into $t2 
sw $t2, 0($t3)                  # paint the first gem to the bitmap
sw $t2, 128($t3)                # paint the second gem to the bitmap
sw $t2, 256($t3)                # paint the third gem to the bitmap

jr $ra                          # return to the calling program

###############################################################################################################

## The code executed when the "q" key is pressed
## - exits the program gracefully
respond_to_Q:
li $v0, 10                          # Quit gracefully
syscall

###############################################################################################################
## game_over logic
## - draws game over screen
## - waits for player to press 'r'
## - restarts game

game_over:
    # Just jump into the drawing routine. We never return to the game,
    # so no need to preserve $ra here.
    j   draw_game_over_screen


wait_for_retry:

    # Use the memory-mapped keyboard just like in the main loop
    lw  $t0, ADDR_KBRD          # base address of keyboard

wait_for_key:
    lw  $t1, 0($t0)             # 1 if a key is pressed, 0 otherwise
    beq $t1, $zero, wait_for_key

    lw  $t2, 4($t0)             # ASCII code of pressed key

    li  $t3, 0x72               # 'r'
    beq $t2, $t3, restart_game  # if 'r', restart

    # If it wasn't 'r', wait for the next key
    j   wait_for_key

restart_game:
    j   main                    # start a brand new game (will re-ask difficulty)

    
## move_column_down
## - moves the current column down by 1 row if it hasn't landed

move_column_down:

    # Save caller's return address
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    lw  $t3, has_landed                # if column has already landed, do nothing
    beq $t3, 1, move_column_down_done_body

    jal erase_current_column           # erase old position

    la  $t1, current_column
    lw  $t2, 4($t1)                    # y position
    addi $t2, $t2, 1                   # y + 1
    sw  $t2, 4($t1)                    # store new y

    jal draw_current_column            # draw in new position

move_column_down_done_body:
    # Restore caller's $ra and return
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


###############################################################################################################
## choose_difficulty
## - asks the player to pick 1 (Easy), 2 (Medium) or 3 (Hard)
## - sets gravity_speed based on the choice

choose_difficulty:

diff_input_loop:
    # print the difficulty prompt message
    li  $v0, 4
    la  $a0, DIFF_PROMPT
    syscall

    # read a single character from user
    li  $v0, 12
    syscall
    move $t0, $v0                      # store the typed character

    # check if user typed '1'
    li  $t1, '1'
    beq $t0, $t1, diff_set_easy

    # check if user typed '2'
    li  $t1, '2'
    beq $t0, $t1, diff_set_medium

    # check if user typed '3'
    li  $t1, '3'
    beq $t0, $t1, diff_set_hard

    # invalid input -> ask again
    j diff_input_loop


diff_set_easy:
    lw $t2, EASY_TICKS
    sw $t2, gravity_speed               # set gravity_speed to slowest
    jr $ra

diff_set_medium:
    lw $t2, MEDIUM_TICKS
    sw $t2, gravity_speed               # set gravity_speed to medium
    jr $ra

diff_set_hard:
    lw $t2, HARD_TICKS
    sw $t2, gravity_speed               # set gravity_speed to fastest
    jr $ra

###############################################################################################################

## The code executed when the "w" key is pressed
## - shuffles the gems in the player's column downward

respond_to_W:

# first we get the colour of the gems in the column

la $t1, current_column          # $t1 holds the address of the column struct
lw $t2, 8($t1)                  # $t2 holds the colour of the first gem
lw $t3, 12($t1)                 # $t3 holds the colour of the second gem
lw $t4, 16($t1)                 # $t4 holds the colour of the third gem

# then we reorder them, first -> second, second -> third, third -> first
sw $t2, 12($t1)                 # first colour goes in the second spot
sw $t3, 16($t1)                 # second colour goes in the third spot
sw $t4, 8($t1)                  # third colour goes in the first spot

jal draw_current_column         # Draw the updated order of gems to the bitmap
j keyboard_input_processed      # return to game loop

###############################################################################################################

## The code executed when the "a" key is pressed
## - move the column to the left

respond_to_A:

lw $t3, can_move_left                       # $t3 either holds a 1 or 0 which checks if the column can move left
beq $t3, $zero, keyboard_input_processed    # if $t3 == 0, column is blocked so do not try to move it left just return to game loop

jal erase_current_column                    # erase the column from the bitmap since it is going to be moved
jal erase_outline

la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
addi $t2, $t2 -1                            # decrement the x position by 1 (move to the left)
sw $t2, 0($t1)                              # update the x position of the column

jal draw_outline
jal draw_current_column                     # Draw the column in its updated location to the bitmap
j keyboard_input_processed                  # return to game loop

###############################################################################################################
## The code executed when the "s" key is pressed
## - move the column down

respond_to_S:
    jal move_column_down
    j   keyboard_input_processed       # back to main loop


###############################################################################################################

## The code executed when the "d" key is pressed
## - move the column to the right

respond_to_D:

lw $t3, can_move_right                      # $t3 either holds a 1 or 0 which checks if the column can move right
beq $t3, $zero, keyboard_input_processed    # if $t3 == 1, column is blocked so do not try to move it right just return to game loop

jal erase_current_column                    # erase the column from the bitmap since it is going to be moved
jal erase_outline

la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
addi $t2, $t2 1                             # increment the x position by 1 (move to the right)
sw $t2, 0($t1)                              # update the x position of the column

jal draw_outline
jal draw_current_column                     # Draw the column in its updated location to the bitmap
j keyboard_input_processed                  # return to game loop


###############################################################################################################
## apply_gravity
## - called every tick from game_loop
## - after enough ticks, automatically moves the column down

apply_gravity:

    # Save return address (game_loop)
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # If the column has landed, just reset the counter and leave
    lw  $t0, has_landed
    bne $t0, $zero, gravity_reset      # if has_landed != 0, skip dropping

    # Not landed: increment the counter
    lw  $t1, gravity_counter
    addi $t1, $t1, 1
    sw  $t1, gravity_counter

    # load the current gravity speed (difficulty changes this value)
    lw  $t2, gravity_speed              
    blt $t1, $t2, gravity_return        # if counter < gravity_speed, do not drop yet

    # Time to drop down one row
    sw  $zero, gravity_counter         # reset counter
    jal move_column_down               # reuse the same movement logic
    j   gravity_return

gravity_reset:
    sw  $zero, gravity_counter         # landed -> keep counter at 0

gravity_return:
    # Restore caller's return address and go back to game_loop
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

###############################################################################################################
## update_gravity_speed
## - called once per game loop
## - every so often, decreases gravity_speed down to gravity_min_speed

update_gravity_speed:

    # Increase "time since last speed-up"
    lw  $t0, gravity_level_timer
    addi $t0, $t0, 1
    sw  $t0, gravity_level_timer

    # Check if it's time to speed up (e.g., every 600 frames)
    # 600 * 17 ms ≈ 10 seconds of real time
    li  $t1, 600
    blt $t0, $t1, ugs_return        # if timer < 600, nothing to do yet

    # Time to speed up gravity
    sw  $zero, gravity_level_timer  # reset timer

    # Load current speed and min speed
    lw  $t2, gravity_speed
    lw  $t3, gravity_min_speed

    # Decrease gravity_speed by 5 (faster), but don't go below min
    addi $t2, $t2, -10
    bge  $t2, $t3, ugs_store        # if new speed >= min, keep it
    add  $t2, $zero, $t3            # else clamp to min

ugs_store:
    sw  $t2, gravity_speed

ugs_return:
    jr  $ra


###############################################################################################################

## The check_left function
## - checks if the current column can move left

check_left:

la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
lw $t3, 4($t1)                              # $t3 holds the y position of the column
addi $t2, $t2, -1                           # $t2 holds the x position one unit left of the column
addi $t3, $t3, 2                            # $t3 holds the y position of the bottom gem in the column

# $t2, $t3 store the x,y coordinate of the pixel to the left of the bottom gem; once this is black the column is free to move left
lw $t0, ADDR_DSPL                           # Store the base address of the bitmap in $t0
sll $t2, $t2, 2                             # multiply the x position by 4 to get the horizontal offset
add $t4, $t0, $t2                           # add this horizontal offset to $t0, store the result in $t4
sll $t3, $t3, 7                             # multiply the y position by 128 to get the vertical offset
add $t4, $t4, $t3                           # add this vertical offset to $t4, $t4 now stores the bitmap address for the target pixel
lw $t2, 0($t4)                              # store the colour in the bitmap at this address in $t2 (we do not need $t2's previous value anymore)

lw $t3, BLACK                               # store the colour black in $t3
bne $t2, $t3, left_blocked                  # if the colour at that location is not black then the left of the column is blocked 
addi $t3, $zero, 1                          # store the value of 1 in $t3
sw $t3, can_move_left                       # set can_move_left to 1 to indicate that the column can move left
jr $ra                                      # return to game loop

left_blocked:                               # in this case the left side of the column is blocked
sw $zero, can_move_left                     # set can_move_left to 0 to indicate that the column cannot move left
jr $ra 

###############################################################################################################

## The check_right function
## - checks if the current column can move right

check_right:

la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
lw $t3, 4($t1)                              # $t3 holds the y position of the column
addi $t2, $t2, 1                            # $t2 holds the x position one unit left of the column
addi $t3, $t3, 2                            # $t3 holds the y position of the bottom gem in the column

# $t2, $t3 store the x,y coordinate of the pixel to the right of the bottom gem; once this is black the column is free to move right
lw $t0, ADDR_DSPL                           # Store the base address of the bitmap in $t0
sll $t2, $t2, 2                             # multiply the x position by 4 to get the horizontal offset
add $t4, $t0, $t2                           # add this horizontal offset to $t0, store the result in $t4
sll $t3, $t3, 7                             # multiply the y position by 128 to get the vertical offset
add $t4, $t4, $t3                           # add this vertical offset to $t4, $t4 now stores the bitmap address for the target pixel
lw $t2, 0($t4)                              # store the colour in the bitmap at this address in $t2 (we do not need $t2's previous value anymore)

lw $t3, BLACK                               # store the colour black in $t3
bne $t2, $t3, right_blocked                 # if the colour at that location is not black then the right of the column is blocked 
addi $t3, $zero, 1                          # store the value of 1 in $t3
sw $t3, can_move_right                      # set can_move_right to 1 to indicate that the column can move right
jr $ra                                      # return to game loop

right_blocked:                              # in this case the right side of the column is blocked
sw $zero, can_move_right                    # set can_move_right to 0 to indicate that the column cannot move right
jr $ra 

###############################################################################################################

## The check_landed function
## - checks if the current column has either reached the floor or landed on a past column

check_landed:

la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
lw $t3, 4($t1)                              # $t3 holds the y position of the column
addi $t3, $t3, 3                            # $t3 holds the y position one unit below the entire column

# $t2, $t3 store the x,y coordinate of the pixel directly below the bottom gem; once this is black the column is free to move downwards
lw $t0, ADDR_DSPL                           # Store the base address of the bitmap in $t0
sll $t2, $t2, 2                             # multiply the x position by 4 to get the horizontal offset
add $t4, $t0, $t2                           # add this horizontal offset to $t0, store the result in $t4
sll $t3, $t3, 7                             # multiply the y position by 128 to get the vertical offset
add $t4, $t4, $t3                           # add this vertical offset to $t4, $t4 now stores the bitmap address for the target pixel
lw $t2, 0($t4)                              # store the colour in the bitmap at this address in $t2 (we do not need $t2's previous value anymore)

lw $t3, BLACK                               # store the colour black in $t3
lw $t9, OUTLINE                             # store the outline colour in $t9

bne $t2, $t3, check_is_outline              # if the colour at that location is not black then check to see if its the outline
j below_clear

check_is_outline:
bne $t2, $t9, below_blocked                 # if the colour at the location is not black AND not an the outline then the column has landed

below_clear:
sw $zero, has_landed                        # set has_landed to 0 to indicate that the column has not reached the floor or landed on a past column
jr $ra                                      # return to game loop

below_blocked:                              # in this case the right side of the column is blocked
addi $t3, $zero, 1                          # store the value of 1 in $t3
sw $t3, has_landed                          # set has_landed to 1 to indicate that the column has either reached the floor or landed on a past column

# check if the column has landed at the very top position
lw  $t2, 4($t1)                         # $t2 = y position of the column
lw  $t4, TOP_BOUNDARY                   # $t4 = top boundary (14)
addi $t4, $t4, 1                        # $t4 = top play row (15)

beq $t2, $t4, game_over                 # if y == top play row, end the game
jr $ra                                  # otherwise, return to game loop

###############################################################################################################

##  The find_horizontal_match function
##  - Looks for a horizontal match of three or more for a given colour on a given row
#
# $a0 = the row to check
# $a1 = the colour we are checking for 

find_horizontal_match:

add $t0, $zero, $zero                       # $t0 is used to store the current number of consectutive gems
add $t6, $zero, $zero                       # $t6 stores the end x for a match, if this is changed from zero a match has been found
addi $t1, $zero, 5                          # $t1 is the loop variable which starts at 5 since that is the x-coordinate of the first column in the playing grid

# we need to convert the row and column to an address in the bitmap
add $t2, $zero, $t1                         # $t2 holds a copy of $t1
sll $t2, $t2, 2                             # multiply this x-value by 4 to get the horizontal offset
add $t3, $s0, $t2                           # add this horizontal offset to $s0 (bitmap address) and store in $t3
add $t7, $zero, $a0                         # $t7 holds a copy of $a0
sll $t7, $t7, 7                             # multiply the y-value (row) by 128 to get the vertical offset
add $t3, $t3, $t7                           # add this vertical offset to $t3

find_horizontal_match_loop_start:
beq $t1, 11, find_horizontal_match_loop_end # when $t1 reaches 11 we would have iterated through the 6 columns in the grid, so loop is complete
lw $t2, 0($t3)                              # get the colour at the address specified by $t3 and store in $t2

bne $t2, $a1, not_colour_looking_for        # check if the colour at the address is the colour we are looking for
bne $t0, $zero, not_first_occurrence        # check if this is the first time we are seeing this colour
add $t4, $zero, $t1                         # if this is the first occurrence, use $t4 to store the starting column of a potential match

not_first_occurrence:
addi $t0, $t0, 1                            # if this is not the first occurrence then $t4 already has a value so just increment the count of consecutive gems

j increment_horizontal_loop_variables       # skip the else logic

not_colour_looking_for:
blt $t0, 3, no_horizontal_match             # if we moved on to a different colour and count is less than 3 then we do not have a match
add $t5, $zero, $t4                         # if we do have a match of three or more, use $t5 to store the starting column of this match
add $t6, $t4, $t0                           # use $t6 to store the ending column (starting column + count) of the match
addi $t6, $t6, -1                           # we need to subtract 1 since the starting column is included

no_horizontal_match:
add $t0, $zero, $zero                       # if we did not find a match simply reset count to 0 and move along

increment_horizontal_loop_variables:
addi $t1, $t1, 1                            # increment the loop variable
addi $t3, $t3, 4                            # increment the bitmap address accordingly

j find_horizontal_match_loop_start          # repeat the process on the next column

find_horizontal_match_loop_end:

# Note that the loop could have finished on a match, so we need to check for this

blt $t0, 3, no_ending_horizontal_match      # check if the number of consectuve gems ($t0) < 3, in this case there is not match
add $t5, $zero, $t4                         # if we do have a match of three or more, use $t5 to store the starting column of this match
add $t6, $t4, $t0                           # use $t6 to store the ending column (starting column + count) of the match
addi $t6, $t6, -1                           # we need to subtract 1 since the starting column is included

no_ending_horizontal_match:

# this code run when there is a match
beq $t6, $zero, find_horizontal_match_end   # check if $t6 was updated from 0

addi $sp, $sp, -4                           # move the stack pointer to an empty location
sw $ra, 0($sp)                              # push $ra onto the stack
                                            
                                            # note that $a0 is still the original value which specifies the row, so we do not need to update its contents
add $a1, $zero, $t5                         # load the the x coordinate of the starting column into $a1
add $a2, $zero, $t6                         # load the the x coordinate of the ending column into $a2
jal horizontal_mark_for_removal             # mark this match for removal in the bitmap copy

lw $ra, 0($sp)                              # pop $ra from the stack
addi $sp, $sp, 4                            # move the stack pointer to the top stack element

find_horizontal_match_end:
jr $ra                                      # return to the calling program

###############################################################################################################

##  The horizontal_mark_for_removal function
##  - given a horizontal match, mark the locations in the bitmap copy 
#
# $a0 = the y coordinate of the horizontal match
# $a1 = the x coordinate of the starting column
# $a2 = the x coordinate of the ending column

horizontal_mark_for_removal:

add $t1, $zero, $a1                         # store a copy of $a1 in $t1
sll $t1, $t1, 2                             # multiply this by 4 to get the horizontal offset
add $t2, $s1, $t1                           # add this horizontal offset to $s1 (bitmap copy address) and store in $t2
sll $a0, $a0, 7                             # multiply the y-value (row) by 128 to get the vertical offset
add $t2, $t2, $a0                           # add this vertical offset to $t2
lw  $t3, RED                                # load the colour red into $t3, this will be used to mark the locations

horizontal_mark_loop_start:
bgt $a1, $a2, horizontal_mark_loop_end      # $a1 will be our loop variable, once it is > $a2 we have marked all the gems in the match
sw $t3, 0($t2)                              # mark the address in the bitmap copy 
addi $a1, $a1, 1                            # increment $a1 by 1
addi $t2, $t2, 4                            # increment $t2 accordingly
j horizontal_mark_loop_start

horizontal_mark_loop_end:
jr $ra                                      # return to the calling program

###############################################################################################################

##  The find_vertical_match function
##  - Looks for a vertical match of three or more for a given colour on a given column
#
# $a0 = the column to check
# $a1 = the colour we are checking for 

find_vertical_match:

add $t0, $zero, $zero                       # $t0 is used to store the current number of consectutive gems
add $t6, $zero, $zero                       # $t6 stores the end y for a match, if this is changed from zero a match has been found
addi $t1, $zero, 15                         # $t1 is the loop variable which starts at 15 since that is the y-coordinate of the first row in the playing grid

# we need to convert the row and column to an address in the bitmap
add $t2, $zero, $t1                         # $t2 holds a copy of $t1
sll $t2, $t2, 7                             # multiply this y-value by 128 to get the vertical offset
add $t3, $s0, $t2                           # add this vertical offset to $s0 (bitmap address) and store in $t3
add $t7, $zero, $a0                         # $t7 holds a copy of $a0
sll $t7, $t7, 2                             # multiply the x-value (column) by 4 to get the horizontal offset
add $t3, $t3, $t7                           # add this horizontal offset to $t3

find_vertical_match_loop_start:
beq $t1, 28, find_vertical_match_loop_end   # when $t1 reaches 28 we would have iterated through the 13 rows in the grid, so loop is complete
lw $t2, 0($t3)                              # get the colour at the address specified by $t3 and store in $t2

bne $t2, $a1, not_colour_looking_for_vertical       # check if the colour at the address is the colour we are looking for
bne $t0, $zero, not_first_occurrence_vertical       # check if this is the first time we are seeing this colour
add $t4, $zero, $t1                                 # if this is the first occurrence, use $t4 to store the starting row of a potential match

not_first_occurrence_vertical:
addi $t0, $t0, 1                            # if this is not the first occurrence then $t4 already has a value so just increment the count of consecutive gems

j increment_vertical_loop_variables       # skip the else logic

not_colour_looking_for_vertical:
blt $t0, 3, no_vertical_match               # if we moved on to a different colour and count is less than 3 then we do not have a match
add $t5, $zero, $t4                         # if we do have a match of three or more, use $t5 to store the starting row of this match
add $t6, $t4, $t0                           # use $t6 to store the ending row (starting row + count) of the match
addi $t6, $t6, -1                           # we need to subtract 1 since the starting row is included

no_vertical_match:
add $t0, $zero, $zero                       # if we did not find a match simply reset count to 0 and move along

increment_vertical_loop_variables:
addi $t1, $t1, 1                            # increment the loop variable
addi $t3, $t3, 128                          # increment the bitmap address accordingly

j find_vertical_match_loop_start            # repeat the process on the next row

find_vertical_match_loop_end:

# Note that the loop could have finished on a match, so we need to check for this

blt $t0, 3, no_ending_vertical_match        # check if the number of consectuve gems ($t0) < 3, in this case there is not match
add $t5, $zero, $t4                         # if we do have a match of three or more, use $t5 to store the starting row of this match
add $t6, $t4, $t0                           # use $t6 to store the ending row (starting row + count) of the match
addi $t6, $t6, -1                           # we need to subtract 1 since the starting row is included

no_ending_vertical_match:

# this code run when there is a match
beq $t6, $zero, find_vertical_match_end     # check if $t6 was updated from 0

addi $sp, $sp, -4                           # move the stack pointer to an empty location
sw $ra, 0($sp)                              # push $ra onto the stack
                                            
                                            # note that $a0 is still the original value which specifies the column, so we do not need to update its contents
add $a1, $zero, $t5                         # load the the y coordinate of the starting row into $a1
add $a2, $zero, $t6                         # load the the y coordinate of the ending row into $a2
jal vertical_mark_for_removal               # mark this match for removal in the bitmap copy

lw $ra, 0($sp)                              # pop $ra from the stack
addi $sp, $sp, 4                            # move the stack pointer to the top stack element

find_vertical_match_end:
jr $ra                                      # return to the calling program

###############################################################################################################

##  The vertical_mark_for_removal function
##  - given a vertical match, mark the locations in the bitmap copy 
#
# $a0 = the x coordinate of the vertical match
# $a1 = the y coordinate of the starting row
# $a2 = the y coordinate of the ending row

vertical_mark_for_removal:

add $t1, $zero, $a1                         # store a copy of $a1 in $t1
sll $t1, $t1, 7                             # multiply this by 128 to get the vertical offset
add $t2, $s1, $t1                           # add this vertical offset to $s1 (bitmap copy address) and store in $t2
sll $a0, $a0, 2                             # multiply the x-value (column) by 4 to get the horizontal offset
add $t2, $t2, $a0                           # add this horizontal offset to $t2
lw  $t3, RED                                # load the colour red into $t3, this will be used to mark the locations

vertical_mark_loop_start:
bgt $a1, $a2, vertical_mark_loop_end        # $a1 will be our loop variable, once it is > $a2 we have marked all the gems in the match
sw $t3, 0($t2)                              # mark the address in the bitmap copy 
addi $a1, $a1, 1                            # increment $a1 by 1
addi $t2, $t2, 128                          # increment $t2 accordingly
j vertical_mark_loop_start

vertical_mark_loop_end:
jr $ra                                      # return to the calling program


###############################################################################################################

## The remove_marked_locations function 
## - goes through the bitmap copy and removes all the marked locations from the actual bitmap

remove_marked_locations:

add $t1, $zero, $zero                               # $t1 will store the offset from the starting address
lw $t2, ADDR_DSPL                                   # $t2 stores the starting address for the bitmap
add $t3, $zero, $s1                                 # $t3 stores the starting address for the bitmap copy
lw $t4, RED                                         # load the colour red into $t4
lw $t9, BLACK                                       # load the colour black into $t9

remove_marked_locations_loop_start:
beq $t1, 4096, remove_marked_locations_loop_end     # the entire bitmap copy has been checked so we can end the loop
lw $t5, 0($t3)                                      # get the colour at the current address in the bitmap copy
bne, $t5, $t4, check_next_pixel                     # check if the colour at the current address in red
sw $t9, 0($t2)                                      # if the pixel is red in the bitmap copy, paint the parallel location in the bitmap black
sw $t9, 0($t3)                                      # remove the mark in the bitmap copy since the pixel has been erased from the bitmap

check_next_pixel:
addi $t1, $t1, 4                                    # increment $t1
addi $t3, $t3, 4                                    # increment the bitmap copy address 
addi $t2, $t2, 4                                    # increment the bitmap address

j remove_marked_locations_loop_start

remove_marked_locations_loop_end:
jr $ra

###############################################################################################################

##  The find_all_vertical_matches function
##  - Looks for all the vertical matches of three or more in the playing grid

find_all_vertical_matches:
addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack

add $t1, $zero, $zero                           # $t1 stores the offset from the starting address of the colour array

vertical_loop_colours_start:
beq $t1, 24, vertical_loop_colours_end          # when the offset reaches 24 we have checked all the colours
add $t0, $s2, $t1                               # add the offset to the starting address
lw $t2, 0($t0)                                  # load the colour at this address into $t2
addi $t3, $zero, 5                              # the first column to check is column 5

addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $t1, 0($sp)                                  # push $t1 onto the stack


    vertical_loop_columns_start:                # now that we have a colour, we need to loop through all the columns
    beq $t3, 11, vertical_loop_columns_end      # when $t3 reaches 11, we would have looped through all the columns
    add $a0, $zero, $t3                         # load the column into $a0
    add $a1, $zero, $t2                         # load the colour into $a1
    
    addi $sp, $sp, -4                           # move the stack pointer to an empty location
    sw $t3, 0($sp)                              # push $t3 onto the stack
    addi $sp, $sp, -4                           # move the stack pointer to an empty location
    sw $t2, 0($sp)                              # push $t2 onto the stack
    
    jal find_vertical_match                     # look for a vertical match based on this colour and column
    
    lw $t2, 0($sp)                              # pop $t2 from the stack
    addi $sp, $sp, 4                            # move the stack pointer to the top stack element
    lw $t3, 0($sp)                              # pop $t3 from the stack
    addi $sp, $sp, 4                            # move the stack pointer to the top stack element
    
    addi $t3, $t3, 1                            # increment the columm by 1
    j vertical_loop_columns_start               # repeat for the next column 
    
    vertical_loop_columns_end:
    
lw $t1, 0($sp)                                  # pop $t1 from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

addi $t1, $t1, 4                                # move on to the next colour
j vertical_loop_colours_start

vertical_loop_colours_end:

lw $ra, 0($sp)                                  # pop $ra from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

jr $ra                                          # return to game loop

###############################################################################################################

##  The find_all_horizontal_matches function
##  - looks for all the horizontal matches of three or more in the playing grid

find_all_horizontal_matches:
addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack

add $t1, $zero, $zero                           # $t1 stores the offset from the starting address of the colour array

horizontal_loop_colours_start:
beq $t1, 24, horizontal_loop_colours_end        # when the offset reaches 24 we have checked all the colours
add $t0, $s2, $t1                               # add the offset to the starting address
lw $t2, 0($t0)                                  # load the colour at this address into $t2
addi $t3, $zero, 15                             # the first row to check is row 15

addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $t1, 0($sp)                                  # push $t1 onto the stack


    horizontal_loop_rows_start:                 # now that we have a colour, we need to loop through all the rows
    beq $t3, 28, horizontal_loop_rows_end       # when $t3 reaches 28, we would have looped through all the rows
    add $a0, $zero, $t3                         # load the row into $a0
    add $a1, $zero, $t2                         # load the colour into $a1
    
    addi $sp, $sp, -4                           # move the stack pointer to an empty location
    sw $t3, 0($sp)                              # push $t3 onto the stack
    addi $sp, $sp, -4                           # move the stack pointer to an empty location
    sw $t2, 0($sp)                              # push $t2 onto the stack
    
    jal find_horizontal_match                   # look for a horizontal match based on this colour and row
    
    lw $t2, 0($sp)                              # pop $t2 from the stack
    addi $sp, $sp, 4                            # move the stack pointer to the top stack element
    lw $t3, 0($sp)                              # pop $t3 from the stack
    addi $sp, $sp, 4                            # move the stack pointer to the top stack element
    
    addi $t3, $t3, 1                            # increment the row by 1
    j horizontal_loop_rows_start                # repeat for the next row 
    
    horizontal_loop_rows_end:
    
lw $t1, 0($sp)                                  # pop $t1 from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

addi $t1, $t1, 4                                # move on to the next colour
j horizontal_loop_colours_start

horizontal_loop_colours_end:

lw $ra, 0($sp)                                  # pop $ra from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

jr $ra                                          # return to game loop

###############################################################################################################

##  The find_all_diagonal_matches function
##  - looks for all diagonal (down-right and down-left) matches of length 3 in the playing grid
##  - if a match is found, the 3 cells are marked RED in bitmap_copy


find_all_diagonal_matches:

    addi $sp, $sp, -4                  # push $ra onto the stack
    sw   $ra, 0($sp)

    lw   $t8, RED                      # $t8 = RED (marker colour in bitmap_copy)
    lw   $t9, BLACK                    # $t9 = BLACK (empty cell colour)

    addi $t0, $zero, 15                # $t0 = current row, start at first play row (15)

diag_row_loop:
    bgt  $t0, 25, diag_done_rows       # stop at row 25 (need room for row+2)

    addi $t1, $zero, 5                 # $t1 = current column, start at first play column (5)

diag_col_loop:
    bgt  $t1, 10, diag_next_row        # stop at column 10

    # Compute address of the current cell (row = $t0, col = $t1)
    # addr = s0 + (col * 4) + (row * 128)

    add  $t2, $zero, $t1               # $t2 = col
    sll  $t2, $t2, 2                   # col * 4
    addu $t3, $s0,  $t2                # $t3 = base + col*4

    add  $t4, $zero, $t0               # $t4 = row
    sll  $t4, $t4, 7                   # row * 128
    addu $t3, $t3,  $t4                # $t3 = address of (row, col)

    lw   $t5, 0($t3)                   # $t5 = colour at (row, col)
    beq  $t5, $t9, diag_skip_cell      # if current cell is BLACK, no gem to match

    # Check down-right diagonal: (row,col), (row+1,col+1), (row+2,col+2)
    # Only valid if col <= 8 and row <= 25
    # Each step down-right is +132 bytes (+128 row, +4 col)

    bgt  $t1, 8, diag_skip_down_right  # if col > 8, cannot fit 3 down-right
    bgt  $t0, 25, diag_skip_down_right # if row > 25, cannot fit 3 down-right

    addi $t6, $t3, 132                 # address of (row+1, col+1)
    lw   $t7, 0($t6)
    bne  $t7, $t5, diag_skip_down_right

    addi $t6, $t6, 132                 # address of (row+2, col+2)
    lw   $t7, 0($t6)
    bne  $t7, $t5, diag_skip_down_right

    # We have 3 matching gems down-right -> mark them in bitmap_copy

    # mark (row, col)
    subu $t7, $t3, $s0                 # offset = addr - base_display
    addu $t7, $s1, $t7                 # $t7 = corresponding address in bitmap_copy
    sw   $t8, 0($t7)

    # mark (row+1, col+1)
    addi $t7, $t7, 132                 # same +132 stride in bitmap_copy
    sw   $t8, 0($t7)

    # mark (row+2, col+2)
    addi $t7, $t7, 132
    sw   $t8, 0($t7)

diag_skip_down_right:

    # Check down-left diagonal: (row,col), (row+1,col-1), (row+2,col-2)
    # Only valid if col >= 7 and row <= 25
    # Each step down-left is +124 bytes (+128 row, -4 col)
    
    blt  $t1, 7, diag_skip_down_left   # if col < 7, cannot fit 3 down-left
    bgt  $t0, 25, diag_skip_down_left  # if row > 25, cannot fit 3 down-left

    addi $t6, $t3, 124                 # address of (row+1, col-1)
    lw   $t7, 0($t6)
    bne  $t7, $t5, diag_skip_down_left

    addi $t6, $t6, 124                 # address of (row+2, col-2)
    lw   $t7, 0($t6)
    bne  $t7, $t5, diag_skip_down_left

    # We have 3 matching gems down-left -> mark them in bitmap_copy

    # mark (row, col)
    subu $t7, $t3, $s0                 # offset = addr - base_display
    addu $t7, $s1, $t7                 # $t7 = corresponding address in bitmap_copy
    sw   $t8, 0($t7)

    # mark (row+1, col-1)
    addi $t7, $t7, 124                 # +128 row, -4 col in copy
    sw   $t8, 0($t7)

    # mark (row+2, col-2)
    addi $t7, $t7, 124
    sw   $t8, 0($t7)

diag_skip_down_left:

diag_skip_cell:
    addi $t1, $t1, 1                   # move to next column
    j    diag_col_loop

diag_next_row:
    addi $t0, $t0, 1                   # move to next row
    j    diag_row_loop

diag_done_rows:
    lw   $ra, 0($sp)                   # restore $ra
    addi $sp, $sp, 4                   # restore stack pointer
    jr   $ra                           # return to the calling code
    
###############################################################################################################

## the drop_row function 
## - drops any gems in a given that are no longer supported 
#
# $a0 = the row to be dropped

drop_row:

addi $t0, $zero, 5                              # $t0 stores the x value of the starting column
add $t1, $t0, $zero                             # $t1 stores a copy of $t0
lw $t9, BLACK                                   # store the colour black in $t9
sll $t1, $t1, 2                                 # multiply $t1 by 4 to get the horizontal offset
add $t2, $s0, $t1                               # add this offset to the base address of the bitmap
sll $a0, $a0, 7                                 # multiply $a0 by 128 to get the vertical offset
add $t2, $t2, $a0                               # add this offset to $t2

drop_row_outer_loop_start:                      # this loops through all the gems in the given row
beq $t0, 11, drop_row_outer_loop_end            # when $t0 reaches 11 we would have dropped all the gems in a row
lw $t3, 0($t2)                                  # $t3 stores the colour at the bitmap address specified by $t2
beq $t3, $t9, drop_next_gem                     # if the colour is black then there is no gem to drop in this location

sw $t9, 0($t2)                                  # If there is a gem in this location, erase it from the bitmap 
add $t4, $zero, $t2                             # store the current address in $t4

    drop_row_inner_loop_start:                  # this loop drops the current gem as far down as it can go
    addi $t5, $t4, 128                          # store the address directly below the current address in $t5
    lw $t6, 0($t5)                              # store the colour at this address in $t6
    bne $t6, $t9, drop_row_inner_loop_end       # if the colour below the gem is not black, the gem cannot drop any further
    add $t4, $t5, $zero                         # if the colour below the gem is black, it can be dropped so update the current address to the address directly below
    j drop_row_inner_loop_start
    
    drop_row_inner_loop_end:
    sw $t3, 0($t4)                              # paint the current address the colour of the gem


drop_next_gem:
addi $t0, $t0, 1                                # increment the column we are on
addi $t2, $t2, 4                                # increment the bitmap address accordingly
j drop_row_outer_loop_start                     # repeat for next column in row

drop_row_outer_loop_end:
jr $ra

###############################################################################################################

## the drop_all_rows function 
## - drops all floating gems

drop_all_rows:

addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack

addi $t7, $zero, 26                             # $t7 stores the first row to be dropped (note we drop from the second to last row up)

drop_rows_loop_start:
beq $t7, 14, drop_rows_loop_end                 # once $t7 reaches 14 we would have dropped all the rows in the playing field
add $a0, $zero, $t7                             # load the current row into $a0
jal drop_row                                    # drop the gems in the row specified by $a0
addi $t7, $t7, -1                               # decrement $t7 by 1
j drop_rows_loop_start                          # repeat for next row

drop_rows_loop_end:
lw $ra, 0($sp)                                  # pop $ra from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element
jr $ra

###############################################################################################################

## the check_for_no_matches function 
## - checks if there are no matches in the playing grid

check_for_no_matches:

add $t0, $zero, $zero                           # store the offset from the starting address in $t0
add $t1, $s1, $zero                             # load the starting address of the bitmap copy into $t1
lw $t2, RED                                     # store the colour red in $t2

check_for_no_matches_loop_start:            
beq $t0, 4096, check_for_no_matches_loop_end    # the entire bitmap copy has been checked so we can end the loop
lw $t3, 0($t1)                                  # get the colour at the current address in the bitmap copy
bne $t3, $t2, not_marked                        # check if the colour at that address is red
li $v0, 0                                       # if the colour is red then we have a marked location which means there is a match
jr $ra                                          # early return to the calling program

not_marked:                                     # if the colour at the address is not red we need to move on to the next address
addi $t0, $t0, 4                                # increment the offset so we can track where we are in the bitmap copy
addi $t1, $t1, 4                                # increment the current address
j check_for_no_matches_loop_start

check_for_no_matches_loop_end:
li $v0, 1                                       # "return" a 1 if the entire bitmap copy has been searched and there was no marked locations (no matches)
jr $ra                                          # return to the calling program

###############################################################################################################
## clear_bitmap
## - fills the whole display with BLACK

clear_bitmap:
    lw  $t0, ADDR_DSPL      # base address of display
    lw  $t1, BLACK          # colour black
    li  $t2, 1024           # 4096 bytes / 4 = 1024 words

clear_bitmap_loop:
    sw  $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    bgtz $t2, clear_bitmap_loop
    jr  $ra


###############################################################################################################
## clear_bitmap_copy
## - fills the mirror bitmap_copy with BLACK as well

clear_bitmap_copy:
    la  $t0, bitmap_copy    # base address of bitmap_copy
    lw  $t1, BLACK
    li  $t2, 1024

clear_copy_loop:
    sw  $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    bgtz $t2, clear_copy_loop
    jr  $ra


###############################################################################################################
## draw_game_over_screen
## - clears display
## - draws big, clearly spaced "OVER" in orange
## - draws big, clearly spaced "RESTART" (first R red, rest white)
## - then waits for user to press 'r'
###############################################################################################################

draw_game_over_screen:

    # clear screen to black
    jal clear_bitmap

    # base address for draw_line / draw_rect
    lw  $t0, ADDR_DSPL
    
    # "OVER" in ORANGE 
    lw  $t1, ORANGE

    #### O at x = 6..9, y = 6..10 ####
    # top
    li $a0, 6
    li $a1, 6
    li $a2, 4
    li $a3, 1
    jal draw_rect
    # bottom
    li $a0, 6
    li $a1, 10
    li $a2, 4
    li $a3, 1
    jal draw_rect
    # left side
    li $a0, 6
    li $a1, 7
    li $a2, 1
    li $a3, 3
    jal draw_rect
    # right side
    li $a0, 9
    li $a1, 7
    li $a2, 1
    li $a3, 3
    jal draw_rect

    #### V at x = 11..14, y = 6..10 ####
    # left stroke
    li $a0, 11
    li $a1, 6
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # right stroke
    li $a0, 14
    li $a1, 6
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # bottom connector
    li $a0, 12
    li $a1, 10
    li $a2, 2
    li $a3, 1
    jal draw_rect

    #### E at x = 16..19, y = 6..10 ####
    # spine
    li $a0, 16
    li $a1, 6
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # top bar
    li $a0, 16
    li $a1, 6
    li $a2, 4
    li $a3, 1
    jal draw_rect
    # middle bar
    li $a0, 16
    li $a1, 8
    li $a2, 4
    li $a3, 1
    jal draw_rect
    # bottom bar
    li $a0, 16
    li $a1, 10
    li $a2, 4
    li $a3, 1
    jal draw_rect

    #### R at x = 21..24, y = 6..10 ####
    # spine
    li $a0, 21
    li $a1, 6
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # top bar
    li $a0, 21
    li $a1, 6
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # middle bar
    li $a0, 21
    li $a1, 8
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # right side of loop
    li $a0, 23
    li $a1, 7
    li $a2, 1
    li $a3, 2
    jal draw_rect
    # lower leg 
    li $a0, 22          # x
    li $a1, 9           # y
    li $a2, 1           # width
    li $a3, 1           # height
    jal draw_rect
    
    # additional pixel
    li $a0, 23          # x
    li $a1, 10           # y
    li $a2, 1           # width
    li $a3, 1           # height
    jal draw_rect

    # "RESTART" below 

    #### First R in RED ####
    lw  $t1, RED

    # R at x = 3..5, y = 14..18
    # spine
    li $a0, 3
    li $a1, 14
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # top bar
    li $a0, 3
    li $a1, 14
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # middle bar
    li $a0, 3
    li $a1, 16
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # right of loop
    li $a0, 5
    li $a1, 15
    li $a2, 1
    li $a3, 2
    jal draw_rect
    # small lower leg
    li $a0, 4          # x
    li $a1, 17         # y
    li $a2, 1          # width
    li $a3, 1          # height
    jal draw_rect
    
    # one additional pixel
    li $a0, 5          # x
    li $a1, 18         # y
    li $a2, 1          # width
    li $a3, 1          # height
    jal draw_rect

    #### "ESTART" in WHITE ####
    lw  $t1, WHITE

    #### E at x = 7..9 ####
    # spine
    li $a0, 7
    li $a1, 14
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # top bar
    li $a0, 7
    li $a1, 14
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # middle bar
    li $a0, 7
    li $a1, 16
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # bottom bar
    li $a0, 7
    li $a1, 18
    li $a2, 3
    li $a3, 1
    jal draw_rect

    #### S at x = 11..13 ####
    # top
    li $a0, 11
    li $a1, 14
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # upper left
    li $a0, 11
    li $a1, 15
    li $a2, 1
    li $a3, 1
    jal draw_rect
    # middle
    li $a0, 11
    li $a1, 16
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # lower right
    li $a0, 13
    li $a1, 17
    li $a2, 1
    li $a3, 1
    jal draw_rect
    # bottom
    li $a0, 11
    li $a1, 18
    li $a2, 3
    li $a3, 1
    jal draw_rect

    #### T at x = 15..17 ####
    # top bar
    li $a0, 15
    li $a1, 14
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # stem
    li $a0, 16
    li $a1, 15
    li $a2, 1
    li $a3, 4
    jal draw_rect

    #### A at x = 19..21 ####
    # peak
    li $a0, 20
    li $a1, 14
    li $a2, 1
    li $a3, 1
    jal draw_rect
    # left leg
    li $a0, 19
    li $a1, 15
    li $a2, 1
    li $a3, 4
    jal draw_rect
    # right leg
    li $a0, 21
    li $a1, 15
    li $a2, 1
    li $a3, 4
    jal draw_rect
    # middle bar
    li $a0, 19
    li $a1, 16
    li $a2, 3
    li $a3, 1
    jal draw_rect

    #### second R at x = 23..25 ####
    # spine
    li $a0, 23
    li $a1, 14
    li $a2, 1
    li $a3, 5
    jal draw_rect
    # top bar
    li $a0, 23
    li $a1, 14
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # middle bar
    li $a0, 23
    li $a1, 16
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # right of loop
    li $a0, 25
    li $a1, 15
    li $a2, 1
    li $a3, 2
    jal draw_rect
    # lower leg 
    li $a0, 24         # x
    li $a1, 17         # y
    li $a2, 1          # width
    li $a3, 1          # height
    jal draw_rect
    
     #addtional pixel
    li $a0, 25         # x
    li $a1, 18         # y
    li $a2, 1          # width
    li $a3, 1          # height
    jal draw_rect

    #### final T at x = 27..29 ####
    # top bar
    li $a0, 27
    li $a1, 14
    li $a2, 3
    li $a3, 1
    jal draw_rect
    # stem
    li $a0, 28
    li $a1, 15
    li $a2, 1
    li $a3, 4
    jal draw_rect

    # finished drawing, now wait for 'r'
    j   wait_for_retry

###############################################################################################################

## the initialize_next_colours function \
## - initializes the next_colours array so that is stores 15 random colours

initialize_next_colours:
addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack (this is the address that takes us back to our main game loop)

la $t0, next_colours                            # load  the starting address of the next_colours array into $t0
add $t2, $zero, $zero                           # store the offset from the starting address in $t2

initialize_next_colours_loop_start:
beq $t2, 60, initialize_next_colours_loop_end   # if $t2 == 60 then all 15 colours have been placed in the array
jal get_random_colour                           # store a random colour in $t1
sw $t1, 0($t0)                                  # load the colour into the current address stored in $t0
addi $t2, $t2, 4                                # increment the offset
addi $t0, $t0, 4                                # increment the address accordingly
j initialize_next_colours_loop_start            # repeat until all colours have been placed in the array

initialize_next_colours_loop_end:
lw $ra, 0($sp)                                  # pop $ra from the stack (this is the address that takes us back to our main game loop)
addi $sp, $sp, 4                                # move the stack pointer to the top stack element
jr $ra                                          # return to the calling program

###############################################################################################################

## the draw_preview_grid function 
## - draws the grid of the panel which will display the next 5 columns

draw_preview_grid:
addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack (this is the address that takes us back to our main game loop)

add $t0, $zero, $s0                             # set $t0 to the base address of the bitmap
lw $t1, GREY                                    # store the colour into $t1

# Draw top horizontal
addi $a0, $zero, 15        # set X coordinate to 15
addi $a1, $zero, 14        # set Y coordinate to 14
addi $a2, $zero, 13        # set rect length to 13
addi $a3, $zero, 1         # set rect height to 1
jal draw_rect              # call the rectangle drawing code

# Draw left vertical
addi $a0, $zero, 15        # set X coordinate to 15
addi $a1, $zero, 14        # set Y coordinate to 14
addi $a2, $zero, 1         # set rect length to 1
addi $a3, $zero, 5         # set rect height to 5
jal draw_rect              # call the rectangle drawing code

# Draw bottom horizontal
addi $a0, $zero, 15        # set X coordinate to 15
addi $a1, $zero, 18        # set Y coordinate to 18
addi $a2, $zero, 13        # set rect length to 8
addi $a3, $zero, 1         # set rect height to 1
jal draw_rect              # call the rectangle drawing code

# Draw right vertical 
addi $a0, $zero, 27        # set X coordinate to 27
addi $a1, $zero, 14        # set Y coordinate to 14
addi $a2, $zero, 1         # set rect length to 1
addi $a3, $zero, 5         # set rect height to 5
jal draw_rect              # call the rectangle drawing code


lw $ra, 0($sp)             # pop $ra from the stack (this is the address that takes us back to our main game loop)
addi $sp, $sp, 4           # move the stack pointer to the top stack element
jr $ra                     # return to the calling program

###############################################################################################################
## the draw_preview_columns function
## - draws the preview columns from based on the colours stored in the next_colours array

draw_preview_columns:

la $t0, next_colours                            # loads the starting address of the next_colours array into $t0
add $t1, $zero, $s0                             # store the starting address of the bitmap in $t1
addi $t2, $zero, 1988                           # store the offset from this starting address in $t2 (1988 is the offset needed to draw the first preview column at x=17, y=15)
add $t1, $t1, $t2                               # add this offset to the starting address

draw_preview_loop_start:
beq $t2, 2028, draw_preview_loop_end            # when $t2 reaches 2028 we would have drawn all the columns

lw $t3, 0($t0)                                  # store the first colour of the column in $t3
sw $t3, 0($t1)                                  # paint the first gem of this column to the bitmap

addi $t0, $t0, 4                                # move to the address of the second colour
lw $t3, 0($t0)                                  # store the second colour of the column in $t3
sw $t3, 128($t1)                                # paint the second gem of this column to the bitmap

addi $t0, $t0, 4                                # move to the address of the third colour
lw $t3, 0($t0)                                  # store the third colour of the column in $t3
sw $t3, 256($t1)                                # paint the third gem of this column to the bitmap

addi $t2, $t2, 8                                # increment the offset for bitmap
addi $t1, $t1, 8                                # increment the current address for the bitmap accordingly
addi $t0, $t0, 4                                # move to the address of the first colour for the next column
j draw_preview_loop_start                       # jump to loop start

draw_preview_loop_end:
jr $ra


###############################################################################################################

## the generate_next_colours function 
## - generates 3 new colours for the next_colours array and moves the colours in the lower 12 spots to the upper 12 spots

generate_next_colours:
addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack (this is the address that takes us back to our main game loop)

la $t0, next_colours                            # load the starting address of the next_colours array into $t0
addi $t1, $zero, 12                             # store the offset (3 colours down) from the starting address in $t1
add $t2, $t0, $t1                               # store the offsetted address in $t2

shift_colours_loop_start:
beq $t1, 60, shift_colours_loop_end     # when the offset reaches 60, we would have shifted all the colours 

lw $t3, 0($t2)                                  # load the colour 3 spaces down in $t3
sw $t3, 0($t0)                                  # store this colour at the current address 

addi $t1, $t1, 4                                # increment the offset
addi $t2, $t2, 4                                # increment the offsetted address
addi $t0, $t0, 4                                # increment the current address
j shift_colours_loop_start

shift_colours_loop_end:

jal get_random_colour                           # load a random colour into $t1
sw $t1, 0($t0)                                  # store that colour in the current address (which would be the third to last space at this point)
jal get_random_colour                           # load a random colour into $t1
sw $t1, 4($t0)                                  # store that colour 1 space down from the current address
jal get_random_colour                           # load a random colour into $t1
sw $t1, 8($t0)                                  # store that colour 2 spaces down from the current address

lw $ra, 0($sp)                                  # pop $ra from the stack (this is the address that takes us back to our main game loop)
addi $sp, $sp, 4                                # move the stack pointer to the top stack element
jr $ra                                          # return to calling program

###############################################################################################################

# the draw_paused_text function
# - draws the word "PAUSED" to the bitmap 

# $a0 = the text colour

draw_paused_text:
add $t0, $zero, $s0                             # load the starting address of the bitmap into $t0
addi $t0, $t0, 648                              # add the offset (x=3, y=5) for the starting point of the letter P to the base address

# draw the letter P
sw $a0, 0($t0)
sw $a0, 4($t0)
sw $a0, 8($t0)
sw $a0, 264($t0)
sw $a0, 128($t0)
sw $a0, 256($t0)
sw $a0, 384($t0)
sw $a0, 512($t0)
sw $a0, 140($t0)
sw $a0, 260($t0)


addi $t0, $t0, 20                               # offsets to the starting point for the letter A

# draw the letter A
sw $a0, 4($t0)
sw $a0, 128($t0)
sw $a0, 256($t0)
sw $a0, 384($t0)
sw $a0, 512($t0)
sw $a0, 8($t0)
sw $a0, 260($t0)
sw $a0, 264($t0)
sw $a0, 268($t0)
sw $a0, 140($t0)
sw $a0, 396($t0)
sw $a0, 524($t0)

addi $t0, $t0, 20                               # offsets to the starting point for the letter U

# draw the letter U
sw $a0, 0($t0)
sw $a0, 128($t0)
sw $a0, 256($t0)
sw $a0, 384($t0)
sw $a0, 516($t0)
sw $a0, 520($t0)
sw $a0, 12($t0)
sw $a0, 140($t0)
sw $a0, 268($t0)
sw $a0, 396($t0)

addi $t0, $t0, 20                               # offsets to the starting point for the letter S

# draw the letter S
sw $a0, 4($t0)
sw $a0, 128($t0)
sw $a0, 512($t0)
sw $a0, 8($t0)
sw $a0, 516($t0)
sw $a0, 260($t0)
sw $a0, 392($t0)

addi $t0, $t0, 16                               # offsets to the starting point for the letter E

# draw the letter E
sw $a0, 0($t0)
sw $a0, 128($t0)
sw $a0, 256($t0)
sw $a0, 384($t0)
sw $a0, 512($t0)
sw $a0, 4($t0)
sw $a0, 8($t0)
sw $a0, 12($t0)
sw $a0, 516($t0)
sw $a0, 520($t0)
sw $a0, 524($t0)
sw $a0, 260($t0)
sw $a0, 264($t0)

addi $t0, $t0, 20                               # offsets to the starting point for the letter D

# draw the letter D
sw $a0, 0($t0)
sw $a0, 128($t0)
sw $a0, 256($t0)
sw $a0, 384($t0)
sw $a0, 512($t0)
sw $a0, 4($t0)
sw $a0, 8($t0)
sw $a0, 140($t0)
sw $a0, 516($t0)
sw $a0, 520($t0)
sw $a0, 268($t0)
sw $a0, 396($t0)

jr $ra

###############################################################################################################

# the respond_to_P function
# - handles the logic when the player presses the "p" key

respond_to_P:
lw $a0, WHITE                               # load the colour white into $a0
jal draw_paused_text                        # draw the text to the screen

addi $t1, $zero, 0                          # store the timer/counter variable in $t1

pause_loop_start:
lw $t0, ADDR_KBRD                           # $t0 = base address for keyboard
lw $t8, 0($t0)                              # Load first word from keyboard
beq $t8, 1, paused_keyboard_input           # If first word 1, key is pressed

j paused_keyboard_input_processed           # no key is pressed so we can skip processing logic

paused_keyboard_input:                      # a key is pressed
lw $a0, 4($t0)                              # Load second word from keyboard, the ascii-encoded value for the key that was pressed

beq $a0, 0x71, respond_to_Q                 # Check if the key q was pressed
beq $a0, 0x70, pause_loop_end               # Check if the key p was pressed

paused_keyboard_input_processed:

# handle the toggling of the text 

addi $t1, $t1, 1                            # increment the counter by 1
bne $t1, 30, skip_erase_text
lw $a0, BLACK                               # load the colour black into $a0
jal draw_paused_text                        # by drawing in black we erase the text from the bitmap

skip_erase_text:
beq $t1, 60, redraw_text
j skip_redraw_text

redraw_text:
lw $a0, WHITE                               # load the colour white into $a0
jal draw_paused_text                        # draw the text to the screen
addi $t1, $zero, 0                          # reset the counter to 0

skip_redraw_text:

# Sleep
li $v0, 32
li $a0, 17
syscall
	
j pause_loop_start

pause_loop_end:
lw $a0, BLACK                               # load the colour black into $a0
jal draw_paused_text                        # by drawing in black we erase the text from the bitmap

j keyboard_input_processed                  # return to the main game loop

###############################################################################################################

# the draw_outline function
# - draws the outline of where the current column would end up if it is dropped

draw_outline:

lw $t0, BLACK                                   # store the colour black in $t0
la $t1, current_column                          # $t1 holds the address of the column struct
lw $t2, 0($t1)                                  # load the x position of the column into $t2
sll $t2, $t2, 2                                 # multiply the x position by 4 to get the horizontal offset
add $t3, $s0, $t2                               # add this horizontal offset to $s0 (base address for bitmap), store the result in $t3
lw $t2, 4($t1)                                  # load the y position of the column into $t2
addi $t2, $t2, 2                                # add 2 to get the y position of the bottom gem
sll $t2, $t2, 7                                 # multiply the y position by 128 to get the vertical offset
add $t3, $t3, $t2                               # add this vertical offset to $t3, $t3 now stores the bitmap address for the third gem in the column

find_drop_point_loop_start:                     # this is the loop that finds the location for the outline
addi $t4, $t3, 128                              # store the address directly below the current address in $t4
lw $t5, 0($t4)                                  # store the colour at this address in $t6
bne $t5, $t0, find_drop_point_loop_end          # if the colour below the gem is not black, the drop point has been found
add $t3, $t4, $zero                             # if the colour below the gem is black, it can be dropped so update the current address to the address directly below

j find_drop_point_loop_start                    # repeat until lowest point has been found
    
find_drop_point_loop_end:

lw $t6, OUTLINE                                 # load the colour for the outline in $t6
sw $t6, 0($t3)                                  # paint the current address (lowest point) 
sw $t6, -128($t3)                               # paint the second lowest point  
sw $t6, -256($t3)                               # paint the third lowest point 

jr $ra                                          # return to the calling program

###############################################################################################################

# the erase_outline function
# - erases the outline of where the current column would end up if it is dropped

erase_outline:

add $t1, $zero, $zero                               # $t1 will store the offset from the starting address
add $t2, $zero, $s0                                 # $t2 stores the starting address for the bitmap
lw $t3, OUTLINE                                     # load the outline colour into $t3
lw $t4, BLACK                                       # load the colour black into $t4

erase_outline_loop_start:
beq $t1, 4096, erase_outline_loop_end               # the entire bitmap has been checked so we can end the loop
lw $t5, 0($t2)                                      # get the colour at the current address in the bitmap 
bne, $t5, $t3, erase_check_next_pixel               # check if the colour at the current address is the outline colour
sw $t4, 0($t2)                                      # if the pixel is the outline colour, paint it black

erase_check_next_pixel:
addi $t1, $t1, 4                                    # increment $t1
addi $t2, $t2, 4                                    # increment the bitmap address

j erase_outline_loop_start                          # repeat until entire bitmap is checked

erase_outline_loop_end:
jr $ra                                              # return to calling program