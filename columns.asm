################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       TODO
# - Unit height in pixels:      TODO
# - Display width in pixels:    TODO
# - Display height in pixels:   TODO
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

##############################################################################
# Mutable Data
##############################################################################

current_column: .space 20 # the coloumn will be represented with 5 pieces of information: x position, y position, colour1, colour2 and colour3

can_move_left: .word 0x0 # keeps track of whether the current column can move left
can_move_right: .word 0x0 # keeps track of whether the current column can move right
has_landed: .word 0x0 # keeps track of whether the current column has either reached the floor or landed on a past column

bitmap_copy: .space 4096 # stores a mirror of the bitmap in memory which is used to mark which gems are to be deleted

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

## Draw the Grid ##
jal draw_grid                   

## Initialize a column at the top middle of the playing field ##
jal initialize_player_column

## Draw the column ##
jal draw_current_column

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

keyboard_input_processed:           # finished checking if a key was pressed and responded accordingly

# 2a. Check for collisions
jal check_left                      # Check if the column can move left
jal check_right                     # Check if the column can move right
jal check_landed                    # Check if the column has reached the floor or 

# 2b. Respond to collisions

## Check if column has landed ##
lw $t0, has_landed                  # Store whether the players column has reached the floor or landed on a past column
bne $t0, 1, draw_screen             # If column has not reached the floor or landed on a past column, skip this part

## Check for matches
jal find_all_horizontal_matches
jal find_all_vertical_matches
jal find_all_diagonal_matches

## Remove any matching gems
jal remove_marked_locations

jal initialize_player_column        # Initialize a new column 
jal draw_current_column             # Draw this new column to the screen

# 3. Draw the screen
draw_screen:



# 4. Sleep
li $v0, 32
li $a0, 17
syscall
	

# 5. Go back to Step 1
j game_loop


##############################################################################
# The Helper Functions
##############################################################################

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

## The get_random_colour function
## - stores a random selection of red, green, blue, orange, yellow or purple into $t1

get_random_colour:

# configure the program to generate a random number between 0 and 5 and store it in $a0
li $v0, 42
li $a0, 0
li $a1, 6
syscall

# Put the corresponding colour in $t0 based on the number generated
# 0 -> red, 1 -> green, 2 -> blue, 3 -> orange, 4 -> yellow, 5 -> purple

check_red: bne $a0, 0, check_green          # if $a0 != 0 then check the case for green
           lw $t1, RED                      # else set  $t0 to RED
           j colour_selected                # jump to end
           
check_green: bne $a0, 1, check_blue         # if $a0 != 1 then check the case for blue
             lw $t1, GREEN                  # else set  $t0 to GREEN
             j colour_selected              # jump to end
             
check_blue: bne $a0, 2, check_orange        # if $a0 != 2 then check the case for orange
            lw $t1, BLUE                    # else set  $t0 to BLUE
            j colour_selected               # jump to end
            
check_orange: bne $a0, 3, check_yellow      # if $a0 != 3 then check the case for yellow
              lw $t1, ORANGE                # else set  $t0 to ORANGE
              j colour_selected             # jump to end
              
check_yellow: bne $a0, 4, check_purple      # if $a0 != 4 then check the case for purple
              lw $t1, YELLOW                # else set  $t0 to YELLOW
              j colour_selected             # jump to end
              
check_purple: lw $t1, PURPLE                # program only reaches here if and only if $a0 == 5
                                            # so set $t0 to PURPLE
colour_selected:    
jr $ra                                      # return to the calling program


## The initialize_player_column function
## - initializes a new column at the top middle of the playing area with three random colours

initialize_player_column:

# first we set the x,y position of the column to roughly the top center of playing field

