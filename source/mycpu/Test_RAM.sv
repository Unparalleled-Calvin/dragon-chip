`include "common.svh"

module Test_RAM #(
`ifdef VERILATOR
    parameter `STRING BACKEND = "behavioral",
`else
    parameter `STRING BACKEND = "xilinx_xpm",
`endif

    parameter int NUM_BYTES = 64,  // 16, 32 or 64

    localparam int BYTE_WIDTH = 8,
    localparam int WORD_WIDTH = 32,
    localparam bit BYTE_WRITE = 1,

    localparam int NUM_WORDS  = NUM_BYTES * BYTE_WIDTH / WORD_WIDTH,
    localparam int ADDR_WIDTH = $clog2(NUM_WORDS),  // 2, 3 or 4
    localparam int LANE_WIDTH = BYTE_WRITE ? BYTE_WIDTH : WORD_WIDTH,
    localparam int NUM_LANES  = WORD_WIDTH / LANE_WIDTH,
    localparam int NUM_BITS   = NUM_BYTES * BYTE_WIDTH,

    // FIXME: Verilator 4.028 does not allow parameter type's name overrides outer types.
    localparam type raddr_t   = logic  [ADDR_WIDTH - 1:0],
    localparam type rstrobe_t = logic  [NUM_LANES  - 1:0],
    localparam type rword_t   = logic  [WORD_WIDTH - 1:0],
    localparam type rlane_t   = logic  [LANE_WIDTH - 1:0],
    localparam type rbundle_t = rlane_t [NUM_LANES  - 1:0],
    localparam type rview_t   = union packed {
        rword_t   word;
        rbundle_t lanes;
    }
) (
    input logic clk, en,
    input  raddr_t   addr_1,
    input  rstrobe_t strobe,
    input  rview_t   wdata,
    input  raddr_t   addr_2,
    output rword_t   rdata,
    output rword_t   rdata_2
);
    /* verilator tracing_off */

    `ASSERT(BACKEND == "behavioral" || BACKEND == "xilinx_xpm");
    `ASSERTS(NUM_BYTES == 16 || NUM_BYTES == 32 || NUM_BYTES == 64,
        "The size of LUTRAM must be 16, 32 or 64 bytes.");


if (BACKEND == "behavioral") begin: behavioral

    `ASSERTS(NUM_BYTES == 16 || NUM_BYTES == 32 || NUM_BYTES == 64,
        "The size of LUTRAM must be 16, 32 or 64 bytes.");
    
    rview_t [NUM_WORDS - 1:0] mem;
    
    assign rdata = mem[addr_1];
    assign rdata_2 = mem[addr_2];

    always_ff @(posedge clk)
    if (en) begin
        for (int i = 0; i < NUM_WORDS; i++)
        for (int j = 0; j < NUM_LANES; j++) begin
            if (addr_1 == raddr_t'(i) && strobe[j])
                mem[i].lanes[j] <= wdata.lanes[j];
        end
    end

end else begin: xilinx_xpm

    `ifndef VERILATOR

        xpm_memory_dpdistram #(
            .ADDR_WIDTH_A(ADDR_WIDTH),
            .ADDR_WIDTH_B(ADDR_WIDTH),
            .BYTE_WRITE_WIDTH_A(LANE_WIDTH),
            .MEMORY_SIZE(NUM_BITS),
            .READ_DATA_WIDTH_A(WORD_WIDTH),
            .READ_DATA_WIDTH_B(WORD_WIDTH),
            .READ_LATENCY_A(0),
            .READ_LATENCY_B(0),
            .SIM_ASSERT_CHK(1),
            .USE_MEM_INIT(0),
            .WRITE_DATA_WIDTH_A(WORD_WIDTH)
        ) xpm_memory_dpdistram_inst (
            .addra(addr_1),
            .addrb(addr_2),
            .clka(clk), 
            .clkb(clk), 
            .dina(wdata),
            .douta(rdata),
            .doutb(rdata_2),
            .ena(en), 
            .enb(en),
            .regcea(1),
            .regceb(1),
            .rsta(0),
            .rstb(0),
            .wea(strobe)
        );
        // End of xpm_memory_dpdistram_inst instantiation
        
    `else
        `UNUSED_OK({clk, addr_1, addr_2, strobe, wdata, rdata});
    `endif
end
endmodule
