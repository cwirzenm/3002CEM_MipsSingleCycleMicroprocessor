main:	addi $2, $0, 5		# initialise $2 = 5	0	20020005
	addi $3, $0, 12		# initialise $3 = 12	4	2003000c
	addi $7, $3, -9		# initialise $7 = 3	8	2067fff7
	or   $4, $7, $2		# $8 <= 3 | 5 = 7	c	00e22025
	and  $5, $3, $4		# $5 <= 12 & 7 = 4	10	00642824
	add  $5, $5, $4		# $5 <= 4 + 7 = 11	14	00a42820
	beq  $5, $7, fail	# shouldn't branch	18	10a70014
	slt  $4, $3, $4		# $8 <= 12 < 7 = 0	1c	0064202a
	beq  $4, $0, around	# should branch		20	10800001
	addi $5, $0, 0		# shouldn't happen	24	20050000
around:	slt  $4, $7, $2 	# $8 <= 3 < 5 = 1	28	00e2202a
	add  $7, $4, $5		# $7 <= 1 + 11 = 12	2c	00853820
	sub  $7, $7, $2		# $7 <= 12 - 5 = 7	30	00e23822
	sw   $7, 68($3)		# [68+12] = 7		34	ac670044
	lw   $2, 80($0)		# $2 <= [80] = 7	38	8c020050
	srl  $2, $2, 1		# $2 <= 7 >> 1 = 3	3c	00021042
	addi $8, $0, -3		# initialise $8 = -3	40	2008fffd
	bgtz $8, fail		# shouldn't branch	44	1d000009
	andi $8, $8, 5		# $8 <= -3 & 5 = 5	48	31080005
	bgtz $8, load		# should branch		4c	1d000001
	addi $2, $0, 1		# shouldn't happen	50	20020001
load:	lh   $8, 77($2)		# $8 <= [77+3] = 7	54	8448004d
	lbu  $4, 80($0)		# $4 <= [80] = 7	58	90040050
	xori $4, $4, 119	# $4 <= 7 ^ 119 = 112	5c	38840077
	j    jump		# should jump		60	0810001a
	addi $8, $0, 1		# shouldn't happen	64	20080001
jump: 	jr   $4			# should jump		68	00800008
fail:	addi $8, $0, 1		# shouldn't happen	6c	20080001
end:    sw   $8, 84($0) 	# [84] = 7		70	ac080054