la $t2, current_column          # $t2 holds the address of the current column struct
lw $t3, LEFT_BOUNDARY           # $t3 holds the x position of the left boundary
addi $t3, $t3, 4                # add 4 to $t3 so it now holds an x position roughly in the middle of the playing field
sw $t3, 0($t2)                  # store this value of $t3 as the x position of the column
lw $t3, TOP_BOUNDARY            # $t3 holds the y position of the ceiling
addi $t3, $t3, 1                # add 1 to $t3 so it now holds an y position of the top of the playing field
sw $t3, 4($t2)                  # store this value of $t3 as the y position of the column

# second we need to give the column three random colours

addi $sp, $sp, -4               # move the stack pointer to an empty location
sw $ra, 0($sp)                  # push $ra onto the stack (this is the address that takes us back to our main game loop)

jal get_random_colour           # this puts a random colour in $t1
sw $t1, 8($t2)                  # store this as the first colour of the column
jal get_random_colour           # this puts a random colour in $t1
sw $t1, 12($t2)                 # store this as the second colour of the column
jal get_random_colour           # this puts a random colour in $t1
sw $t1, 16($t2)                 # store this as the third colour of the column

lw $ra, 0($sp)                  # pop $ra from the stack (this is the address that takes us back to our main game loop)
addi $sp, $sp, 4                # move the stack pointer to the top stack element
jr $ra                          # return to the game loop


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


## The code executed when the "q" key is pressed
## - exits the program gracefully
respond_to_Q:
li $v0, 10                          # Quit gracefully
syscall

game_over:
    li $v0, 10      # exit program
    syscall

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
la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
addi $t2, $t2 -1                            # decrement the x position by 1 (move to the left)
sw $t2, 0($t1)                              # update the x position of the column

jal draw_current_column                     # Draw the column in its updated location to the bitmap
j keyboard_input_processed                  # return to game loop

###############################################################################################################

## The code executed when the "s" key is pressed
## - move the column down

respond_to_S:
lw $t3 has_landed                           # $t3 either holds a 1 or 0 which checks if the column has reached the floor or landed on a past column
beq $t3, 1, keyboard_input_processed        # if $t3 == 1, column has reached the floor or landed on a past column so return to game loop

jal erase_current_column                    # erase the column from the bitmap since it is going to be moved
la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 4($t1)                              # $t2 holds the y position of the column
addi $t2, $t2 1                             # increment the y position by 1 (move down)
sw $t2, 4($t1)                              # update the y position of the column

jal draw_current_column                     # Draw the column in its updated location to the bitmap
j keyboard_input_processed                  # return to game loop

###############################################################################################################

## The code executed when the "d" key is pressed
## - move the column to the right

respond_to_D:

lw $t3, can_move_right                      # $t3 either holds a 1 or 0 which checks if the column can move right
beq $t3, $zero, keyboard_input_processed    # if $t3 == 1, column is blocked so do not try to move it right just return to game loop

jal erase_current_column                    # erase the column from the bitmap since it is going to be moved
la $t1, current_column                      # $t1 holds the address of the column struct
lw $t2, 0($t1)                              # $t2 holds the x position of the column
addi $t2, $t2 1                             # increment the x position by 1 (move to the right)
sw $t2, 0($t1)                              # update the x position of the column

jal draw_current_column                     # Draw the column in its updated location to the bitmap
j keyboard_input_processed                  # return to game loop

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
bne $t2, $t3, below_blocked                 # if the colour at that location is not black then below the column is blocked 
sw $zero, has_landed                        # set has_landed to 0 to indicate that the column has not reached the floor or landed on a past column
jr $ra                                      # return to game loop

below_blocked:                              # in this case below the column is blocked
    addi $t3, $zero, 1                      # store the value of 1 in $t3
    sw $t3, has_landed                      # set has_landed to 1 to indicate that the column has landed

    # check if the column has landed at the very top position
    la  $t1, current_column                 # load address of the column struct
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

add $t0, $zero, $zero                       # $t0 is used to store the current number of consecutive gems
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

##  The find_diagonal_down_right_match function
##  - Looks for a diagonal (down-right) match of three or more for a given colour starting from a given cell
#
# $a0 = the starting row to check
# $a1 = the starting column to check
# $a2 = the colour we are checking for 

