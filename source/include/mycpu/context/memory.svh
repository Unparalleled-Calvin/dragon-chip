`ifndef __MEMORY_SVH__
`define __MEMORY_SVH__

`include "common.svh"
//`include "exception.svh"

typedef enum i3 {
    SM_IDLE      = 3'h0,
    SM_LOAD      = 3'h1,
    SM_LOADWAIT  = 3'h2,
    SM_STORE     = 3'h3,
    SM_STOREWAIT = 3'h4
} memory_stat_t;

typedef struct packed {
    memory_stat_t stat;
    word_t pc;
    op_t op;
    memory_args_t memory_args;
    write_reg_t write_reg;
    write_hilo_t write_hilo;
    
    exception_args_t exception;
} memory_context_t;

parameter memory_context_t MEMORY_CONTEXT_RESET = '0;

`endif
