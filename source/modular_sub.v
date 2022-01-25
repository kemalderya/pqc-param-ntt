`timescale 1ns / 1ps

module modular_sub(input [31:0]      a, b, q,
                   output reg [31:0] T
    );
    
    reg signed [32:0] T1;
    reg signed [32:0] T2, T3;
    
    always@(*) begin
        T1 = a - b;
        T2 = T1 + {q[31:8],8'b1};
        T3 = T1 + {q[31:8],8'b1,1'b0};
        
        if(T1[32] == 1'b0)
            T = T1;
        else if(T2[32] == 1'b0)
            T = T2;
        else
            T = T3;
    end
endmodule