find_diagonal_down_right_match:

add $t0, $zero, $zero                       # $t0 is used to store the current number of consecutive gems
add $t6, $zero, $zero                       # $t6 stores the ending row for a match, if this is changed from zero a match has been found
add $t1, $zero, $a0                         # $t1 is the loop variable for the row, initialised to the starting row
add $t2, $zero, $a1                         # $t2 is the loop variable for the column, initialised to the starting column

# we need to convert the row and column to an address in the bitmap
add $t3, $zero, $t2                         # $t3 holds a copy of the column
sll $t3, $t3, 2                             # multiply this x-value by 4 to get the horizontal offset
addu $t3, $s0, $t3                           # add this horizontal offset to $s0 (bitmap address) and store in $t3
add $t7, $zero, $t1                         # $t7 holds a copy of the row
sll $t7, $t7, 7                             # multiply the y-value (row) by 128 to get the vertical offset
addu $t3, $t3, $t7                           # add this vertical offset to $t3

find_diagonal_down_right_match_loop_start:
bgt $t1, 27, find_diagonal_down_right_match_loop_end   # if the row is > 27 we have left the playing grid
bgt $t2, 10, find_diagonal_down_right_match_loop_end   # if the column is > 10 we have left the playing grid

lw $t7, 0($t3)                              # get the colour at the address specified by $t3 and store in $t7

bne $t7, $a2, diag_dr_not_colour            # check if the colour at the address is the colour we are looking for

beq $t0, $zero, diag_dr_first_occurrence    # if this is the first time encountering this colour, record the starting cell

j diag_dr_not_first_occurrence              # otherwise, go straight to incrementing the count

diag_dr_first_occurrence:
add $t4, $zero, $t1                         # store the starting row of the potential match in $t4
add $t5, $zero, $t2                         # store the starting column of the potential match in $t5

diag_dr_not_first_occurrence:
addi $t0, $t0, 1                            # increment the count of consecutive gems

j diag_dr_increment_loop_variables          # skip the logic for the case where the colour does not match

diag_dr_not_colour:
blt $t0, 3, diag_dr_no_match_yet            # if the count is less than 3 then we do not have a match
add $t6, $zero, $t1                         # store the row one past the last match in $t6
addi $t6, $t6, -1                           # subtract 1 to get the row of the last gem in the match
j find_diagonal_down_right_match_loop_end   # a match has been found so we can end the loop

diag_dr_no_match_yet:
add $t0, $zero, $zero                       # reset the count to 0 if we did not find a match

diag_dr_increment_loop_variables:
addi $t1, $t1, 1                            # increment the row to move down one cell
addi $t2, $t2, 1                            # increment the column to move right one cell
addi $t3, $t3, 132                          # increment the address by 132 bytes (128 for row, 4 for column)
j find_diagonal_down_right_match_loop_start # repeat the process on the next cell

find_diagonal_down_right_match_loop_end:

# Note that the loop could have finished on a match, so we need to check for this

blt $t0, 3, diag_dr_no_ending_match         # if the number of consecutive gems ($t0) < 3, then there is no match
add $t6, $zero, $t1                         # store the row one past the last match in $t6
addi $t6, $t6, -1                           # subtract 1 to get the row of the last gem in the match

diag_dr_no_ending_match:

beq $t6, $zero, find_diagonal_down_right_match_end     # if $t6 is still zero, no match was found so we can return

addi $sp, $sp, -4                           # move the stack pointer to an empty location
sw $ra, 0($sp)                              # push $ra onto the stack

add $a0, $zero, $t4                         # load the starting row of the match into $a0
add $a1, $zero, $t5                         # load the starting column of the match into $a1
add $a2, $zero, $t6                         # load the ending row of the match into $a2
jal diagonal_down_right_mark_for_removal    # mark this match for removal in the bitmap copy

