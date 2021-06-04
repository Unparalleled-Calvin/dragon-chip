`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute (
    input common_context_t CommonContext,
    input memory_context_t memoryContext, 
    input write_context_t WriteContext,
    input logic clk, resetn,
    input execute_context_t ExecuteContext,
    output execute_context_t executeContext
);

    i32 result, vs, vt, vi, viu, va;
    i33 result33, vs33, vt33, vi33;
    logic exception_ov;
    
    i32 mult_a, mult_b;
    logic mult_done, div_done;
    i64 mult_c, div_c;
    word_t hi, lo;
    
    assign vs = ExecuteContext.vars.vs;
    assign vt = ExecuteContext.vars.vt;
    assign vi = ExecuteContext.vars.vi;
    assign viu = ExecuteContext.vars.viu;
    assign va = ExecuteContext.vars.va;
    assign vs33 = {ExecuteContext.vars.vs[31], ExecuteContext.vars.vs};
    assign vt33 = {ExecuteContext.vars.vt[31], ExecuteContext.vars.vt};
    assign vi33 = {ExecuteContext.vars.vi[31], ExecuteContext.vars.vi};
    
    always_comb begin
        unique case (ExecuteContext.op)
            MULTU, DIVU:  begin mult_a = vs; mult_b = vt; end
            MULT, DIV: begin
                if (vs[31] == 1'b0) mult_a = vs; // a>=0
                else mult_a = -$signed(vs);
                if (vt[31] == 1'b0) mult_b = vt; // b>=0
                else mult_b = -$signed(vt);
            end
            default: begin mult_a = 32'b0; mult_b = 32'b0; end
        endcase
    end
    
    Execute_ALU Execute_ALU_inst(.*);
    
    Execute_MULT Execute_MULT_Inst(.valid(ExecuteContext.stat == SE_MULT), .done(mult_done), 
                                   .a(mult_a), .b(mult_b), .c(mult_c), .*);
    
    Execute_DIV Execute_DIV_Inst(.valid(ExecuteContext.stat == SE_DIV), .done(div_done), 
                                 .a(mult_a), .b(mult_b), .c(div_c), .*);

    word_t vhi, vlo;
    Execute_Forward_HILO Execute_Forward_hilo_Inst(
        .m(memoryContext.write_hilo),
        .w(WriteContext.write_hilo),
        .data_hi(CommonContext.hi), 
        .data_lo(CommonContext.lo), 
        .vhi(vhi),
        .vlo(vlo)
    );
    
    Execute_HILO Execute_HILO_Inst(.op(ExecuteContext.op), .a(vs), .b(vt), .*);

    always_comb begin
        executeContext = ExecuteContext;
        if (!ExecuteContext.exception.valid) begin
            unique if (ExecuteContext.stat == SE_IDLE) begin
                //pass
            end
            else if (ExecuteContext.stat == SE_ALU) begin
                executeContext.stat = SE_IDLE;
                if (exception_ov)
                    `THROW(executeContext.exception, EX_OV, ExecuteContext.pc);
                if (ExecuteContext.write_reg.src == SRC_ALU) begin
                    executeContext.write_reg.value = result;
                    if (ExecuteContext.op == MOVN) begin
                        executeContext.write_reg.valid = |{ExecuteContext.vars.vt};
                    end else if (ExecuteContext.op == MOVZ) begin
                        executeContext.write_reg.valid = ~(|{ExecuteContext.vars.vt});
                    end
                end
                if (ExecuteContext.memory_args.valid)
                    executeContext.memory_args.addr = result;
            end
            else if (ExecuteContext.stat == SE_MULT) begin
                if (mult_done) begin
                    executeContext.stat = SE_IDLE;
                    if (ExecuteContext.op == MUL)begin
                        executeContext.write_reg.value = mult_c[31:0];
                    end else begin
                        // {hi, lo} = a * b;
                        executeContext.write_hilo.hi = hi;
                        executeContext.write_hilo.lo = lo;
                    end
                end
            end
            else if (ExecuteContext.stat == SE_DIV) begin
                if (div_done) begin
                    executeContext.stat = SE_IDLE;
                    // {hi, lo} = {a % b, a / b}
                    executeContext.write_hilo.hi = hi;
                    executeContext.write_hilo.lo = lo;
                end
            end
        end
        else begin
            executeContext.stat = SE_IDLE;
        end
    end
endmodule
