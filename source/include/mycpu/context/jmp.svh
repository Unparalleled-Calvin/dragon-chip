`ifndef __JMP_SVH__
`define __JMP_SVH__

`include "common.svh"

typedef enum i2 {
    J_NOP    = 2'b00,
    J_DIR    = 2'b01,
    J_REG    = 2'b10,
    J_REL    = 2'b11
} jmp_t;

typedef struct packed {
    jmp_t stat;
    addr_t pc_src;
    addr_t pc_dst;
} jmp_pack_t;

`endif
