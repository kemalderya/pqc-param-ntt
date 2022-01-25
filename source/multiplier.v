`timescale 1ns / 1ps

module multiplier(A, B, clk, res

    );
    
    input[31:0] A, B;
    input clk;
    output reg[63:0] res;

    (* use_dsp = "yes" *) reg [31:0] p00,p01,p10,p11;

    always @(posedge clk) begin
        p00 <= A[15:0] * B[15:0];
        p01 <= A[15:0] * B[31:16];
        p10 <= A[31:16] * B[15:0];
        p11 <= A[31:16] * B[31:16];
    end

    wire [47:0] p;
    wire [31:0] i0,i1,i2;
    wire [31:0] c,s;

    assign i0 = {p11[15:0],p00[31:16]};
    assign i1 = p01;
    assign i2 = p10;

    generate
        genvar fa_idx;

        for(fa_idx=0; fa_idx<32; fa_idx=fa_idx+1) begin: FA_LOOP
            assign {c[fa_idx],s[fa_idx]} = i0[fa_idx] + i1[fa_idx] + i2[fa_idx];
        end
    endgenerate

    assign p = {p11[31:16],s} + {c,1'b0};

    always @(posedge clk) begin
        res <= {p,p00[15:0]};
    end      
endmodule
