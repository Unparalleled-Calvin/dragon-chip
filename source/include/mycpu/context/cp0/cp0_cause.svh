`ifndef __CP0_CAUSE_SVH__
`define __CP0_CAUSE_SVH__

`include "common.svh"
`include "cp0_common.svh"

/**
 * CP0 Cause register
 */

// NOTE: we actually implement TI bit, although it should return
// zero on read in Release 1 implementations.
typedef struct packed {
    i1      BD;       // 31: in branch delay slot?
    i1      TI;       // 30: timer interrupt, in Release 2
    i2      CE;       // [29:28]: coprocessor unit number
    i1      DC;       // 27: optional
    i1      PCI;      // 26: performance counter interrupt, in Release 2
    i2      ASE1;     // [25:24]: reserved
    i1      IV;       // 23: interrupt vector
    i1      WP;       // 22: optional
    i1      FDCI;     // 21: optional
    i5      RES1;     // [20:16]: reserved
    i8      IP;       // [15:8]: interrupt requests
    i1      RES2;     // 7: reserved
    ecode_t ExcCode;  // [6:2]: exception code
    i2      RES3;     // [1:0]: reserved
} cp0_cause_t;

parameter cp0_cause_t CP0_CAUSE_MASK = '{
    IV : 1'b1,
    IP : 8'h03,

    default: '0
};

`endif
