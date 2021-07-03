`ifndef __DECODE_SVH__
`define __DECODE_SVH__

`include "common.svh"
`include "exception.svh"

typedef enum i1 {
    SD_IDLE   = 1'h0,
    SD_DECODE = 1'h1
} decode_stat_t;


typedef struct packed {
    logic valid;
    
    word_t pc;
    word_t instr;
    op_t op;
    
    vars_t vars;
    jmp_pack_t jmp;
    memory_args_t memory_args;
    write_reg_t write_reg;
    write_hilo_t write_hilo;
    exception_args_t exception;
} decode_context_t;


`endif
