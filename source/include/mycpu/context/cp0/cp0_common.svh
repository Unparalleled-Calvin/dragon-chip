`ifndef __CP0_COMMON_SVH__
`define __CP0_COMMON_SVH__

`include "common.svh"

/**
 * exception code
 */

typedef enum i5 {
    EX_INT      = 0,   // Interrupt
    EX_MOD      = 1,   // TLB modification exception
    EX_TLBL     = 2,   // TLB exception (load or instruction fetch)
    EX_TLBS     = 3,   // TLB exception (store)
    EX_ADEL     = 4,   // Address error exception (load or instruction fetch)
    EX_ADES     = 5,   // Address error exception (store)
    EX_IBE      = 6,   // Bus error exception (instruction fetch)
    EX_DBE      = 7,   // Bus error exception (data reference: load or store)
    EX_SYS      = 8,   // Syscall exception
    EX_BP       = 9,   // Breakpoint exception
    EX_RI       = 10,  // Reserved instruction exception
    EX_CPU      = 11,  // Coprocessor Unusable exception
    EX_OV       = 12,  // Arithmetic Overflow exception
    EX_TR       = 13,  // Trap exception
    EX_FPE      = 15,  // Floating point exception
    EX_C2E      = 18,  // Reserved for precise Coprocessor 2 exceptions
    EX_TLBRI    = 19,  // TLB Read-Inhibit exception
    EX_TLBXI    = 20,  // TLB Execution-Inhibit exception
    EX_MDMX     = 22,  // MDMX Unusable Exception (MDMX ASE)
    EX_WATCH    = 23,  // Reference to WatchHi/WatchLo address
    EX_MCHECK   = 24,  // Machine check
    EX_THREAD   = 25,  // Thread Allocation, Deallocation, or Scheduling Exceptions (MIPS® MT ASE)
    EX_DSPDIS   = 26,  // DSP ASE State Disabled exception (MIPS® DSP ASE)
    EX_CACHEERR = 30   // Cache error
} ecode_t /* verilator public */;

`endif
