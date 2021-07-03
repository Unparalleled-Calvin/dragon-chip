`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode (
    input logic clk, resetn,
    input common_context_t CommonContext,

    input decode_context_t fetch2decode_1, fetch2decode_2,

    input write_reg_t succeed_write_reg[5:0], 
    input write_hilo_t succeed_write_hilo[5:0], 
    
    output jmp_pack_t jmp_1, jmp_2,
    output execute_context_t decode2execute_1, decode2execute_2,
    
    input pipeline_stat_t ExecuteStat_1, ExecuteStat_2,
    output pipeline_stat_t DecodeStat_1, DecodeStat_2, 
    input logic succeed_exception_valid,
    output logic exception_valid, ERET_exist, MTC0_exist
);
    
    logic resetn_1;
    
    logic write_reg_valid_1, write_reg_valid_2;
    creg_addr_t write_reg_dst_1, rs_1, rt_1;
    creg_addr_t write_reg_dst_2, rs_2, rt_2;
    
    logic modify_hi_1, modify_lo_1, need_hi_1, need_lo_1;
    logic modify_hi_2, modify_lo_2, need_hi_2, need_lo_2;
    
    logic MTC0_exist_1, MTC0_exist_2;
    logic ERET_exist_1, ERET_exist_2;
    logic exception_valid_1, exception_valid_2;
    logic load_use_hazard_1, load_use_hazard_2, load_use_hazard_self;
    
    logic valid_1, valid_2;
    
    assign exception_valid = exception_valid_1 || exception_valid_2;
    assign ERET_exist = ERET_exist_1 || ERET_exist_2;
    assign MTC0_exist = MTC0_exist_1 || MTC0_exist_2; 
    
    Decode_single Decode_single_inst_1 (
        .resetn(resetn && resetn_1),
        .fetch2decode(fetch2decode_1),
        .jmp(jmp_1),
        .write_reg_valid(write_reg_valid_1),
        .write_reg_dst(write_reg_dst_1),
        .rs(rs_1), 
        .rt(rt_1),
        .modify_hi(modify_hi_1),
        .modify_lo(modify_lo_1),
        .need_hi(need_hi_1),
        .need_lo(need_lo_1),
        
        .exception_valid(exception_valid_1),
        .MTC0_exist(MTC0_exist_1), 
        .ERET_exist(ERET_exist_1),
        .load_use_hazard(load_use_hazard_1),
        
        .DecodeStat(DecodeStat_1),
        .decode2execute(decode2execute_1),
        
        .valid(valid_1),
        .*
    );
    
    Decode_single Decode_single_inst_2 (
        .fetch2decode(fetch2decode_2),
        .jmp(jmp_2),
        .write_reg_valid(write_reg_valid_2),
        .write_reg_dst(write_reg_dst_2),
        .rs(rs_2), 
        .rt(rt_2),
        .modify_hi(modify_hi_2),
        .modify_lo(modify_lo_2),
        .need_hi(need_hi_2),
        .need_lo(need_lo_2),
        
        .exception_valid(exception_valid_2),
        .MTC0_exist(MTC0_exist_2), 
        .ERET_exist(ERET_exist_2),
        .load_use_hazard(load_use_hazard_2),
        
        .DecodeStat(DecodeStat_2),
        .decode2execute(decode2execute_2),
        
        .valid(valid_2),
        .*
    );
    
    assign load_use_hazard_self = valid_1 && valid_2 && (
                                      (write_reg_valid_1 && 
                                         (write_reg_dst_1 == rs_2 || 
                                          write_reg_dst_1 == rt_2)
                                       ) || 
                                      (modify_hi_1 && need_hi_2) ||
                                      (modify_lo_1 && need_lo_2)
                                  );
    
    always_comb begin
        DecodeStat_1 = 2'b11;
        DecodeStat_2 = 2'b11;
        resetn_1 = 1;
        if (load_use_hazard_1) begin
            DecodeStat_1.valid = 0;
            DecodeStat_1.ready = 0;
            DecodeStat_2.valid = 0;
            DecodeStat_2.ready = 0;
        end
        
        if (ExecuteStat_1.ready == 0 || ExecuteStat_2.ready == 0) begin
            DecodeStat_1.ready = 0;
            DecodeStat_2.ready = 0;
        end
        
        if (load_use_hazard_2 || load_use_hazard_self) begin
            resetn_1 = !(ExecuteStat_1.ready && DecodeStat_1.valid);
            DecodeStat_2.valid = 0;
            DecodeStat_2.ready = 0;
        end
    end
    
endmodule

