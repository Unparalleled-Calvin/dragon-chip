`include "common.svh"
`include "mycpu/mycpu.svh"

module tlb(
    input logic clk,
    input logic resetn,
    output tlb_table_t tlb_table
);
    tlb_table_t tlb_table_nxt;

    always_comb begin
        tlb_table_nxt = tlb_table;
    end

    always_ff @( posedge clk ) begin
        tlb_table <= resetn ? tlb_table_nxt : '0;
    end
endmodule

module tlb_lut (
    input tlb_table_t tlb_table,  // global in hardware
    input word_t vaddr,
    input logic [7:0] asid,
    output logic success,
    output word_t paddr
);
    logic [TLB_ENTRIES-1:0] hit_mask;
    tlb_addr_t hit_addr;

    for (genvar i=0; i<TLB_ENTRIES; i++) begin
        assign hit_mask[i] = (tlb_table[i].vpn2 == vaddr[31:13]) &&
                             (tlb_table[i].asid == asid || tlb_table[i].G);
                                /* 当前进程的表项 */          /* 全局表项 */
    end

    always_comb begin
        success = '0;
        hit_addr = '0;
        for (int i = TLB_ENTRIES - 1; i >= 0; i--) begin
            if (hit_mask[i]) begin
                hit_addr = i;
                success = 1'b1;
                break;
            end
        end
    end

    assign paddr = {
        vaddr[12] ? tlb_table[hit_addr].pfn1 : tlb_table[hit_addr].pfn0,
        vaddr[11:0]
    };
endmodule