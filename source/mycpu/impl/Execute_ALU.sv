`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute_ALU (
    input execute_context_t ExecuteContext,
    output word_t result,
    output logic exception_ov
);

    i32 vs, vt, vi, viu, va;
    i33 result33, vs33, vt33, vi33;
    assign vs = ExecuteContext.vars.vs;
    assign vt = ExecuteContext.vars.vt;
    assign vi = ExecuteContext.vars.vi;
    assign viu = ExecuteContext.vars.viu;
    assign va = ExecuteContext.vars.va;
    assign vs33 = {ExecuteContext.vars.vs[31], ExecuteContext.vars.vs};
    assign vt33 = {ExecuteContext.vars.vt[31], ExecuteContext.vars.vt};
    assign vi33 = {ExecuteContext.vars.vi[31], ExecuteContext.vars.vi};
    
    always_comb begin
        exception_ov = '0;
        result = '0;
        result33 = '0;
        unique case (ExecuteContext.op)
            SLL     : result = vt << va;
            SRL     : result = vt >> va;
            SRA     : result = $signed(vt) >>> $signed(va);
            SLLV    : result = vt << (vs[4:0]);
            SRLV    : result = vt >> (vs[4:0]);
            SRAV    : result = $signed(vt) >>> $signed(vs[4:0]);
            JALR    : result = ExecuteContext.pc + 32'h8;
            ADD     : begin
                        result33 = $signed(vs33) + $signed(vt33);
                        if (result33[32] != result33[31] && !ExecuteContext.exception.valid)
                            exception_ov = 1;
                        else
                            result = result33[31:0];
                    end
            ADDU    : result = vs + vt; //TODO
            SUB     : begin
                        result33 = $signed(vs33) - $signed(vt33);
                        if (result33[32] != result33[31] && !ExecuteContext.exception.valid)
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
            BLTZAL  : result = ExecuteContext.pc + 32'h8;
            BGEZAL  : result = ExecuteContext.pc + 32'h8;
            JAL     : result = ExecuteContext.pc + 32'h8;
            ADDI    : begin
                        result33 = vs33 + vi33;
                        if (result33[32] != result33[31] && !ExecuteContext.exception.valid)
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
            LWL     : result = vs + vi;
            LWR     : result = vs + vi;
            LBU     : result = vs + vi;
            LHU     : result = vs + vi;
            SB      : result = vs + vi;
            SH      : result = vs + vi;
            SW      : result = vs + vi;
            SWL     : result = vs + vi;
            SWR     : result = vs + vi;
            CLO     : begin
                        priority case(0)
                        vs[31] : result = 32'd0;
                        vs[30] : result = 32'd1;
                        vs[29] : result = 32'd2;
                        vs[28] : result = 32'd3;
                        vs[27] : result = 32'd4;
                        vs[26] : result = 32'd5;
                        vs[25] : result = 32'd6;
                        vs[24] : result = 32'd7;
                        vs[23] : result = 32'd8;
                        vs[22] : result = 32'd9;
                        vs[21] : result = 32'd10;
                        vs[20] : result = 32'd11;
                        vs[19] : result = 32'd12;
                        vs[18] : result = 32'd13;
                        vs[17] : result = 32'd14;
                        vs[16] : result = 32'd15;
                        vs[15] : result = 32'd16;
                        vs[14] : result = 32'd17;
                        vs[13] : result = 32'd18;
                        vs[12] : result = 32'd19;
                        vs[11] : result = 32'd20;
                        vs[10] : result = 32'd21;
                        vs[9]  : result = 32'd22;
                        vs[8]  : result = 32'd23;
                        vs[7]  : result = 32'd24;
                        vs[6]  : result = 32'd25;
                        vs[5]  : result = 32'd26;
                        vs[4]  : result = 32'd27;
                        vs[3]  : result = 32'd28;
                        vs[2]  : result = 32'd29;
                        vs[1]  : result = 32'd30;
                        vs[0]  : result = 32'd31;
                        default: result = 32'd32;
                        endcase
                    end
            CLZ     : begin
                        priority case(1)
                        vs[31] : result = 32'd0;
                        vs[30] : result = 32'd1;
                        vs[29] : result = 32'd2;
                        vs[28] : result = 32'd3;
                        vs[27] : result = 32'd4;
                        vs[26] : result = 32'd5;
                        vs[25] : result = 32'd6;
                        vs[24] : result = 32'd7;
                        vs[23] : result = 32'd8;
                        vs[22] : result = 32'd9;
                        vs[21] : result = 32'd10;
                        vs[20] : result = 32'd11;
                        vs[19] : result = 32'd12;
                        vs[18] : result = 32'd13;
                        vs[17] : result = 32'd14;
                        vs[16] : result = 32'd15;
                        vs[15] : result = 32'd16;
                        vs[14] : result = 32'd17;
                        vs[13] : result = 32'd18;
                        vs[12] : result = 32'd19;
                        vs[11] : result = 32'd20;
                        vs[10] : result = 32'd21;
                        vs[9]  : result = 32'd22;
                        vs[8]  : result = 32'd23;
                        vs[7]  : result = 32'd24;
                        vs[6]  : result = 32'd25;
                        vs[5]  : result = 32'd26;
                        vs[4]  : result = 32'd27;
                        vs[3]  : result = 32'd28;
                        vs[2]  : result = 32'd29;
                        vs[1]  : result = 32'd30;
                        vs[0]  : result = 32'd31;
                        default: result = 32'd32;
                        endcase
                    end
            MOVN    : result = vs;
            MOVZ    : result = vs;
            default : result = 32'h0;
        endcase
    end
endmodule
