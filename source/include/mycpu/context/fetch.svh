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

`endif
