`include "defines.v"

// read latency is 1 cc

module BRAM #(parameter DSIZE=32, MSIZE=1023, DEPTH=10)
             (input                  clk,
              input                  wen,
              input      [DEPTH-1:0] waddr,
              input      [DSIZE-1:0] din,
              input      [DEPTH-1:0] raddr,
              output reg [DSIZE-1:0] dout);
// bram
(* ram_style="block" *) reg [DSIZE-1:0] blockram [MSIZE-1:0];

// write operation
always @(posedge clk) begin
    if(wen)
        blockram[waddr] <= din;
end

// read operation
always @(posedge clk) begin
    dout <= blockram[raddr];
end

endmodule
