	.data
fname:		.asciiz		"blank.bmp"
outfile: 	.asciiz 	"result.bmp"
imgInf: 	.word 		512, 512, pImg, 0, 0, 0 # width, height, cX, cY, black (0)
handle: 	.word 		0
fSize:		.word 		0		# 190 bytes
pFile:		.space 		62
pImg:		.space		36000 		# size of the image

radius:		.word 		10		# default radius
center_x: 	.word 		0
center_y: 	.word 		0

ask_radmin:	.word		0
ask_radinc:	.word		16

dpy_width: 	.word 		512
dpy_height: 	.word 		512
dpy_base: 	.word 		62
.eqv	dpy_margin		8

	.text
main:
	# open file
	la $a0, fname		# name of the file
	li $a1, 0		# set 0 to flag (read-only)
	li $a2, 0		# set 0 to mode (ignoring mode)
	li $v0, 13		# value for opening file
	syscall

	# read file
	move $a0, $v0		# move $v0 to $a0	- file descriptor
	sw $a0, handle		# store $a0 to handle
	la $a1, pFile		# load address of pFile to $a1 (after the header) - address of input buffer
	la $a2, 36062		# load address 36062 to $a2 (maximum number of characters to read)
	li $v0, 14		# read from file
	syscall

	# print integer
	move $a0, $v0		# move $v0 to $a0
	sw $a0, fSize		# store word $a0 to fSize
	li $v0,1		# print integer
	syscall

	# close the file
	li $v0, 16		# close file
	syscall

