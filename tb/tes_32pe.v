`include "defines.v"

module tes_32pe();

parameter HP = 5;
parameter FP = (2*HP);
parameter q = 455577601;

reg        clk,reset;
reg [4:0]  OP_CODE;
reg        din_valid;
reg [31:0] din0;
reg [11:0]      ring_size;
reg [3:0]       ring_depth, limit;
wire[31:0] dout0;
wire       done;
wire [31:0] t_di, t_do;
wire [`BRAM_DEPTH-1:0] t_dr, t_dw;
wire t_de; 
wire [31:0] ntteven, nttodd, twiddle, oute, outo, outo2, state, addo, subo;  

// ---------------------------------------------------------------- CLK

always #HP clk = ~clk;

// ---------------------------------------------------------------- TXT data

parameter RING_DEPTH = 10;
parameter DATA_SIZE  = 32;
parameter PSET       = 2'b11;

// test data
parameter LOOP_PARAM = 3;
parameter LOOP_W     = 3552;
parameter LOOP_DATA  = (1 << RING_DEPTH);

reg [31:0] params   [0:5];
reg [31:0] w	 	[0:LOOP_W-1];
reg [31:0] winv	 	[0:LOOP_W-1];
reg [31:0] din	 	[0:LOOP_DATA-1];
reg [31:0] din_1	[0:LOOP_DATA-1];
reg [31:0] dout	 	[0:LOOP_DATA-1];

initial begin
	// ntt
	$readmemh("TES_PARAM_32PE.txt", params);
	$readmemh("TES_W_32PE.txt"    , w);
	$readmemh("TES_WINV_32PE.txt" , winv);
	$readmemh("TES_DIN0_32PE.txt"  , din);
	$readmemh("TES_DIN1_32PE.txt"  , din_1);
	$readmemh("TES_DOUT_32PE.txt" , dout);
end

// ---------------------------------------------------------------- TEST case

integer k;

initial begin: CLK_RESET_INIT
	// clk & reset (150 cc)
	clk       = 0;
	reset     = 0;

	#200;
	reset    = 1;
	#200;
	reset    = 0;
	#100;

	#1000;
end

initial begin: LOAD_DATA
    OP_CODE   = 0;
    din_valid = 0;

    din0 = 32'd0;

    #1500;
    ring_size = 1024;
    ring_depth = 10;
    limit = 10;
    
    // load parameters
    OP_CODE   = 5'b00001;
    #FP;
    OP_CODE   = 5'b00000;

    // ---- pset + op_type
    din_valid = 1'b1;
    din0      = {30'd0,PSET};
    #FP;
    // ---- q
    din_valid = 1'b1;
    din0      = params[1];
    #FP;
    // ---- n_inv
    din_valid = 1'b1;
    din0      = params[5];
    #FP;

    // ---- idle
    din_valid = 1'b0;
    #FP;

    // load w
    OP_CODE   = 4'b0010;
    #FP;
    OP_CODE   = 4'b0000;

    // ---- W
    for(k=0; k<LOOP_W; k=k+1) begin
        din_valid = 1'b1;
        din0 = w[k];
        #FP;
    end

    // ---- idle
    din_valid = 1'b0;
    #FP;
    // load input data
    OP_CODE   = 5'b00011;
    #FP;
    OP_CODE   = 5'b00000;

    // ---- DATA#0
    for(k=0; k<512; k=k+1) begin
        din_valid = 1'b1;
        din0 = din[k];
        #FP;
    end

    // ---- DATA#0
    for(k=512; k<1024; k=k+1) begin
        din_valid = 1'b1;
        din0 = din[k];
        #FP;
    end

    // ---- DATA#1
    for(k=0; k<512; k=k+1) begin
        din_valid = 1'b1;
        din0 = din_1[k];
        #FP;
    end
    
    // ---- DATA#1
    for(k=512; k<1024; k=k+1) begin
        din_valid = 1'b1;
        din0 = din_1[k];
        #FP;
    end

    // ---- idle
    din_valid = 1'b0;
    #FP; 

    // start
	OP_CODE = 4'b0100;
    #FP;
	OP_CODE = 4'b0000;
    #FP;
    
    #2020;
    
    din_valid = 1'b0;
    #FP;
    
    OP_CODE = 5'b01010;
    #FP;
	OP_CODE = 5'b00000;
    #FP;
    
    #2020;
    
    // ---- idle
    din_valid = 1'b0;
    #FP;
    din_valid = 1'b1;
    OP_CODE = 5'b01011;
    #FP;
	OP_CODE = 5'b00000;
    #FP;
    
    for(k=0; k<42; k=k+1) begin
        din_valid = 1'b1;
        #FP;
    end
    
    // ---- idle
    din_valid = 1'b0;
    #FP;
    
    #200;
    
    // load W_inv
    OP_CODE   = 5'b00010;
    #FP;
    OP_CODE   = 5'b00000;
    
    for(k=0; k<LOOP_W; k=k+1) begin
        din_valid = 1'b1;
        din0 = winv[k];
        #FP;
    end
    
    // ---- idle
    din_valid = 1'b0;
    #FP;   
    
    OP_CODE = 5'b00111;
    #FP;
	OP_CODE = 5'b00000;
    #FP;
    
    #2020;
    
    
    din_valid = 1'b1;
    OP_CODE = 5'b01000;
    #FP;
	OP_CODE = 5'b00000;
    #FP;
    
    for(k=0; k<42; k=k+1) begin
        din_valid = 1'b1;
        #FP;
    end
    
    // ---- idle
    din_valid = 1'b0;
    #FP;
end

// ---------------------------------------------------------------- TEST control

integer m;
integer e;
integer i;

reg [31:0] fout[0:1023];

initial begin: TEST_DATA
    e = 0;
    i = 0;
    #1500;

    while(done == 1'b0) begin
        #FP;
    end

    #FP;
    m = 0;
	
	while(i<(ring_size >> (`PE_DEPTH + 1))) begin
        while(dout0 != 0) begin
            if(m[0] == 0)
                fout[(m>>1)] = dout0;
            else
                fout[(m>>1)+512] = dout0;
            
            m = m + 1;
            #FP;
        end
        
        i = i + 1;
        #FP;
    end

    #100;

	// Check result	
    for(m=0; m<LOOP_DATA; m=m+1) begin
        if(fout[m] >= q)
            fout[m] = fout[m] - q;
        else
            fout[m] = fout[m];
        
        if(fout[m] == dout[m]) begin
			e = e+1;
        end
		else begin
			$display("Wrong result -- index:%d, expected:%h --> calculated:%h",m,dout[m],fout[m]);
		end
    end

    if(e == (1 << RING_DEPTH))
        $display("NTT -- Correct!");
    else
        $display("NTT -- Incorrect!");

    $stop;
end

// ---------------------------------------------------------------- UUT

NTT1024 uut (clk,reset,
             OP_CODE,
             din_valid,
             din0,
             ring_size, ring_depth, limit,
             dout0,
             done);

endmodule
