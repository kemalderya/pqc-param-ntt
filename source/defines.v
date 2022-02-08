`timescale 1ns / 1ps

// CU states
`define CU_IDLE       3'b000

`define CU_NTT1P_OP   3'b001
`define CU_NTT1P_WAIT 3'b010
`define CU_NTT1P_LAST 3'b011

`define CU_INTT1P_OP   3'b111
`define CU_INTT1P_LAST 3'b101

// top module states
`define OP_IDLE       4'b0000
`define OP_READ_PSET  4'b0001
`define OP_READ_W     4'b0010
`define OP_READ_DATA0 4'b0011
`define OP_NTT        4'b0100
`define OP_SEND_DATA0 4'b0101
`define OP_INTT       4'b0111
`define OP_POST       4'b1000
`define OP_COEFMUL    4'b1011
`define OP_COEFMUL2   4'b1100
`define OP_COEFMUL1   4'b1101

// some parameters
`define PE            32
`define PE_DEPTH      ($clog2(`PE))

`define DATA_SIZE       1024 >> `PE_DEPTH
`define DATA_SIZE_TW    1024 >> (`PE_DEPTH >> 1)
`define BRAM_DEPTH      ($clog2(1024 >> `PE_DEPTH))
`define TW_DEPTH        ($clog2(1024 >> (`PE_DEPTH >> 1)))
`define MAX             9'd511

`define RING_SIZE       256
`define RING_DEPTH      ($clog2(`RING_SIZE))

