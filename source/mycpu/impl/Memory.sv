`include "common.svh"
`include "mycpu/mycpu.svh"

module Memory (
    input logic clk, resetn,
    input memory_context_t execute2memory_1, execute2memory_2,

    output dbus_req_t  dreq,
    input dbus_resp_t  dresp,
    output write_single_context_t memory2write_1, memory2write_2,
    
    output write_reg_t write_reg_1, write_reg_2, 
    output write_hilo_t write_hilo_1, write_hilo_2, 
    input pipeline_stat_t WriteStat,
    output pipeline_stat_t MemoryStat_1, MemoryStat_2, 
    input logic succeed_exception_valid,
    output logic exception_valid, ERET_exist, MTC0_exist
);
    
    dbus_req_t  dreq_1, dreq_2;
    dbus_resp_t  dresp_1, dresp_2;
    
    logic exception_valid_1, exception_valid_2;
    logic ERET_exist_1, ERET_exist_2;
    logic MTC0_exist_1, MTC0_exist_2;
    logic done_1, done_2, done_doned_1, done_doned_2, error_1, error_2;
    
    assign exception_valid = exception_valid_1 || exception_valid_2;
    assign ERET_exist = ERET_exist_1 || ERET_exist_2;
    assign MTC0_exist = MTC0_exist_1 || MTC0_exist_2; 

    Memory_single Memory_single_inst_1(
        .execute2memory(execute2memory_1),
        .dreq(dreq_1),
        .dresp(dresp_1),
        .memory2write(memory2write_1),
        .write_reg(write_reg_1),
        .write_hilo(write_hilo_1),
        .MemoryStat(MemoryStat_1),
        .succeed_exception_valid(succeed_exception_valid),
        .exception_valid(exception_valid_1), 
        .ERET_exist(ERET_exist_1), 
        .MTC0_exist(MTC0_exist_1),
        .done(done_1),
        .done_doned(done_doned_1),
        .error(error_1),
        .*
    );
    
    Memory_single Memory_single_inst_2(
        .execute2memory(execute2memory_2),
        .dreq(dreq_2),
        .dresp(dresp_2),
        .memory2write(memory2write_2),
        .write_reg(write_reg_2),
        .write_hilo(write_hilo_2),
        .MemoryStat(MemoryStat_2),
        .succeed_exception_valid(succeed_exception_valid || error_1),
        .exception_valid(exception_valid_2), 
        .ERET_exist(ERET_exist_2), 
        .MTC0_exist(MTC0_exist_2),
        .done(done_2),
        .done_doned(done_doned_2),
        .error(error_2),
        .*
    );
    
    always_comb begin
        dresp_1 = '0;
        dresp_2 = '0;
        if (!done_doned_1) begin
            dreq = dreq_1;
            dresp_1 = dresp;
        end
        else begin
            dreq = dreq_2;
            dresp_2 = dresp;
        end
    end
    
    always_comb begin
        MemoryStat_1 = 2'b11;
        MemoryStat_2 = 2'b11;
        if (!done_1 || !done_2) begin
            MemoryStat_1.valid = 0;
            MemoryStat_1.ready = 0;
            MemoryStat_2.valid = 0;
            MemoryStat_2.ready = 0;
        end
        
        if (WriteStat.ready == 0) begin
            MemoryStat_1.ready = 0;
            MemoryStat_2.ready = 0;
        end
    end
    
endmodule
