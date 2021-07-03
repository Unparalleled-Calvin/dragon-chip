`ifndef __JMP_SVH__
`define __JMP_SVH__

`include "common.svh"

typedef struct packed {
    i1 valid; // this is a jmp instr.
    i1 en; // condition is met.
    addr_t pc_dst;
} jmp_pack_t;

`endif
