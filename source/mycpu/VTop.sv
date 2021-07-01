`include "access.svh"
`include "common.svh"
`include "mycpu/mycpu.svh"

module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input i6 ext_int
);
    `include "bus_decl"

    flex_bus_req_t  ireq;
    flex_bus_resp_t iresp;
    dbus_req_t [1:0] dreq;
    dbus_resp_t [1:0] dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    MyCore core(.dreq_1(dreq[0]), .dreq_2(dreq[1]), .dresp_1(dresp[0]), .dresp_2(dresp[1]), .*);

    //IBusToCBus icvt(.*);
    //DBusToCBus dcvt(.*);
    
    ICache icvt(.*);

    DCache dcvt0(.*);
    
    cbus_req_t  oreq_v;
    
    MyArbiter mux(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq(oreq_v),
        .oresp(oresp),
        .*
    );

    
    assign oreq.valid = oreq_v.valid;
    assign oreq.is_write = oreq_v.is_write;
    assign oreq.size = oreq_v.size;
    AddrTrans addrtrans_o(.paddr(oreq.addr), .vaddr(oreq_v.addr));
    assign oreq.strobe = oreq_v.strobe;
    assign oreq.data = oreq_v.data;
    assign oreq.len = oreq_v.len;
    
    `UNUSED_OK({ext_int});
endmodule
