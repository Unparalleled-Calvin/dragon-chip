`ifndef __MYCOMMON_SVH__
`define __MYCOMMON_SVH__

`include "common.svh"

typedef `BITS(10) i10;
typedef `BITS(20) i20;
typedef `BITS(22) i22;

typedef struct packed {
    logic  valid;  // in request?
    addr_t addr;   // target address
} flex_bus_req_t;

typedef struct packed {
    logic  addr_ok;  // is the address accepted by cache?
    logic  data_ok;  // is the field "data" valid?
    word_t data_1;     // the data read from cache
    logic valid_2;
    word_t data_2;     // the data read from cache
} flex_bus_resp_t;

`endif
