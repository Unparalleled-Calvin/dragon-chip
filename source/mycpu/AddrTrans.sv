`include "common.svh"
`include "sramx.svh"

typedef logic [31:0] paddr_t;
typedef logic [31:0] vaddr_t;

module AddrTrans(
	output paddr_t paddr, // physical address
	input vaddr_t vaddr // virtual address
);
	assign paddr[27:0] = vaddr[27:0];
	always_comb begin
	    unique case (vaddr[31:28])
	        4'h8: paddr[31:28] = 4'b0; // kseg0
	        4'h9: paddr[31:28] = 4'b1; // kseg0
	        4'ha: paddr[31:28] = 4'b0; // kseg1
	        4'hb: paddr[31:28] = 4'b1; // kseg1
	        default: paddr[31:28] = vaddr[31:28];
	    endcase
	end

endmodule
