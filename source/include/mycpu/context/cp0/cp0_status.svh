`ifndef __CP0_STATUS_SVH__
`define __CP0_STATUS_SVH__

`include "common.svh"

/**
 * CP0 Status register
 */

typedef struct packed {
    i4 CU;    // [31:28]: access to coprocessors
    i1 RP;    // 27: optional
    i1 FR;    // 26: floating point registers, optional
    i1 RE;    // 25: optional
    i1 MX;    // 24: optional
    i1 RES1;  // 23: reserved
    i1 BEV;   // 22: location of exception vectors
    i1 TS;    // 21: optional
    i1 SR;    // 20: optional
    i1 NMI;   // 19: optional
    i1 ASE;   // 18: optional
    i2 RES2;  // [17:16]: reserved
    i8 IM;    // [15:8]: interrupt masks IM7~IM0
    i3 RES3;  // [7:5]: reserved
    i2 KSU;   // [4:3]: supervisor mode, optional
    i1 ERL;   // 2: error level
    i1 EXL;   // 1: exception level
    i1 IE;    // 0: interrupt enable
} cp0_status_t;

parameter cp0_status_t CP0_STATUS_MASK = '{
    CU  : 4'b0001,  // CU0 is writable, although it's ignored.
    BEV : 1'b1,
    IM  : 8'hff,
    ERL : 1'b1,
    EXL : 1'b1,
    IE  : 1'b1,
    default: '0
};

parameter cp0_status_t CP0_STATUS_RESET = '{
    CU  : 4'b0001,
    BEV : 1'b1,
    ERL : 1'b1,
    default: '0
};

`endif
