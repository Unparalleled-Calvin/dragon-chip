`ifndef __CP0_SVH__
`define __CP0_SVH__

`include "common.svh"
`include "cp0_cause.svh"
`include "cp0_status.svh"

typedef enum i8 {
    RS_BADVADDR = {5'd8,  3'd0},
    RS_COUNT    = {5'd9,  3'd0},
    RS_COMPARE  = {5'd11, 3'd0},
    RS_STATUS   = {5'd12, 3'd0},
    RS_CAUSE    = {5'd13, 3'd0},
    RS_EPC      = {5'd14, 3'd0},
    RS_ERROREPC = {5'd30, 3'd0}
} regsel_t /* verilator public */;  // register number + select number

typedef struct packed {
    // we sort members descending in ther register number,
    // due to a misbehavior of little endian bit numbering array
    // in Verilator.
    addr_t        BadVAddr; // 8 号寄存器，地址错异常时记录该虚拟地址
    word_t        Count; // 9 号寄存器，是一个计时器，每两个时钟周期加一
                         // 该寄存器是软件可写的，软件写入的优先级高于硬件自增
    word_t        Compare; // 11 号寄存器，和 Count 寄存器比较以产生时钟中断
                           // 当 Compare 寄存器被设置过，且 Compare 和 Count 寄存器值相等时，产生时钟中断信号并保持
                           // 当 Compare 寄存器被软件修改时，清除时钟中断信号
    cp0_status_t  Status; // 12 号寄存器，记录处理器的运行状态
    cp0_cause_t   Cause; // 13 号寄存器，记录最近一次异常的原因
    addr_t        EPC; // 14 号寄存器，用于异常处理结束后的恢复
    addr_t        ErrorEPC;
} cp0_t;


parameter word_t CP0_FULL_MASK = 32'hffffffff;

parameter cp0_t CP0_RESET = '{
    Status : CP0_STATUS_RESET,
    default: '0
};

parameter cp0_t CP0_MASK = '{
    BadVAddr : '0,
    Count    : CP0_FULL_MASK,
    Compare  : CP0_FULL_MASK,
    Status   : CP0_STATUS_MASK,
    Cause    : CP0_CAUSE_MASK,
    EPC      : CP0_FULL_MASK,
    ErrorEPC : CP0_FULL_MASK
};

`endif
