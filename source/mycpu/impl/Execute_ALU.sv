`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute_ALU (
    input word_t Pc, 
    input op_t Op, 
    input vars_t Vars,
    input exception_args_t Exception, 
    output word_t result,
    output logic exception_ov
);

    i32 vs, vt, vi, viu, va;
    i33 result33, vs33, vt33, vi33;
    assign vs = Vars.vs;
    assign vt = Vars.vt;
    assign vi = Vars.vi;
    assign viu = Vars.viu;
    assign va = Vars.va;
    assign vs33 = {Vars.vs[31], Vars.vs};
    assign vt33 = {Vars.vt[31], Vars.vt};
    assign vi33 = {Vars.vi[31], Vars.vi};
    
    always_comb begin
        exception_ov = '0;
        result = '0;
        result33 = '0;
        unique case (Op)
            SLL     : result = vt << va;
            SRL     : result = vt >> va;
            SRA     : result = $signed(vt) >>> $signed(va);
            SLLV    : result = vt << (vs[4:0]);
            SRLV    : result = vt >> (vs[4:0]);
            SRAV    : result = $signed(vt) >>> $signed(vs[4:0]);
            JALR    : result = Pc + 32'h8;
            ADD     : begin
                        result33 = $signed(vs33) + $signed(vt33);
                        if (result33[32] != result33[31] && !Exception.valid)
                            exception_ov = 1;
                        else
                            result = result33[31:0];
                    end
            ADDU    : result = vs + vt; //TODO
            SUB     : begin
                        result33 = $signed(vs33) - $signed(vt33);
                        if (result33[32] != result33[31] && !Exception.valid)
                            exception_ov = 1;
                        else
                            result = result33[31:0];
                    end
            SUBU    : result = vs - vt; //TODO
            AND     : result = vs & vt;
            OR      : result = vs | vt;
            XOR     : result = vs ^ vt;
            NOR     : result = ~(vs | vt);
            SLT     : result = ($signed(vs) < $signed(vt)) ? 32'h1 : 32'h0;
            SLTU    : result = (vs < vt) ? 32'h1 : 32'h0;
            BLTZAL  : result = Pc + 32'h8;
            BGEZAL  : result = Pc + 32'h8;
            JAL     : result = Pc + 32'h8;
            ADDI    : begin
                        result33 = vs33 + vi33;
                        if (result33[32] != result33[31] && !Exception.valid)
                            exception_ov = 1;
                        else
                            result = result33[31:0];
                    end
            ADDIU   : result = vs + vi; //TODO
            SLTI    : result = ($signed(vs) < $signed(vi)) ? 32'h1 : 32'h0;
            SLTIU   : result = (vs < vi) ? 32'h1 : 32'h0;
            ANDI    : result = vs & viu;
            ORI     : result = vs | viu;
            XORI    : result = vs ^ viu;
            LUI     : result = {vi[15:0], {16'h0}};
            LB      : result = vs + vi;
            LH      : result = vs + vi;
            LW      : result = vs + vi;
            LBU     : result = vs + vi;
            LHU     : result = vs + vi;
            SB      : result = vs + vi;
            SH      : result = vs + vi;
            SW      : result = vs + vi;
            default : result = 32'h0;
        endcase
    end
endmodule
