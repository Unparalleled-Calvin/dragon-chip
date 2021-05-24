`ifndef __FETCH_SVH__
`define __FETCH_SVH__

`include "common.svh"
`include "exception.svh"
`include "context_common.svh"


typedef enum i2 {
    SF_IDLE  = 2'h0,
    SF_FETCH = 2'h1,
    SF_WAIT  = 2'h2
} fetch_stat_t;

typedef struct packed {
    fetch_stat_t stat;
    addr_t pc;
    addr_t next_pc;
    word_t instr;
    jmp_pack_t decodeJmp, writeJmp;
    
    exception_args_t exception;
} fetch_context_t;

parameter fetch_context_t FETCH_CONTEXT_RESET = '{
    stat    : SF_IDLE,
    pc      : 32'hbfbffffc,
    next_pc : 32'hbfc00000,
    default : '0
};

`endif
