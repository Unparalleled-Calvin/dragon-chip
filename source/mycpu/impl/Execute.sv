`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute (
    input logic clk, resetn,
    input execute_context_t decode2execute_1, decode2execute_2, 
    
    output memory_context_t execute2memory_1, execute2memory_2, 
    
    input pipeline_stat_t MemoryStat_1, MemoryStat_2, 
    output pipeline_stat_t ExecuteStat_1, ExecuteStat_2, 
    
    output write_reg_t executeContext_write_reg_1, executeContext_write_reg_2, 
    output write_hilo_t executeContext_write_hilo_1, executeContext_write_hilo_2, 
    
    input logic succeed_exception_valid,
    output logic executeContext_exception_valid, executeContext_ERET_exist, executeContext_MTC0_exist
);
    
    logic executeContext_exception_valid_1, executeContext_exception_valid_2;
    logic executeContext_ERET_exist_1, executeContext_ERET_exist_2;
    logic executeContext_MTC0_exist_1, executeContext_MTC0_exist_2;
    logic valid_1, valid_2;
    
    assign executeContext_exception_valid = executeContext_exception_valid_1 || executeContext_exception_valid_2;
    assign executeContext_ERET_exist = executeContext_ERET_exist_1 || executeContext_ERET_exist_2;
    assign executeContext_MTC0_exist = executeContext_MTC0_exist_1 || executeContext_MTC0_exist_2; 
    
    Execute_single Execute_single_inst_1(.decode2execute(decode2execute_1), 
                                         .execute2memory(execute2memory_1),
                                         .ExecuteStat(ExecuteStat_1),
                                         .executeContext_write_reg(executeContext_write_reg_1),
                                         .executeContext_write_hilo(executeContext_write_hilo_1),
                                         .executeContext_exception_valid(executeContext_exception_valid_1),
                                         .executeContext_ERET_exist(executeContext_ERET_exist_1),
                                         .executeContext_MTC0_exist(executeContext_MTC0_exist_1),
                                         .valid(valid_1),
                                         .*);
    
    Execute_single Execute_single_inst_2(.decode2execute(decode2execute_2), 
                                         .execute2memory(execute2memory_2),
                                         .ExecuteStat(ExecuteStat_2),
                                         .executeContext_write_reg(executeContext_write_reg_2),
                                         .executeContext_write_hilo(executeContext_write_hilo_2),
                                         .executeContext_exception_valid(executeContext_exception_valid_2),
                                         .executeContext_ERET_exist(executeContext_ERET_exist_2),
                                         .executeContext_MTC0_exist(executeContext_MTC0_exist_2),
                                         .valid(valid_2),
                                         .*);
    
    always_comb begin
        ExecuteStat_1 = 2'b11;
        ExecuteStat_2 = 2'b11;
        if (!valid_1 || !valid_2) begin
            ExecuteStat_1.valid = 0;
            ExecuteStat_1.ready = 0;
            ExecuteStat_2.valid = 0;
            ExecuteStat_2.ready = 0;
        end
        
        if (MemoryStat_1.ready == 0 || MemoryStat_2.ready == 0) begin
            ExecuteStat_1.ready = 0;
            ExecuteStat_2.ready = 0;
        end
    end

endmodule