lw $ra, 0($sp)                              # pop $ra from the stack
addi $sp, $sp, 4                            # move the stack pointer to the top stack element

find_diagonal_down_right_match_end:
jr $ra                                      # return to the calling program

###############################################################################################################

##  The diagonal_down_right_mark_for_removal function
##  - Given a down-right diagonal match, mark the locations in the bitmap copy
#
# $a0 = the starting row of the match
# $a1 = the starting column of the match
# $a2 = the ending row of the match

diagonal_down_right_mark_for_removal:

add $t1, $zero, $a0                         # store a copy of the starting row in $t1
sll $t1, $t1, 7                             # multiply this by 128 to get the vertical offset
add $t2, $s1, $t1                           # add this vertical offset to $s1 (bitmap copy address) and store in $t2
sll $t3, $a1, 2                             # multiply the starting column by 4 to get the horizontal offset
add $t2, $t2, $t3                           # add this horizontal offset to $t2
lw  $t4, RED                                # load the colour red into $t4, this will be used to mark the locations

sub $t5, $a2, $a0                           # subtract the starting row from the ending row to get the difference
addi $t5, $t5, 1                            # add 1 so $t5 stores the number of gems in the match

diagonal_down_right_mark_loop_start:
beq $t5, $zero, diagonal_down_right_mark_loop_end   # when $t5 reaches 0 we have marked all the gems in the match
sw $t4, 0($t2)                              # mark the address in the bitmap copy
addi $t2, $t2, 132                          # move the address one cell down-right (128 for row, 4 for column)
addi $t5, $t5, -1                           # decrement the loop counter
j diagonal_down_right_mark_loop_start

diagonal_down_right_mark_loop_end:
jr $ra                                      # return to the calling program

###############################################################################################################

##  The find_diagonal_down_left_match function
##  - Looks for a diagonal (down-left) match of three or more for a given colour starting from a given cell
#
# $a0 = the starting row to check
# $a1 = the starting column to check
# $a2 = the colour we are checking for 

find_diagonal_down_left_match:

add $t0, $zero, $zero                       # $t0 is used to store the current number of consecutive gems
add $t6, $zero, $zero                       # $t6 stores the ending row for a match, if this is changed from zero a match has been found
add $t1, $zero, $a0                         # $t1 is the loop variable for the row, initialised to the starting row
add $t2, $zero, $a1                         # $t2 is the loop variable for the column, initialised to the starting column

# we need to convert the row and column to an address in the bitmap
add $t3, $zero, $t2                         # $t3 holds a copy of the column
sll $t3, $t3, 2                             # multiply this x-value by 4 to get the horizontal offset
addu $t3, $s0, $t3                           # add this horizontal offset to $s0 (bitmap address) and store in $t3
add $t7, $zero, $t1                         # $t7 holds a copy of the row
sll $t7, $t7, 7                             # multiply the y-value (row) by 128 to get the vertical offset
addu $t3, $t3, $t7                           # add this vertical offset to $t3

find_diagonal_down_left_match_loop_start:
bgt $t1, 27, find_diagonal_down_left_match_loop_end   # if the row is > 27 we have left the playing grid
blt $t2, 5, find_diagonal_down_left_match_loop_end    # if the column is < 5 we have left the playing grid

lw $t7, 0($t3)                              # get the colour at the address specified by $t3 and store in $t7

bne $t7, $a2, diag_dl_not_colour            # check if the colour at the address is the colour we are looking for

beq $t0, $zero, diag_dl_first_occurrence    # if this is the first time encountering this colour, record the starting cell

j diag_dl_not_first_occurrence              # otherwise, go straight to incrementing the count

diag_dl_first_occurrence:
add $t4, $zero, $t1                         # store the starting row of the potential match in $t4
add $t5, $zero, $t2                         # store the starting column of the potential match in $t5

diag_dl_not_first_occurrence:
addi $t0, $t0, 1                            # increment the count of consecutive gems

j diag_dl_increment_loop_variables          # skip the logic for the case where the colour does not match

