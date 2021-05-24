`ifndef __WRITE_SVH__
`define __WRITE_SVH__

`include "common.svh"
`include "context_common.svh"
`include "exception.svh"

typedef struct packed {
    word_t pc;
    op_t op;
    write_reg_t write_reg;
    write_hilo_t write_hilo;
    
    exception_args_t exception;
} write_context_t;

parameter write_context_t WRITE_CONTEXT_RESET = '0;

`endif
