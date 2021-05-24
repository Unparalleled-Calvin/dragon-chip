`ifndef __EXECUTE_SVH__
`define __EXECUTE_SVH__

`include "common.svh"
`include "exception.svh"

typedef enum i2 {
    SE_IDLE   = 2'h0,
    SE_ALU    = 2'h1,
    SE_MULT    = 2'h2,
    SE_DIV    = 2'h3
} execute_stat_t;

typedef struct packed {
    execute_stat_t stat;
    word_t pc;
    op_t op;
    vars_t vars;
    memory_args_t memory_args;
    write_reg_t write_reg;
    write_hilo_t write_hilo;

    exception_args_t exception;
} execute_context_t;

parameter execute_context_t EXECUTE_CONTEXT_RESET = '0;

`endif