diag_dl_not_colour:
blt $t0, 3, diag_dl_no_match_yet            # if the count is less than 3 then we do not have a match
add $t6, $zero, $t1                         # store the row one past the last match in $t6
addi $t6, $t6, -1                           # subtract 1 to get the row of the last gem in the match
j find_diagonal_down_left_match_loop_end    # a match has been found so we can end the loop

diag_dl_no_match_yet:
add $t0, $zero, $zero                       # reset the count to 0 if we did not find a match

diag_dl_increment_loop_variables:
addi $t1, $t1, 1                            # increment the row to move down one cell
addi $t2, $t2, -1                           # decrement the column to move left one cell
addi $t3, $t3, 124                          # increment the address by 124 bytes (128 for row, -4 for column)
j find_diagonal_down_left_match_loop_start  # repeat the process on the next cell

find_diagonal_down_left_match_loop_end:

# Note that the loop could have finished on a match, so we need to check for this

blt $t0, 3, diag_dl_no_ending_match         # if the number of consecutive gems ($t0) < 3, then there is no match
add $t6, $zero, $t1                         # store the row one past the last match in $t6
addi $t6, $t6, -1                           # subtract 1 to get the row of the last gem in the match

diag_dl_no_ending_match:

beq $t6, $zero, find_diagonal_down_left_match_end      # if $t6 is still zero, no match was found so we can return

addi $sp, $sp, -4                           # move the stack pointer to an empty location
sw $ra, 0($sp)                              # push $ra onto the stack

add $a0, $zero, $t4                         # load the starting row of the match into $a0
add $a1, $zero, $t5                         # load the starting column of the match into $a1
add $a2, $zero, $t6                         # load the ending row of the match into $a2
jal diagonal_down_left_mark_for_removal     # mark this match for removal in the bitmap copy

lw $ra, 0($sp)                              # pop $ra from the stack
addi $sp, $sp, 4                            # move the stack pointer to the top stack element

find_diagonal_down_left_match_end:
jr $ra                                      # return to the calling program

###############################################################################################################

##  The diagonal_down_left_mark_for_removal function
##  - Given a down-left diagonal match, mark the locations in the bitmap copy
#
# $a0 = the starting row of the match
# $a1 = the starting column of the match
# $a2 = the ending row of the match

diagonal_down_left_mark_for_removal:

add $t1, $zero, $a0                         # store a copy of the starting row in $t1
sll $t1, $t1, 7                             # multiply this by 128 to get the vertical offset
add $t2, $s1, $t1                           # add this vertical offset to $s1 (bitmap copy address) and store in $t2
sll $t3, $a1, 2                             # multiply the starting column by 4 to get the horizontal offset
add $t2, $t2, $t3                           # add this horizontal offset to $t2
lw  $t4, RED                                # load the colour red into $t4, this will be used to mark the locations

sub $t5, $a2, $a0                           # subtract the starting row from the ending row to get the difference
addi $t5, $t5, 1                            # add 1 so $t5 stores the number of gems in the match

diagonal_down_left_mark_loop_start:
beq $t5, $zero, diagonal_down_left_mark_loop_end   # when $t5 reaches 0 we have marked all the gems in the match
sw $t4, 0($t2)                              # mark the address in the bitmap copy
addi $t2, $t2, 124                          # move the address one cell down-left (128 for row, -4 for column)
addi $t5, $t5, -1                           # decrement the loop counter
j diagonal_down_left_mark_loop_start

diagonal_down_left_mark_loop_end:
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
##  - looks for all the diagonal (down-right and down-left) matches of three or more in the playing grid

find_all_diagonal_matches:
addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $ra, 0($sp)                                  # push $ra onto the stack

add $t1, $zero, $zero                           # $t1 stores the offset from the starting address of the colour array

diagonal_loop_colours_start:
beq $t1, 24, diagonal_loop_colours_end          # when the offset reaches 24 we have checked all the colours
add $t0, $s2, $t1                               # add the offset to the starting address
lw $t2, 0($t0)                                  # load the colour at this address into $t2

addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $t1, 0($sp)                                  # push $t1 onto the stack

###############################################
# check all down-right diagonals for this colour
###############################################
addi $t3, $zero, 15                             # the first row to check is row 15

diagonal_dr_rows_start:
beq $t3, 26, diagonal_dr_rows_end               # when $t3 reaches 26, we would have looped through rows 15..25
addi $t4, $zero, 5                              # the first column to check is column 5

addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $t3, 0($sp)                                  # push $t3 onto the stack

    diagonal_dr_cols_start:
    beq $t4, 9, diagonal_dr_cols_end            # when $t4 reaches 9, we would have looped through columns 5..8
    add $a0, $zero, $t3                         # load the row into $a0
    add $a1, $zero, $t4                         # load the column into $a1
    add $a2, $zero, $t2                         # load the colour into $a2
    
    addi $sp, $sp, -8                           # move the stack pointer to empty locations
    sw $t4, 0($sp)                              # push $t4 onto the stack
    sw $t2, 4($sp)                              # push $t2 onto the stack
    
    jal find_diagonal_down_right_match          # look for a down-right diagonal match from this cell
    
    lw $t2, 4($sp)                              # pop $t2 from the stack
    lw $t4, 0($sp)                              # pop $t4 from the stack
    addi $sp, $sp, 8                            # move the stack pointer to the top stack element
    
    addi $t4, $t4, 1                            # increment the column by 1
    j diagonal_dr_cols_start                    # repeat for the next column
    
    diagonal_dr_cols_end:

lw $t3, 0($sp)                                  # pop $t3 from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

addi $t3, $t3, 1                                # increment the row by 1
j diagonal_dr_rows_start                        # repeat for the next row

diagonal_dr_rows_end:

###############################################
# check all down-left diagonals for this colour
###############################################
addi $t3, $zero, 15                             # the first row to check is row 15

diagonal_dl_rows_start:
beq $t3, 26, diagonal_dl_rows_end               # when $t3 reaches 26, we would have looped through rows 15..25
addi $t4, $zero, 7                              # the first column to check is column 7

addi $sp, $sp, -4                               # move the stack pointer to an empty location
sw $t3, 0($sp)                                  # push $t3 onto the stack

    diagonal_dl_cols_start:
    beq $t4, 11, diagonal_dl_cols_end           # when $t4 reaches 11, we would have looped through columns 7..10
    add $a0, $zero, $t3                         # load the row into $a0
    add $a1, $zero, $t4                         # load the column into $a1
    add $a2, $zero, $t2                         # load the colour into $a2
    
    addi $sp, $sp, -8                           # move the stack pointer to empty locations
    sw $t4, 0($sp)                              # push $t4 onto the stack
    sw $t2, 4($sp)                              # push $t2 onto the stack
    
    jal find_diagonal_down_left_match           # look for a down-left diagonal match from this cell
    
    lw $t2, 4($sp)                              # pop $t2 from the stack
    lw $t4, 0($sp)                              # pop $t4 from the stack
    addi $sp, $sp, 8                            # move the stack pointer to the top stack element
    
    addi $t4, $t4, 1                            # increment the column by 1
    j diagonal_dl_cols_start                    # repeat for the next column
    
    diagonal_dl_cols_end:

lw $t3, 0($sp)                                  # pop $t3 from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

addi $t3, $t3, 1                                # increment the row by 1
j diagonal_dl_rows_start                        # repeat for the next row

diagonal_dl_rows_end:

lw $t1, 0($sp)                                  # pop $t1 from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

addi $t1, $t1, 4                                # move on to the next colour
j diagonal_loop_colours_start

diagonal_loop_colours_end:

lw $ra, 0($sp)                                  # pop $ra from the stack
addi $sp, $sp, 4                                # move the stack pointer to the top stack element

jr $ra                                          # return to game loop

###############################################################################################################