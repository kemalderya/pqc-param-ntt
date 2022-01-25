`timescale 1ns / 1ps

module butterfly(a, b, w, q, CT, i, clk, reset, r0, res2, r02, r1, add, sub

    );
    
    input[31:0] a, b, w, q;
    input[1:0] i;
    input CT, clk, reset;
    output reg[31:0] r0, r1, res2, add, sub, r02;
    
    reg[31:0] b2, bw, T3, a2, a3, a4, a5, ad1, ad2, ad3, ad4, ad5, ad6, a6, a6d, T3r, T3d, T3d1, T3d2, T3d3, T3d4, T3d5, T3d6, wd, wr, addr, add2r, subr, sub2r;
    reg[32:0] T;
    reg signed[32:0] T2;
    reg signed[32:0] T4;
    reg signed[32:0] T5;
    wire[31:0] res, mod_a, mod_s;
    
    always@*
    begin
    
    if(CT == 0)
        b2 = b;
    else
        b2 = bw;
        
    case(i)
    2'b00: a6d = ad3;
    2'b01: a6d = ad4;
    2'b10: a6d = ad5;
    2'b11: a6d = ad6;
    endcase
        
    if(CT == 0)
        a6 = a;
    else
        a6 = a6d;
        
    T3 = mod_a;
    addr = mod_a;
    // --------------------
    
    case(i)
    2'b00: T3d = T3d3;
    2'b01: T3d = T3d4;
    2'b10: T3d = T3d5;
    2'b11: T3d = T3d6;
    endcase
    
    if(CT == 0) begin
        r0 = T3d;
        r02 = T3d;
    end
    else begin
        r0 = T3r;
        r02 = T3r;
    end
        
    a2 = mod_s;
    subr = mod_s;
    // --------------------
    
    if(CT == 0)
        a4 = a3;
    else
        a4 = b;
    
    a5 = res;
    
    if(CT == 0)
        res2 = bw;
    else
        res2 = a3;
        
    if(CT == 0)
        wr = wd;
    else
        wr = w;
    
    end
    
    always@(posedge clk)
    begin
        ad1 <= a;
        ad2 <= ad1;
        ad3 <= ad2;
        ad4 <= ad3;
        ad5 <= ad4;
        ad6 <= ad5;
    end
    
    always@(posedge clk)
    begin
        T3d1 <= T3r;
        T3d2 <= T3d1;
        T3d3 <= T3d2;
        T3d4 <= T3d3;
        T3d5 <= T3d4;
        T3d6 <= T3d5;
    end      
    
    always@(posedge clk)
    begin
        T3r <= T3;
    end
    
    always@(posedge clk)
    begin
        a3 <= a2;
    end
    
    always@(posedge clk)
    begin
        bw  <= a5;
    end
    
    always@(posedge clk)
    begin
        r1 <= res2;
    end
    
    always@(posedge clk)
    begin
        wd <= w;
    end
    
    always@(posedge clk)
    begin        
        add2r <= addr;
        add   <= add2r;
    end
    
    always@(posedge clk)
    begin    
        sub2r <= subr;
        sub   <= sub2r;
    end
    
    mont_redu_top3 k(a4, wr, q, i, clk, reset, res);
    modular_add    k1(a6, b2, q, mod_a);
    modular_sub    k2(a6, b2, q, mod_s);    
    
endmodule
