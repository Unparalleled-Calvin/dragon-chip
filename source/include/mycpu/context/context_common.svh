`ifndef __CONTEXT_COMMON_SVH__
`define __CONTEXT_COMMON_SVH__

`include "common.svh"
`include "../mycommon.svh"

typedef struct packed {
    word_t va, vi, viu, vj;
    word_t vs, vt, hi, lo;
    creg_addr_t rs, rt, rd;
} vars_t;

typedef enum i1 {
    UNSIGNED    = 1'b0,
    SIGNED      = 1'b1
} signed_t;

typedef enum i2 {
    // where should be modified at after the D stage
    SRC_NOP         = 2'b00,
    SRC_ALU         = 2'b01,
    SRC_MEM         = 2'b10
} src_t;

typedef struct packed {
    i1 valid;
    word_t addr;
    i1 write;
    signed_t sig;
    msize_t msize;
    word_t data;
} memory_args_t;

typedef struct packed {
    i1 valid;
    src_t src;
    word_t value;
    creg_addr_t dst;
} write_reg_t;

typedef struct packed {
    i1 valid_hi, valid_lo;
    word_t hi, lo;
} write_hilo_t;

`endif
