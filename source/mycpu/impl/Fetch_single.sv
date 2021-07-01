`include "common.svh"
`include "mycpu/mycpu.svh"

module Fetch_single (
    input valid, 
    input addr_t pc,
    input word_t instr,
    input logic Last_instr_is_jmp,
    input logic addr_invalid,
    input logic has_interrupt,
    input decode_context_t Fetch,
    output decode_context_t fetch
);

    op_t op;
    jmp_pack_t jmp;
    memory_args_t memory_args;
    write_reg_t write_reg;
    write_hilo_t write_hilo;
    
    Fetch_op_trans    Fetch_op_trans_inst(.instr(instr), .op(op));
    Fetch_Select_Jmp  Fetch_Select_Jmp_inst(.op(op), .jmp(jmp));
    Fetch_Memory_args Fetch_Memory_args_inst(.op(op), .memory_args(memory_args));
    Fetch_Write_Reg   Fetch_Write_Reg_inst(.op(op), .rt(instr[20:16]),  .rd(instr[15:11]), .write_reg(write_reg));
    Fetch_Write_HILO  Fetch_Write_HILO_inst(.op(op), .write_hilo(write_hilo));

    always_comb begin
        if (valid) begin
            fetch.valid       = valid;
            fetch.pc          = pc;
            fetch.instr       = instr;
            fetch.op          = op;
            fetch.vars        = '0;
            fetch.jmp         = jmp;
            fetch.memory_args = memory_args;
            fetch.write_reg   = write_reg;
            fetch.write_hilo  = write_hilo;
        end
        else begin
            fetch.valid       = Fetch.valid;
            fetch.pc          = Fetch.pc;
            fetch.instr       = Fetch.instr;
            fetch.op          = Fetch.op;
            fetch.vars        = '0;
            fetch.jmp         = Fetch.jmp;
            fetch.memory_args = Fetch.memory_args;
            fetch.write_reg   = Fetch.write_reg;
            fetch.write_hilo  = Fetch.write_hilo;
        end
    end
    
    always_comb begin
        if (valid) begin
            fetch.exception = '0;
            
            if (Last_instr_is_jmp) begin
                fetch.exception.delayed = 1;
            end
            
            if (addr_invalid) begin
                `ADDR_ERROR(fetch.exception, EX_ADEL, pc, pc)
            end
            else if (has_interrupt) begin
                // NOTE: current instruction has completed, therefore new pc will be recorded in EPC in S_EXCEPTION.
                `THROW(fetch.exception, EX_INT, pc);
            end
            else begin
                unique case (op)
                    DECODE_ERROR: `THROW(fetch.exception, EX_RI, pc)
                    SYSCALL: `THROW(fetch.exception, EX_SYS, pc)
                    BREAK: `THROW(fetch.exception, EX_BP, pc)
                    default: begin end
                endcase
            end
        end
        else begin
            fetch.exception = Fetch.exception;
        end
    end

endmodule
