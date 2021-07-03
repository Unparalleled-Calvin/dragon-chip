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
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    MyCore core(.*);

    //IBusToCBus icvt(.*);
    //DBusToCBus dcvt(.*);
    
    ICache icvt(.*);
    
    dbus_req_t  [1:0] mux_dreq;
    dbus_resp_t [1:0] mux_dresp;
    cbus_req_t  [1:0] mux_creq;
    cbus_resp_t [1:0] mux_cresp;
    
    logic d_block;
    
    always_comb begin
        mux_dreq = 0;
        mux_cresp = 0;

        if (dreq.addr[31:29] == 3'b101) begin
            if (!d_block) begin
                mux_dreq[1] = dreq;
                dresp = mux_dresp[1];
                dcreq = mux_creq[1];
                mux_cresp[1] = dcresp;
            end
            else begin
                mux_dreq[0] = '0;
                dresp = mux_dresp[0];
                dcreq = mux_creq[0];
                mux_cresp[0] = dcresp;
            end
        end else begin
            mux_dreq[0] = dreq;
            dresp = mux_dresp[0];
            dcreq = mux_creq[0];
            mux_cresp[0] = dcresp;
        end
    end
    
    DCache dcvt0(
        .dreq(mux_dreq[0]),
        .dresp(mux_dresp[0]),
        .dcreq(mux_creq[0]),
        .dcresp(mux_cresp[0]),
        .block(d_block),
        .*
    );

    DBusToCBus dcvt1(
        .dreq(mux_dreq[1]),
        .dresp(mux_dresp[1]),
        .dcreq(mux_creq[1]),
        .dcresp(mux_cresp[1]),
        .*
    );
    
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
