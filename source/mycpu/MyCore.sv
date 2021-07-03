`include "common.svh"
`include "mycpu/mycpu.svh"

module MyCore (
    input logic clk, resetn,
    output flex_bus_req_t  ireq,
    input  flex_bus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp,
    input i6 ext_int
);

common_context_t CommonContext, commonContext;

decode_context_t fetch2decode_1, fetch2decode_2;

execute_context_t decode2execute_1, decode2execute_2;

memory_context_t execute2memory_1, execute2memory_2;

write_single_context_t memory2write_1, memory2write_2;

jmp_pack_t decodeJmp_1_fwd, decodeJmp_2_fwd, writeJmp_fwd;

logic decodeContext_MTC0_exist, executeContext_MTC0_exist, memoryContext_MTC0_exist, WriteContext_MTC0_exist;
logic decodeContext_ERET_exist, executeContext_ERET_exist, memoryContext_ERET_exist, WriteContext_ERET_exist;
logic decodeContext_exception_valid, executeContext_exception_valid, memoryContext_exception_valid, WriteContext_exception_valid;

write_reg_t executeContext_write_reg, memoryContext_write_reg, WriteContext_write_reg;
write_hilo_t executeContext_write_hilo, memoryContext_write_hilo, WriteContext_write_hilo;

write_reg_t succeed_write_reg[5:0]; //TODO
write_hilo_t succeed_write_hilo[5:0]; //TODO

logic MTC0_exist, ERET_exist;
assign MTC0_exist = WriteContext_MTC0_exist || memoryContext_MTC0_exist || executeContext_MTC0_exist || decodeContext_MTC0_exist;
assign ERET_exist = WriteContext_ERET_exist || memoryContext_ERET_exist || executeContext_ERET_exist || decodeContext_ERET_exist;

logic Fetch_valid_1, Fetch_valid_2, Fetch_ready;
pipeline_stat_t DecodeStat_1, DecodeStat_2, ExecuteStat_1, ExecuteStat_2, MemoryStat_1, MemoryStat_2, WriteStat;

Fetch Fetch_inst(.succeed_exception_valid(decodeContext_exception_valid || executeContext_exception_valid || 
                                          memoryContext_exception_valid || WriteContext_exception_valid ||
                                          MTC0_exist || ERET_exist), 
                 .CommonContext_cp0(CommonContext.cp0), 
                 .valid_1(Fetch_valid_1), 
                 .valid_2(Fetch_valid_2), 
                 .ready(Fetch_ready),
                 .*);

Decode Decode_inst(.succeed_exception_valid(executeContext_exception_valid || memoryContext_exception_valid || WriteContext_exception_valid), 
                   .jmp_1(decodeJmp_1_fwd), .jmp_2(decodeJmp_2_fwd),
                   .exception_valid(decodeContext_exception_valid),
                   .ERET_exist(decodeContext_ERET_exist), 
                   .MTC0_exist(decodeContext_MTC0_exist),
                   .*);

Execute Execute_inst(.succeed_exception_valid(memoryContext_exception_valid || WriteContext_exception_valid), 
                     .executeContext_write_reg_1(succeed_write_reg[1]),
                     .executeContext_write_hilo_1(succeed_write_hilo[1]),
                     .executeContext_write_reg_2(succeed_write_reg[0]),
                     .executeContext_write_hilo_2(succeed_write_hilo[0]),
                     .*);

Memory Memory_inst(.succeed_exception_valid(WriteContext_exception_valid), 
                   .write_reg_1(succeed_write_reg[3]),
                   .write_hilo_1(succeed_write_hilo[3]),
                   .write_reg_2(succeed_write_reg[2]),
                   .write_hilo_2(succeed_write_hilo[2]),
                   .exception_valid(memoryContext_exception_valid), 
                   .ERET_exist(memoryContext_ERET_exist), 
                   .MTC0_exist(memoryContext_MTC0_exist),
                   .*);

Write Write_inst(.write_reg_1(succeed_write_reg[5]),
                 .write_hilo_1(succeed_write_hilo[5]),
                 .write_reg_2(succeed_write_reg[4]),
                 .write_hilo_2(succeed_write_hilo[4]),
                 .exception_valid(WriteContext_exception_valid), 
                 .ERET_exist(WriteContext_ERET_exist), 
                 .MTC0_exist(WriteContext_MTC0_exist),
                 .*);

always_ff @(posedge clk) begin
    // Common
    if(~resetn) begin
        CommonContext <= COMMON_CONTEXT_RESET;
    end
    else
        CommonContext <= commonContext;
end

endmodule
