    addi t0, zero, 0     # loop variable          0
    addi t1, zero, 100   # loop upper bound       4
    addi t2, zero, 0     # sum                    8
loop:
    addi t0, t0, 1                               #c
    add t2, t0, t2                               #10
    beq t0, t1, next # i == 100?                  14 
    beq zero, zero, loop                         #18    

next:   
    # store result
    lui t0, 0x80000  # base ram address           1c
    sw t2, 0x100(t0)                             #20

    lui t0, 0x10000  # serial address             24
.TESTW1:
    lb t1, 5(t0)                                 #28 
    andi t1, t1, 0x20                            #2c
    beq t1, zero, .TESTW1                        #30
    # do not write when serial is in used

    addi a0, zero, 'd'                           #34
    sb a0, 0(t0)                                 #38 

.TESTW2:
    lb t1, 5(t0)                                 #3c
    andi t1, t1, 0x20                            #40
    beq t1, zero, .TESTW2                        #44 

    addi a0, zero, 'o'                           #48
    sb a0, 0(t0)                                 #4c

.TESTW3:
    lb t1, 5(t0)                                 #50
    andi t1, t1, 0x20
    beq t1, zero, .TESTW3

    addi a0, zero, 'n'
    sb a0, 0(t0)

.TESTW4:
    lb t1, 5(t0)
    andi t1, t1, 0x20
    beq t1, zero, .TESTW4

    addi a0, zero, 'e'
    sb a0, 0(t0)

.TESTW5:
    lb t1, 5(t0)
    andi t1, t1, 0x20
    beq t1, zero, .TESTW5

    addi a0, zero, '!'
    sb a0, 0(t0)

end:
    beq zero, zero, end 
    # loop forever, let pc under control