###########################################################################

	# prompt user for ask_radmin value
	la $a0, _S_001
	li $v0, 4
	syscall
	li $v0, 5
	syscall
	sw $v0, ask_radmin

	lw $t0, ask_radmin
	beqz $t0, main_skipinc

	# prompt user for ask_radinc value
	la $a0, _S_002
	li $v0, 4
	syscall
	li $v0, 5
	syscall
	sw $v0, ask_radinc

	main_skipinc:
	lw $t0, ask_radmin


	# compute circle center from image
	lw $s6, dpy_width
	srl $s6, $s6, 1
	sw $s6, center_x

	lw $s5, dpy_height
	srl $s5, $s5, 1
	sw $s5, center_y

	# set radius to min((width / 2) - 16,(height / 2) - 16)
	move $s0, $s6
	blt $s6, $s5, main_gotradius
	move $s0, $s5

	main_gotradius:
	subi $s0, $s0, dpy_margin
	sw $s0, radius

	main_loop:
	jal kdraw
	jal radbump

	main_next:
	sle $s7, $s7, $zero			# shift to white / black
    	bnez    $v0,main_loop

	# open outfile
	la $a0, outfile				# load address of outfile to $a0
	li $a1, 1					# set 1 to flag (write)
	li $a2, 0					# set 0 to mode (ignoring mode)
	li $v0, 13					# value for opening file
	syscall

	# read file
	move $a0, $v0				# move $v0 to $a0
	sw $a0, handle				# store address of handle to $a0
	li $v0, 1					# print value of $a0
	syscall

	# write file
	la $a1, pFile				# load addr of pFile to $a1
	lw $a2, fSize				# load word fSize to $a2
	li $v0, 15					# write to file
	syscall

	# close file
	li $v0, 16
	syscall

	# end program
	li $v0, 10
	syscall

	kdraw:
		subi $sp, $sp, 4
		sw $ra, 0($sp)

		lw $s0, radius 	# X = R
		li $s1, 0	# Y = 0

		# initialize condition xchng = 1 - (2 * r)
		li $s3, 1
		sll $t0, $s0, 1
		sub $s3, $s3, $t0

		li $s4, 1	# ychng = 1
		li $s2, 0	# raderr = 0

	kdraw_loop:
		blt $s0, $s1, kdraw_done # if X ($s0) < Y ($s1), branch (we're done)

		# draw pixels in all 8 octants
		jal draw8

		addi $s1, $s1, 1	# y += 1
		add $s2, $s2, $s4	# raderr += ychg
		addi $s4, $s4, 2	# ychg += 2

		sll $t0, $s2, 1		# get 2 * raderr
		add $t0, $t0, $s3	# get (2 * raderr) + xchng
		blez $s2, kdraw_loop  	# >0? if no, loop

		subi $s0, $s0, 1	# x -= 1
		add $s2, $s2, $s3	# raderr += xchng
		addi $s3, $s3, 2	# xchng += 2
		j kdraw_loop

	kdraw_done:
		lw $ra, 0($sp)
		addi $sp, $sp,4
		jr $ra

	## draw  8 points
	# $s0 -- X coord
	# $s1 -- Y coord

	# $t8 -- center_x
	# $t9 -- center_y

	draw8:
		#lw $s7, color
		beq $s7, 0, drawblack
		drawwhite:
			subi $sp, $sp, 4
			sw $ra, 0($sp)

			# + drawctr $t8, $t9
			lw $t8, center_x
			lw $t9, center_y

			# draw [+x, +y]
			add $a0, $t8, $s0
			add $a1, $t9, $s1
			jal set_pixel

			# draw [+y, +x]
			add $a0, $t8, $s1
			add $a1, $t9, $s0
			jal set_pixel

			# draw [-x, +y]
			sub $a0, $t8, $s0
			add $a1, $t9, $s1
			jal set_pixel

			# draw [-y, +x]
			add $a0, $t8, $s1
			sub $a1, $t9, $s0
			jal set_pixel

			# draw [-x, -y]
			sub $a0, $t8, $s0
			sub $a1, $t9, $s1
			jal set_pixel

			# draw [-y, -x]
			sub $a0, $t8, $s1
			sub $a1, $t9, $s0
			jal set_pixel

			# draw [+x, -y]
			add $a0, $t8, $s0
			sub $a1, $t9, $s1
			jal set_pixel

			# draw [+y,-x]
			sub $a0, $t8, $s1
			add $a1, $t9, $s0
			jal set_pixel

			lw $ra, 0($sp)
			addi $sp, $sp, 4
			jr $ra

		drawblack:
			subi $sp, $sp, 4
			sw $ra, 0($sp)

			# + drawctr $t8, $t9
			lw $t8, center_x
			lw $t9, center_y


			# draw [+x, +y]
			add $a0, $t8, $s0
			add $a1, $t9, $s1
			jal set_pixel_black

			# draw [+y, +x]
			add $a0, $t8, $s1
			add $a1, $t9, $s0
			jal set_pixel_black

			# draw [-x, +y]
			sub $a0, $t8, $s0
			add $a1, $t9, $s1
			jal set_pixel_black

			# draw [-y, +x]
			add $a0, $t8, $s1
			sub $a1, $t9, $s0
			jal set_pixel_black

			# draw [-x, -y]
			sub $a0, $t8, $s0
			sub $a1, $t9, $s1
			jal set_pixel_black

			# draw [-y, -x]
			sub $a0, $t8, $s1
			sub $a1, $t9, $s0
			jal set_pixel_black

			# draw [+x, -y]
			add $a0, $t8, $s0
			sub $a1, $t9, $s1
			jal set_pixel_black

			# draw [+y,-x]
			sub $a0, $t8, $s1
			add $a1, $t9, $s0
			jal set_pixel_black

			lw $ra, 0($sp)
			addi $sp, $sp, 4
			jr $ra


		#####################################################

	#la $a0, pImg
	set_pixel:
		move $t2, $a0
		move $t3, $a1
		mul $t5, $t3, 64
		andi $t6, $t2, 7
		li $t7, 0x80
		srlv $t7, $t7, $t6
		srl $t6, $a0, 3
		add $t5, $t5, $t6
		lb $v0, pImg+0($t5)
		or $t7, $t7, $v0
		sb $t7, pImg+0($t5)
		jr $ra

	set_pixel_black:
		move $t2, $a0
		move $t3, $a1
		mul $t5, $t3, 64
		andi $t6, $t2, 7
		li $t7, 0x80
		srlv $t7, $t7, $t6
		srl $t6, $a0, 3
		add $t5, $t5, $t6
		lb $v0, pImg+0($t5)
		not $t7, $t7
		and $t7, $t7, $v0
		sb $t7, pImg+0($t5)
		jr $ra

	radbump:
		lw $t0, radius			# $t0 = radius
		lw $t1, ask_radinc		# $t1 = radinc (default: 16)
		sub $t0, $t0, $t1		# new radius

		lw $v0, ask_radmin		# do multiple circles ?
		beqz $v0, radbump_store  	# if no, go to radbump_store

		slt $v0, $v0, $t0		# set less than : if $v0 < $t0 then v0 = 1, else 0
						# if radmin < $t0, v0=1
	radbump_store:
		beqz $t0, radbump_safe	# if $t0 = 0
		sw $t0, radius

	radbump_safe:
		jr $ra

###########################################################################

	# open outfile
	la $a0, outfile		# load address of outfile to $a0
	li $a1, 1		# set 1 to flag (write)
	li $a2, 0		# set 0 to mode (ignoring mode)
	li $v0, 13		# value for opening file
	syscall

	# read file
	move $a0, $v0		# move $v0 to $a0
	sw $a0, handle		# store address of handle to $a0
	li $v0, 1		# print value of $a0
	syscall

	# write file
	la $a1, pFile		# load addr of pFile to $a1
	lw $a2, fSize		# load word fSize to $a2
	li $v0, 15		# write to file
	syscall

	# close file
	li $v0, 16		# close file
	syscall

	li $v0, 10		# end program
	syscall

	.data
	_S_001:	.asciiz "minimum radius (0=single) > "
	_S_002: .asciiz "radius decrement > "