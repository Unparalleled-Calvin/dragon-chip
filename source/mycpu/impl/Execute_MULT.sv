`include "common.svh"
`include "mycpu/mycpu.svh"

module Execute_MULT (
    input logic clk, resetn,
    input i1 valid,
    input i32 a, b,
    output logic done, // 握手信号，done 上升沿时的输出是有效的
    output i64 c // c = a * b
);
    enum i1 { INIT, DOING } state, state_nxt;
    i35 count, count_nxt;
    localparam i35 MULT_DELAY = {2'b0, 1'b1, 32'b0};
    always_ff @(posedge clk) begin
        if (~resetn) begin
            {state, count} <= '0;
        end else begin
            {state, count} <= {state_nxt, count_nxt};
        end
    end
    assign done = (state_nxt == INIT);
    always_comb begin
        {state_nxt, count_nxt} = {state, count}; // default
        unique case(state)
            INIT: begin
                if (valid) begin
                    state_nxt = DOING;
                    count_nxt = MULT_DELAY;
                end
            end
            DOING: begin
                count_nxt = {1'b0, count_nxt[34:1]};
                if (count_nxt == '0) begin
                    state_nxt = INIT;
                end
            end
        endcase
    end
    i65 p, p_nxt;
    always_comb begin
        p_nxt = p;
        unique case(state)
            INIT: begin
                p_nxt = {33'b0, a};
            end
            DOING: begin
                if (p_nxt[0]) begin
                    p_nxt[64:32] = p_nxt[63:32] + b;
                    // p_nxt[64:32] = p_nxt[64:32] + b;
            	end
            	p_nxt = {1'b0, p_nxt[64:1]};
            end
        endcase
    end
    always_ff @(posedge clk) begin
        if (~resetn) begin
            p <= 65'b0;
        end else begin
            p <= p_nxt;
        end
    end
    assign c = p[63:0];
endmodule
