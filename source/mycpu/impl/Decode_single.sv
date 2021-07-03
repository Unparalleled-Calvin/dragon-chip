`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode_single (
    input logic clk, resetn,
    input common_context_t CommonContext,

    input decode_context_t fetch2decode,

    input write_reg_t succeed_write_reg[5:0],
    input write_hilo_t succeed_write_hilo[5:0],
    
    output jmp_pack_t jmp,
    
    output logic write_reg_valid,
    output creg_addr_t write_reg_dst, rs, rt,
    
    output logic modify_hi, modify_lo, need_hi, need_lo,
    
    input logic succeed_exception_valid, 
    output logic exception_valid, MTC0_exist, ERET_exist, load_use_hazard,
    
    input pipeline_stat_t DecodeStat,
    output execute_context_t decode2execute,
    output logic valid
);
    decode_stat_t Stat, stat;
    
    logic Valid;
    
    word_t Pc, pc;
    word_t Instr, instr;
    op_t Op, op;
    
    vars_t Vars, vars;
    jmp_pack_t Jmp;
    memory_args_t Memory_args, memory_args;
    write_reg_t Write_reg, write_reg;
    write_hilo_t Write_hilo, write_hilo;
    exception_args_t Exception, exception;
    
    
    assign write_reg_valid = write_reg.valid;
    assign write_reg_dst = write_reg.dst;
    assign rs = vars.rs;
    assign rt = vars.rt;
    
    assign exception_valid = exception.valid;
    assign MTC0_exist = op == MTC0;
    assign ERET_exist = op == ERET;
    
    assign load_use_hazard = (succeed_write_reg[0].valid && succeed_write_reg[0].src == SRC_MEM && succeed_write_reg[0].dst != 5'b0 && 
                              (vars.rs == succeed_write_reg[0].dst || vars.rt == succeed_write_reg[0].dst)) ||
                             (succeed_write_reg[1].valid && succeed_write_reg[1].src == SRC_MEM && succeed_write_reg[1].dst != 5'b0 && 
                              (vars.rs == succeed_write_reg[1].dst || vars.rt == succeed_write_reg[1].dst));
    
    assign modify_hi = write_hilo.valid_hi;
    assign modify_lo = write_hilo.valid_lo;
    assign need_hi   = Op == MFHI;
    assign need_lo   = Op == MFLO;
    
    
    always_comb begin
        stat = Stat;
    end
    
    always_comb begin
        if (succeed_exception_valid)
            valid = 0;
        else
            valid = Valid;
    end
    
    
    Decode_Forward_Reg Decode_Forward_Reg_Inst_s(
        .write_reg(succeed_write_reg),
        .src(Instr[25:21]), 
        .data_src(CommonContext.r[Instr[25:21]]), 
        .vr(vars.vs)
    );

    Decode_Forward_Reg Decode_Forward_Reg_Inst_t(
        .write_reg(succeed_write_reg),
        .src(Instr[20:16]), 
        .data_src(CommonContext.r[Instr[20:16]]), 
        .vr(vars.vt)
    );

    Decode_Forward_HILO Decode_Forward_hilo_Inst(
        .write_hilo(succeed_write_hilo),
        .data_hi(CommonContext.hi), 
        .data_lo(CommonContext.lo), 
        .vhi(vars.hi),
        .vlo(vars.lo)
    );
    
    
    always_comb begin
        pc    = Pc;
        instr = Instr;
        op    = Op;
    end

    always_comb begin
        vars.va = {{27'b0}, Instr[10:6]};
        vars.vi = {{16{Instr[15]}}, Instr[15:0]};
        vars.viu = {{16'b0}, Instr[15:0]};
        vars.vj = {Pc[31:28], Instr[25:0], 2'b0};
        vars.rs = Instr[25:21];
        vars.rt = Instr[20:16];
        vars.rd = Instr[15:11];
    end
    
    
    Decode_Write_Reg Decode_Write_Reg_Inst(.op(Op), .cp0(CommonContext.cp0), 
                                           .vt(vars.vt), .vhi(vars.hi), .vlo(vars.lo), .rd(Instr[15:11]), 
                                           .Write_reg(Write_reg), .write_reg(write_reg)
                                           );
    
    Decode_Write_HILO Decode_Write_HILO_Inst(.op(Op), .vs(vars.vs),
                                             .Write_hilo(Write_hilo), .write_hilo(write_hilo)
                                             );
    
    Decode_Memory_args Decode_Memory_args_Inst(.op(Op), .vt(vars.vt),
                                               .Memory_args(Memory_args), .memory_args(memory_args)
                                               );
    
    always_comb begin
        exception = Exception;
        if (!Exception.valid) begin
            unique case (Op)
                DECODE_ERROR: `THROW(exception, EX_RI, Pc)
                SYSCALL: `THROW(exception, EX_SYS, Pc)
                BREAK: `THROW(exception, EX_BP, Pc)
                default: begin end
            endcase
        end
    end


    Decode_Select_Jmp Decode_Select_Jmp_Inst(.op(Op), .pc_src(Pc),
                                             .vs(vars.vs), .vt(vars.vt), .vi(vars.vi), .vj(vars.vj),
                                             .Jmp(Jmp), .jmp(jmp)
                                             );
    
    always_ff @(posedge clk) begin
        if(~resetn) begin
            Stat          <= SD_IDLE;
            {Valid, Pc, Instr, Op, Vars, Jmp, Memory_args, Write_reg, Write_hilo, Exception} <= '0;
        end
        else if (DecodeStat.ready == 0) begin
            Stat          <= stat;
            {Valid, Pc, Instr, Op, Vars, Jmp, Memory_args, Write_reg, Write_hilo, Exception}
             <= {valid, pc, instr, op, vars, jmp, memory_args, write_reg, write_hilo, exception};
        end
        else begin
            Stat          <= SD_DECODE;
            {Valid, Pc, Instr, Op, Vars, Jmp, Memory_args, Write_reg, Write_hilo, Exception}
             <= fetch2decode;
        end
    end

    always_comb begin
        decode2execute = EXECUTE_CONTEXT_RESET;
        if (DecodeStat.valid == 1 && valid) begin
            if (op == MULT || op == MULTU)
                decode2execute.stat = SE_MULT;
            else if (op == DIV || op == DIVU)
                decode2execute.stat = SE_DIV;
            else
                decode2execute.stat = SE_ALU;
            decode2execute.pc = pc;
            decode2execute.op = op;
            decode2execute.vars = vars;
            decode2execute.memory_args = memory_args;
            decode2execute.write_reg = write_reg;
            decode2execute.write_hilo = write_hilo;
            decode2execute.exception = exception;
        end
    end

endmodule

