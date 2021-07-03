`ifndef __TLB_SVH__
`define __TLB_SVH__

`include "common.svh"
`include "../mycommon.svh"

typedef struct packed {
    logic [18:0] vpn2;  // virtual page number
    logic [7:0] asid;   // 资源拥有者标识符
    logic G;            // 映射是否为 global

    // 以下每个属性都有两份，分别对应 vaddr[12] 为 0 或 1 两种情况
    logic [19:0] pfn0, pfn1;  // physical page number
    logic [2:0] C0, C1;       // cache flag，标识 kseg0 段是否经过 cache
    logic V0, V1, D0, D1;     // valid、dirty
} tlb_entry_t;

typedef struct packed {
    tlb_entry_t [31:0] entries;
} tlb_table_t;