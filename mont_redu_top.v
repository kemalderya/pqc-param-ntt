`timescale 1ns / 1ps

module mont_redu_top(A, B, q, i, clk, reset, res

    );
    
    input[31:0] A, B, q;
    input[1:0] i;
    input clk, reset;
    output reg[31:0] res;
    
    wire[63:0] C;
    reg[63:0] Cr;
    reg[23:0] qh, qhd2, qhd3, qhd4;
    reg [1:0] id1, id2, id3, id4;
    reg [32:0] qd1, qd2;
    
    (* use_dsp = "yes" *) reg[47:0] T1, T4, T6, T7; 
    
    reg[55:0] TH;
    reg[10:0] T1w;
    reg[56:0] T1r;
    
    reg[48:0] TH2;
    reg[3:0]  T4w;
    reg[49:0] T4r;
    
    reg[41:0] TH3;
    reg[47:0] T6r;
    
    reg[39:0] TH4;
    
    reg[56:0] T8;
    reg signed [57:0] T9; 
    
    reg[10:0] TL, TC, TL2, TC2, TL3, TC3, TL4, TC4;
    reg carry, carry2, carry3, carry4;
    reg[10:0] dum, dum2, dum3, dum4;
    
    // ------------------------------------------------------------------------------------
    
    multiplier x(A, B, clk, C);   

    // ------------------------------------------------------------------------------------
    
    always@*
    begin
        Cr = C;
        
        // ------------------------------------------------------------------------------------
        
        qh = (qd2 >> 8);
        TL = Cr[7:0];
        dum = -(TL[7:0]);
        TC = dum[7:0];
        carry = TL[7] | TC[7];
        TH = (Cr >> 8);
        
        // DSP Block
        T1 = (qh * TC) + TH[45:0] + carry;
        T1w= TH[55:46] + T1[46];
        
        // ------------------------------------------------------------------------------------
        
        TL2 = T1r[7:0];
        dum2 = -(TL2[7:0]);
        TC2 = dum2[7:0];
        carry2 = TL2[7] | TC2[7];
        TH2 = (T1r >> 8);

        // DSP Block
        T4 = (qhd2 * TC2) + TH2[45:0] + carry2;
        T4w= TH2[48:46]+T4[46];
        
        // ------------------------------------------------------------------------------------
        
        TL3 = T4r[7:0];
        dum3 = -(TL3[7:0]);
        TC3 = dum3[7:0];
        carry3 = TL3[7] | TC3[7];
        TH3 = (T4r >> 8);
        
       // DSP Block
       T6 = (qhd3 * TC3) + TH3 + carry3; 
       
       // ------------------------------------------------------------------------------------
        
        TL4 = T6r[7:0];
        dum4 = -(TL4[7:0]);
        TC4 = dum4[7:0];
        carry4 = TL4[7] | TC4[7];
        TH4 = (T6r >> 8);
        
        // DSP Block
        T7 = (qhd4 * TC4) + TH4 + carry4;
        
        // ------------------------------------------------------------------------------------
        
        if(id2 == 2'd0)
            T8 = {T1w,T1[45:0]};
        else if(id3 == 2'd1)
            T8 = {T4w,T4[45:0]};
        else if(id4 == 2'd2)
            T8 = T6;
        else
            T8 = T7;     
            
        res = T8;      
        
    end
    
    // ------------------------------------------------------------------------------------
    
    always@(posedge clk)
    begin
        qd1 <= q;
        qd2 <= qd1;
    end
    
    always@(posedge clk)
    begin
        if(reset)
        begin
            id1 <= 0;
            id2 <= 0;
            id3 <= 0;
            id4 <= 0;           
        end
        else
        begin
            id1 <= i;
            id2 <= id1;
            id3 <= id2;
            id4 <= id3;
        end
    end

    always@(posedge clk)
    begin
        T1r  <= {T1w,T1[45:0]};
    end
    
    always@(posedge clk)
    begin
        T4r  <= {T4w,T4[45:0]};    
    end 
    
    always@(posedge clk)
    begin       
        T6r <= T6;    
    end  
    
    always@(posedge clk)
    begin           
        qhd2 <= qh;
        qhd3 <= qhd2;
        qhd4 <= qhd3; 
    end 
endmodule
