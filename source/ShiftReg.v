`timescale 1 ns / 1 ps

module ShiftReg #(parameter DATA=32)
   (input         clk,reset,
    input  [2:0]  sel,
    input  [DATA-1:0] data_in,
    output reg [DATA-1:0] data_out);

reg [DATA-1:0] shift_array [11:0];

always @(posedge clk) begin
    shift_array[0] <= data_in;
end

genvar shft;

generate
    for(shft=0; shft < 11; shft=shft+1) begin: DELAY_BLOCK
        always @(posedge clk) begin
            shift_array[shft+1] <= shift_array[shft];
        end
    end
endgenerate

always@(*)
begin
    case(sel)
    3'b000: data_out = shift_array[6];
    3'b001: data_out = shift_array[7];
    3'b010: data_out = shift_array[8];
    3'b011: data_out = shift_array[9];
    3'b100: data_out = shift_array[10];
    default: data_out = shift_array[11];
    endcase
end

endmodule
