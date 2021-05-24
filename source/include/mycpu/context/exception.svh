`ifndef __EXCEPTION_SVH__
`define __EXCEPTION_SVH__

`include "cp0/cp0.svh"

typedef struct packed {
    logic valid;
    ecode_t code;
    addr_t bad_vaddr;
    // 错误代码所在位置
    addr_t pc_src;
    // currently in delay slot?
    logic delayed;
    // PC of delayed branches，是分支代码所在位置
    addr_t delayed_pc_src;
} exception_args_t;

`define THROW(exception, ecode, pc) \
    begin \
        exception.valid = 1; \
        exception.code = ecode; \
        exception.bad_vaddr = 32'b0; \
        exception.pc_src = pc; \
    end

`define ADDR_ERROR(exception, ecode, vaddr, pc) \
    begin \
        exception.valid = 1; \
        exception.code = ecode; \
        exception.bad_vaddr = vaddr; \
        exception.pc_src = pc; \
    end
`endif
