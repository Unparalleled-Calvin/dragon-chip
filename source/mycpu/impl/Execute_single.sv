`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute_single (
    input logic clk, resetn,
    input execute_context_t decode2execute,
    
    output memory_context_t execute2memory,
    
    input pipeline_stat_t ExecuteStat,
    output write_reg_t executeContext_write_reg,
    output write_hilo_t executeContext_write_hilo,
    input logic succeed_exception_valid,
    output logic executeContext_exception_valid, executeContext_ERET_exist, executeContext_MTC0_exist,
    output logic valid
);
    execute_stat_t Stat, stat;
    word_t Pc;
    op_t Op;
    vars_t Vars;
    memory_args_t Memory_args, memory_args;
    write_reg_t Write_reg, write_reg;
    write_hilo_t Write_hilo, write_hilo;

    logic Drop, drop;
    
    exception_args_t Exception, exception;
    
    assign executeContext_exception_valid = exception.valid;
    assign executeContext_ERET_exist = Op == ERET;
    assign executeContext_MTC0_exist = Op == MTC0;
    
    assign executeContext_write_reg = write_reg;
    assign executeContext_write_hilo = write_hilo;
    assign valid = stat == SE_IDLE;
    
    i32 result, vs, vt, vi, viu, va;
    i33 result33, vs33, vt33, vi33;
    logic exception_ov;
    
    i32 mult_a, mult_b;
    logic mult_valid, div_valid;
    i64 mult_c, div_c;
    word_t hi, lo;
    
    assign vs = Vars.vs;
    assign vt = Vars.vt;
    assign vi = Vars.vi;
    assign viu = Vars.viu;
    assign va = Vars.va;
    assign vs33 = {Vars.vs[31], Vars.vs};
    assign vt33 = {Vars.vt[31], Vars.vt};
    assign vi33 = {Vars.vi[31], Vars.vi};
    
    always_comb begin
        unique case (Op)
            MULTU, DIVU:  begin mult_a = vs; mult_b = vt; end
            MULT, DIV, MUL: begin
                if (vs[31] == 1'b0) mult_a = vs; // a>=0
                else mult_a = -$signed(vs);
                if (vt[31] == 1'b0) mult_b = vt; // b>=0
                else mult_b = -$signed(vt);
            end
            default: begin mult_a = 32'b0; mult_b = 32'b0; end
        endcase
    end
    
    Execute_ALU Execute_ALU_inst(.*);
    
    Execute_MULT Execute_MULT_Inst(.valid(Stat == SE_MULT), .done(mult_valid), 
                                   .a(mult_a), .b(mult_b), .c(mult_c), .*);
    
    Execute_DIV Execute_DIV_Inst(.valid(Stat == SE_DIV), .done(div_valid), 
                                 .a(mult_a), .b(mult_b), .c(div_c), .*);

    Execute_HILO Execute_HILO_Inst(.op(Op), .a(vs), .b(vt), .*);

    always_comb begin
        if (succeed_exception_valid)
            drop = 1;
        else
            drop = Drop;
    end
    
    always_comb begin
        stat = Stat;
        memory_args = Memory_args;
        write_reg = Write_reg;
        write_hilo = Write_hilo;
        
        if (!Exception.valid) begin
            unique if (Stat == SE_IDLE) begin
                //pass
            end
            else if (Stat == SE_ALU) begin
                stat = SE_IDLE;
                if (Write_reg.src == SRC_ALU)
                    write_reg.value = result;
                if (Memory_args.valid)
                    memory_args.addr = result;
            end
            else if (Stat == SE_MULT) begin
                if (mult_valid) begin
                    stat = SE_IDLE;
                    // {hi, lo} = a * b;
                    if (Op == MUL) begin
                        write_reg.value = lo;
                    end
                    else begin
                        write_hilo.hi = hi;
                        write_hilo.lo = lo;
                    end
                end
            end
            else if (Stat == SE_DIV) begin
                if (div_valid) begin
                    stat = SE_IDLE;
                    // {hi, lo} = {a % b, a / b}
                    write_hilo.hi = hi;
                    write_hilo.lo = lo;
                end
            end
        end
        else begin
            stat = SE_IDLE;
        end
    end
    
    always_comb begin
        exception = Exception;
        if (exception_ov)
            `THROW(exception, EX_OV, Pc);
    end

    always_comb begin
        execute2memory = MEMORY_CONTEXT_RESET;
        if (ExecuteStat.valid == 1 && drop == 0) begin
            execute2memory.pc = Pc;
            execute2memory.op = Op;
            if (memory_args.valid == 1 && memory_args.write == 0)
            execute2memory.stat = SM_LOAD;
            else if (memory_args.valid == 1 && memory_args.write == 1)
            execute2memory.stat = SM_STORE;
            else
            execute2memory.stat = SM_IDLE;
            execute2memory.memory_args = memory_args;
            execute2memory.write_reg = write_reg;
            execute2memory.write_hilo = write_hilo;
            execute2memory.exception = exception;
        end
    end

    always_ff @(posedge clk) begin
        // Execute
        if(~resetn)
            {Stat, Pc, Op, Vars, Memory_args, Write_reg, Write_hilo, Drop, Exception} <= '0;
        else if (ExecuteStat.ready == 0) begin
            {Stat, Pc, Op, Vars, Memory_args, Write_reg, Write_hilo, Drop, Exception}
             <= {stat, Pc, Op, Vars, memory_args, write_reg, write_hilo, drop, exception};
        end
        else
            {Stat, Pc, Op, Vars, Memory_args, Write_reg, Write_hilo, Drop, Exception} <= decode2execute;
    end

endmodule
