`ifndef __CONTEXT_SVH__
`define __CONTEXT_SVH__

`include "common.svh"
`include "cp0/cp0.svh"
`include "exception.svh"
`include "jmp.svh"
`include "fetch.svh"
`include "decode.svh"
`include "execute.svh"
`include "memory.svh"
`include "write.svh"

typedef struct packed {
    logic resetn, valid, ready;
} pipeline_stat_t;

typedef struct packed {
    word_t[31:0] r;
    cp0_t cp0;
    word_t hi, lo;
} common_context_t;

parameter common_context_t COMMON_CONTEXT_RESET = '{
    r          : {32{32'b0}},
    cp0        : CP0_RESET,
    hi         : 32'b0,
    lo         : 32'b0
};


`endif
