`include "common.svh"
`include "mycpu/mycpu.svh"

module Decode (
    input common_context_t CommonContext,

    input decode_context_t DecodeContext,
    
    output decode_context_t decodeContext,
    output jmp_pack_t decodeJmp,
    output logic jmp_delayed,

    input execute_context_t executeContext, 
    input memory_context_t memoryContext, 
    input write_context_t WriteContext
);

op_t op;
Decode_Op_Trans Decode_Op_Trans_Inst(.instr(DecodeContext.instr), .op(op));

word_t vs;
Decode_Forward_Reg Decode_Forward_Reg_Inst_s(
    .e(executeContext.write_reg),
    .m(memoryContext.write_reg),
    .w(WriteContext.write_reg),
    .src(DecodeContext.instr[25:21]), 
    .data_src(CommonContext.r[DecodeContext.instr[25:21]]), 
    .vr(vs)
);

word_t vt;
Decode_Forward_Reg Decode_Forward_Reg_Inst_t(
    .e(executeContext.write_reg),
    .m(memoryContext.write_reg),
    .w(WriteContext.write_reg),
    .src(DecodeContext.instr[20:16]), 
    .data_src(CommonContext.r[DecodeContext.instr[20:16]]), 
    .vr(vt)
);

word_t vhi, vlo;
Decode_Forward_HILO Decode_Forward_hilo_Inst(
    .e(executeContext.write_hilo),
    .m(memoryContext.write_hilo),
    .w(WriteContext.write_hilo),
    .data_hi(CommonContext.hi), 
    .data_lo(CommonContext.lo), 
    .vhi(vhi),
    .vlo(vlo)
);

Decode_Select_Jmp Decode_Select_Jmp_Inst(.op(decodeContext.op), .pc_src(decodeContext.pc), .vars(decodeContext.vars), .jmp(decodeJmp), .*);

memory_args_t memory_args;
Decode_Memory Decode_Memory_Inst(.*);

write_reg_t write_reg;
Decode_Write_Reg Decode_Write_Reg_Inst(.cp0(CommonContext.cp0), .rt(DecodeContext.instr[20:16]), .rd(DecodeContext.instr[15:11]), .*);

write_hilo_t write_hilo;
Decode_Write_HILO Decode_Write_HILO_Inst(.*);

always_comb begin
    decodeContext = DecodeContext;
    if (!DecodeContext.exception.valid) begin
        decodeContext.stat = decodeContext.stat;
        decodeContext.op = op;
        
        decodeContext.vars.va = {{27'b0}, DecodeContext.instr[10:6]};
        decodeContext.vars.vi = {{16{DecodeContext.instr[15]}}, DecodeContext.instr[15:0]};
        decodeContext.vars.viu = {{16'b0}, DecodeContext.instr[15:0]};
        decodeContext.vars.vj = {DecodeContext.pc[31:28], DecodeContext.instr[25:0], 2'b0};
        decodeContext.vars.vs = vs;
        decodeContext.vars.vt = vt;
        decodeContext.vars.hi = vhi;
        decodeContext.vars.lo = vlo;
        
        decodeContext.vars.rs = DecodeContext.instr[25:21];
        decodeContext.vars.rt = DecodeContext.instr[20:16];
        decodeContext.vars.rd = DecodeContext.instr[15:11];
        
        decodeContext.memory_args = memory_args;
        decodeContext.write_hilo = write_hilo;
        decodeContext.write_reg = write_reg;

        unique case (decodeContext.op)
            DECODE_ERROR: `THROW(decodeContext.exception, EX_RI, DecodeContext.pc)
            SYSCALL: `THROW(decodeContext.exception, EX_SYS, DecodeContext.pc)
            BREAK: `THROW(decodeContext.exception, EX_BP, DecodeContext.pc)
            default: begin end
        endcase
    end
    else begin
        decodeContext.stat = SD_IDLE;
    end
end

endmodule

