`include "defines.v"

module NTT1024(input             clk,reset,
               input      [3:0]  OP_CODE,
               input             din_valid,
               input      [31:0] din0,
               input      [11:0] ring_size,
               input      [3:0]  ring_depth, limit,
               output reg [31:0] dout0,
               output reg        done                    
               );
// ---------------------------------------------------------------- connections


reg [4:0] curr_state,next_state;

reg [31:0]q;
reg [31:0]n_inv;

reg [1:0] dsp;
reg       conf;
reg       ntt2;
wire      nttdone;

parameter c_param_limit = 2'd2;

reg [1:0]             c_param              ;  // counter for OP_READ_PSET state
reg [`TW_DEPTH+3:0] c_tw                 ;  // counter for OP_READ_W state
reg [10:0] c_data               ;  

reg              c_op;  // counter for OP_NTT state
reg [(`BRAM_DEPTH-1):0] c_out                ;  // counter for OP_SEND_DATA0 state
reg [`PE_DEPTH+1:0]      c_out2               ;
reg [`PE_DEPTH:0]        c_out_limit2         ;

// bram signals for input polynomials
reg [31:0]            di0 [(2*`PE)-1:0];
wire[31:0]            do0 [(2*`PE)-1:0];
reg [`BRAM_DEPTH-1:0] dw0 [(2*`PE)-1:0];
reg [`BRAM_DEPTH-1:0] dr0 [(2*`PE)-1:0];
reg [0:0]             de0 [(2*`PE)-1:0];

// bram signals for twiddle factors
reg [31:0]            ti  [`PE-1:0];
wire[31:0]            to  [`PE-1:0];
reg [`TW_DEPTH-1:0]   tw  [`PE-1:0];
reg [`TW_DEPTH-1:0]   tr  [`PE-1:0];
reg [0:0]             te  [`PE-1:0];

// control unit signals (from control unit to top module)
reg [2:0] start_ntt_1p;

wire [`BRAM_DEPTH-1:0]         raddr0;
wire [`BRAM_DEPTH-1:0]         waddr0,waddr1;
wire                           wen0  ,wen1  ;
wire                           brsel0,brsel1;
wire                           brselen0,brselen1;
wire [3:0]                     stage_count;
wire [`TW_DEPTH-1:0]           raddr_tw;
wire [2*`PE*(`PE_DEPTH+1)-1:0] brscramble;

// signals for PU blocks
reg [31:0] NTTin0     [`PE-1:0];
reg [31:0] NTTin1     [`PE-1:0];
reg [31:0] MULin      [`PE-1:0];
wire[31:0] ADDout     [`PE-1:0];
wire[31:0] SUBout     [`PE-1:0];
wire[31:0] NTToutEVEN [(2*`PE)-1:0];
wire[31:0] NTToutODD  [`PE-1:0];
wire[31:0] MULout     [(2*`PE)-1:0];

// ---------------------------------------------------------------- FSM

always @(posedge clk) begin
    if(reset)
        curr_state <= 0;
    else
        curr_state <= next_state;
end

always @(*) begin
    case(curr_state)
    `OP_IDLE: begin
        case(OP_CODE)
        4'd0: next_state = `OP_IDLE;
        4'd1: next_state = `OP_READ_PSET;
        4'd2: next_state = `OP_READ_W;
        4'd3: next_state = `OP_READ_DATA0;
        4'd4: next_state = `OP_NTT;
        4'd7: next_state = `OP_INTT;
        4'd8: next_state = `OP_POST;
        4'd10: next_state = `OP_NTT;
        4'd11: next_state = `OP_COEFMUL;
        4'd12: next_state = `OP_COEFMUL2;
        4'd13: next_state = `OP_COEFMUL1;      
        default: next_state = `OP_IDLE;
        endcase
    end
    `OP_READ_PSET: begin
        next_state = (c_param == c_param_limit) ? `OP_IDLE : `OP_READ_PSET;
    end
    `OP_READ_W: begin
        next_state = (!din_valid) ? `OP_IDLE : `OP_READ_W;
    end
    `OP_READ_DATA0: begin
        next_state = (!din_valid) ? `OP_IDLE : `OP_READ_DATA0;
    end
    `OP_NTT: begin
        next_state = (nttdone == 1'b1) ? `OP_IDLE : `OP_NTT;
    end
    `OP_SEND_DATA0: begin
        next_state = ((c_out == (ring_size >>`PE_DEPTH + 1)) && c_out2 == c_out_limit2 + 1) ? `OP_IDLE : `OP_SEND_DATA0;
    end
    `OP_INTT: begin
        next_state = (nttdone == 1'b1) ? `OP_IDLE  : `OP_INTT;
    end
    `OP_POST: begin
        next_state = (!din_valid) ? `OP_SEND_DATA0 : `OP_POST;
    end
    `OP_COEFMUL: begin
        next_state = (!din_valid) ? `OP_IDLE : `OP_COEFMUL;
    end
    `OP_COEFMUL2: begin
        next_state = (!din_valid) ? `OP_IDLE : `OP_COEFMUL2;
    end
    `OP_COEFMUL1: begin
        next_state = (!din_valid) ? `OP_IDLE : `OP_COEFMUL1;
    end 
    default: next_state = `OP_IDLE;
    endcase
end

always @(posedge clk) begin
    if(reset)
        ntt2 <= 0;
    else begin
        if(OP_CODE == 4'b0100)
            ntt2 <= 1'b0;
        else if(OP_CODE == 4'b1010)
            ntt2 <= 1'b1;          
        else
            ntt2 <= ntt2;
    end    
end

// ---------------------------------------------------------------- PSET, OP_TYPE, Q, N_INV
/*
c_param:0 --> receive pset
c_param:1 --> receive q
c_param:2 --> receive n_inv (not used in NTT)
*/

always @(posedge clk) begin
    if(reset) begin
        c_param <= 0;
    end
    else begin
        if(din_valid) begin
            if(c_param == c_param_limit)
                c_param <= 0;
            else if(curr_state == `OP_READ_PSET)
                c_param <= c_param + 1;
        end
        else begin
            c_param <= c_param;
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        q       <= 0;
        n_inv   <= 0;
        dsp     <= 0;
    end
    else begin
        if(curr_state == `OP_READ_PSET) begin
            dsp                      <= (din_valid && (c_param == 2'd0)) ? din0[1:0] : dsp;
            q                        <= (din_valid && (c_param == 2'd1)) ? din0      : q;
            n_inv                    <= (din_valid && (c_param == 2'd2)) ? din0      : n_inv;
        end
        else begin
            q       <= q;
            n_inv   <= n_inv;
            dsp     <= dsp;
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        c_tw <= 0;
    end
    else begin
        if((curr_state == `OP_READ_W)) begin
            if(din_valid)     
                c_tw <= c_tw + 1;            
            else 
                c_tw <= 0;            
        end
        else 
            c_tw <= c_tw;        
    end
end

always @(posedge clk) begin
    if(reset) begin
        c_data        <= 0;
    end
    else begin
        if((curr_state == `OP_READ_PSET) && (c_param == 2'd0)) begin
            if(din_valid)                 
                c_data        <= 0;            
        end
        else if((curr_state == `OP_READ_DATA0) || (curr_state == `OP_POST) || (curr_state == `OP_COEFMUL) || (curr_state == `OP_COEFMUL2) || (curr_state == `OP_COEFMUL1)) begin
            if(din_valid) 
                c_data <= c_data + 1;            
            else 
                c_data       <= 0;            
        end      
        else 
            c_data       <= 0;        
    end
end

// ---------------------------------------------------------------- OP

always @(posedge clk) begin
    if(reset) begin
        c_op       <= 0;
    end
    else begin
        if((curr_state == `OP_NTT) || (curr_state == `OP_INTT)) begin
            c_op <= 1;
        end        
        else begin
            c_op       <= 0;
        end
    end
end

// ---------------------------------------------------------------- OUT

always @(posedge clk) begin
    if(reset) begin
        c_out        <= 0;
        c_out2       <= 0;
        c_out_limit2 <= 0;
    end
    else begin
        if((curr_state == `OP_READ_PSET) && (c_param == 2'd0)) begin
            if(din_valid) begin            
                c_out        <= 0;
                c_out2       <= 0;
                c_out_limit2 <= (`PE << 1) - 1;
            end
        end
        else if(curr_state == `OP_SEND_DATA0) begin
            if(c_out2 == c_out_limit2)
                c_out <= c_out + 1;
            else
                c_out <= c_out;

            if(c_out2 == c_out_limit2 + 1)
                c_out2 <= 0;
            else
                c_out2 <= c_out2 + 1;            
            
            c_out_limit2 <= c_out_limit2;
        end
        else begin
            c_out       <= c_out;
            c_out2       <= c_out2;
            c_out_limit2 <= c_out_limit2;
        end
    end
end

// ---------------------------------------------------------------- CU signals (start signal)

always @(posedge clk) begin
    if(reset) begin
        start_ntt_1p <= 3'b000;
    end
    else begin
        case(curr_state)
        `OP_NTT: begin
            if(c_op == 0 && ntt2 == 0)
                start_ntt_1p <= 3'b100;
            else if(c_op == 0 && ntt2 == 1)
                start_ntt_1p <= 3'b101;
            else
                start_ntt_1p <= 0;
        end
        `OP_INTT: begin
            if(c_op == 0)
                start_ntt_1p <= 3'b111;
            else
                start_ntt_1p <= 0;
        end
        default: begin
            start_ntt_1p <= 0;
        end
        endcase

    end
end

always @(posedge clk) begin
    if(reset) begin
        conf <= 1'b0;        
    end
    else begin
        case(curr_state)
        `OP_NTT: begin
            conf <= 1'b1;            
        end
        `OP_INTT: begin
            conf <= 1'b0;            
        end
        `OP_COEFMUL: begin
            conf <= 1'b0;            
        end
        `OP_COEFMUL1: begin
            if(c_data > 646)
                conf <= 1'b1;
            else
                conf <= 1'b0;
        end 
        `OP_COEFMUL2: begin
            if(c_data > ((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + 1)
                conf <= 1'b1;
            else
                conf <= 1'b0;
        end      
        `OP_POST: begin
            conf <= 1'b0;            
        end
        default: begin
            conf  <= conf;            
        end
        endcase
    end
end

// ---------------------------------------------------------------- BRAM signals
// ---------------------------------------------------------------- data, tw, ntt

/*
In state OP_READ_W, twiddle factors are stored into BRAMs.
*/

// twiddle (write)
integer t_loop = 0;

always @(posedge clk) begin
    for(t_loop = 0; t_loop<`PE; t_loop=t_loop+1) begin
        if(((curr_state == `OP_READ_W)) && din_valid) begin
            te[t_loop] <= (t_loop == (c_tw & ((1 << `PE_DEPTH)-1)));
            tw[t_loop] <= c_tw >> `PE_DEPTH;
            ti[t_loop] <= din0;
        end
        else begin
            te[t_loop] <= 1'b0;
            tw[t_loop] <= 0;
            ti[t_loop] <= 0;
        end        
    end
end

// twiddle (read)
integer t_loop_rd = 0;

always @(posedge clk) begin
    for(t_loop_rd = 0; t_loop_rd<`PE; t_loop_rd=t_loop_rd+1) begin
        if((curr_state == `OP_COEFMUL2) && (c_data > (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) - 1))) begin
            tr[t_loop_rd] <= (c_data - ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> `PE_DEPTH));
        end
        else if((curr_state == `OP_COEFMUL1) && (c_data > 645)) begin
            if(c_data < 710)
                tr[t_loop_rd] <= ((c_data - 646) << 1);
            else
                tr[t_loop_rd] <= ((c_data - 710) << 1) + 1;
        end
        else begin
            tr[t_loop_rd] <= raddr_tw;
        end
    end
end

integer n = 0;

always @(posedge clk) begin
    for(n = 0; n < (2*`PE); n = n + 1) begin
            if(curr_state == `OP_READ_DATA0) begin
                dr0[n] <= 0;
                if(din_valid) begin
                    if(c_data < (ring_size >> 1)) begin
                        di0[n] <= din0;
                        dw0[n] <= c_data >> `PE_DEPTH;
                        de0[n] <= (n == ((c_data & ((1 << `PE_DEPTH) - 1)) << 1));
                    end
                    else if(c_data < ring_size) begin
                        di0[n] <= din0;
                        dw0[n] <= ((c_data - (ring_size >> 1)) >> `PE_DEPTH);
                        de0[n] <= (n == ((((c_data - (ring_size >> 1)) & ((1 << `PE_DEPTH) - 1)) << 1) + 1));
                    end
                    else if(c_data < ring_size + (ring_size >> 1)) begin
                        di0[n] <= din0;
                        dw0[n] <= ((1 << (`BRAM_DEPTH - 1)) | ((c_data - ring_size) >> `PE_DEPTH));
                        de0[n] <= (n == (((c_data - ring_size) & ((1 << `PE_DEPTH) - 1)) << 1));
                    end
                    else begin
                        di0[n] <= din0;
                        dw0[n] <= ((1 << (`BRAM_DEPTH - 1)) | ((c_data - (ring_size + (ring_size >> 1))) >> `PE_DEPTH));
                        de0[n] <= (n == ((((c_data - (ring_size + (ring_size >> 1))) & ((1 << `PE_DEPTH) - 1)) << 1) + 1));
                    end
                end
                else begin                    
                    di0[n] <= di0[n];
                    dw0[n] <= dw0[n];
                    de0[n] <= de0[n];                  
                end
            end
            else if(curr_state == `OP_NTT || curr_state == `OP_INTT) begin
                dr0[n] <= raddr0;
                if((stage_count < (ring_depth - `PE_DEPTH - 1) && (curr_state == `OP_NTT) && (stage_count != 6 || limit != 3'b111)) || ((stage_count >= `PE_DEPTH && stage_count < (ring_depth - 1)) && (curr_state == `OP_INTT))) begin
                    if(brselen0) begin
                        if(brsel0 == 0) begin
                            if(n[0] == 0) begin
                                de0[n] <= wen0;
                                dw0[n] <= waddr0;
                                di0[n] <= MULout[n];
                            end
                        end
                        else begin // brsel0 == 1
                            if(n[0] == 0) begin
                                de0[n] <= wen1;
                                dw0[n] <= waddr1;
                                di0[n] <= MULout[n+1];
                            end
                        end
                    end
                    else begin
                        if(n[0] == 0) begin
                            de0[n] <= 0;
                            dw0[n] <= dw0[n];
                            di0[n] <= di0[n];
                        end
                    end

                    if(brselen1) begin
                        if(brsel1 == 0) begin
                            if(n[0] == 1) begin
                                de0[n] <= wen0;
                                dw0[n] <= waddr0;
                                di0[n] <= MULout[n-1];
                            end
                        end
                        else begin // brsel1 == 1
                            if(n[0] == 1) begin
                                de0[n] <= wen1;
                                dw0[n] <= waddr1;
                                di0[n] <= MULout[n];
                            end
                        end
                    end
                    else begin
                        if(n[0] == 1) begin
                            de0[n] <= 0;
                            dw0[n] <= dw0[n];
                            di0[n] <= di0[n];
                        end
                    end
                end
                else if((stage_count < (limit - 1) && curr_state == `OP_NTT) || (stage_count < (ring_depth - 1) && curr_state == `OP_INTT)) begin
                    de0[n] <= wen0;
                    dw0[n] <= waddr0;
                    di0[n] <= NTToutEVEN[brscramble[(`PE_DEPTH+1)*n+:(`PE_DEPTH+1)]];                   
                end
                else if (ntt2 == 1 && stage_count == limit - 1 && curr_state == `OP_NTT) begin                    
                    de0[n] <= wen0;
                    dw0[n] <= waddr0;
                    if(n[0] == 0)
                        di0[n] <= NTToutEVEN[(n + 1)];
                    else
                        di0[n] <= NTToutEVEN[(n - 1)];
                end
                else begin                    
                    de0[n] <= wen0;
                    dw0[n] <= waddr0;
                    di0[n] <= NTToutEVEN[n];                    
                end
            end            
            else if(curr_state == `OP_COEFMUL || curr_state == `OP_POST) begin
                if(c_data < (ring_size >> (`PE_DEPTH + 1))) begin
                    if(n[0] == 0)
                        dr0[n] <= c_data;
                    
                    if(n[0] == 1 && curr_state == `OP_COEFMUL)
                        dr0[n] <= (1 << (`BRAM_DEPTH - 1)) | c_data;
                end    
                else if(c_data < ring_size >> `PE_DEPTH) begin
                    if(n[0] == 1)
                        dr0[n] <= c_data - (ring_size >> `PE_DEPTH + 1);                    
                    
                    if(n[0] == 0 && curr_state == `OP_COEFMUL)
                        dr0[n] <= (1 << (`BRAM_DEPTH - 1)) | (c_data - (ring_size >> `PE_DEPTH + 1));
                end                            
                else
                    dr0[n] <= 0;                
                
                if((c_data > 6 + dsp) && (c_data < ((ring_size >> (`PE_DEPTH + 1)) + 7 + dsp))) begin                    
                    if(n[0] == 0) begin
                        de0[n] <= 1;
                        dw0[n] <= (c_data-7-dsp);
                        di0[n] <= NTToutEVEN[n+1];
                    end
                    
                    if(n[0] == 1) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end
                end
                else if((c_data > 6 + dsp) && (c_data < ((ring_size >> `PE_DEPTH) + 7 + dsp))) begin
                    if(n[0] == 1) begin
                        de0[n] <= 1;
                        dw0[n] <= (c_data-((ring_size >> `PE_DEPTH + 1) + 7 + dsp));
                        di0[n] <= NTToutEVEN[n];
                    end
                    
                    if(n[0] == 0) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end
                end
                else begin
                    de0[n] <= 0;
                    dw0[n] <= 0;
                    di0[n] <= 0;
                end    
            end
            else if(curr_state == `OP_COEFMUL1) begin
                if(c_data < 128) begin
                    if(n[0] == 0)
                        dr0[n] <= c_data;
                    
                    if(n[0] == 1)
                        dr0[n] <= 10'b1000000000 | c_data;
                end
                else if(c_data < 256) begin
                    if(n[0] == 1)
                        dr0[n] <= (c_data - 128);
                    
                    if(n[0] == 0)
                        dr0[n] <= 10'b1000000000 | (c_data - 128);
                end
                else if(c_data < 384) begin
                    if(n[0] == 0)
                        dr0[n] <= (c_data - 256);
                    
                    if(n[0] == 1) begin
                        if(c_data[0] == 0)
                            dr0[n] <= 10'b1000000000 | (c_data - 255);
                        else
                            dr0[n] <= 10'b1000000000 | (c_data - 257);
                    end
                end
                else if(c_data < 512) begin
                    if(n[0] == 1)
                        dr0[n] <= (c_data - 384);
                    
                    if(n[0] == 0) begin
                        if(c_data[0] == 0)
                            dr0[n] <= 10'b1000000000 | (c_data - 383);
                        else
                            dr0[n] <= 10'b1000000000 | (c_data - 385);
                    end
                end
                else if(c_data > 514 && c_data < 643)
                    dr0[n] <= 9'b110000000 | (c_data - 515);
                else if(c_data > 645 && c_data < 774)
                    dr0[n] <= 9'b100000000 | (c_data - 646);
                else
                    dr0[n] <= 0;
                    
                if((c_data > 7) && (c_data < 264)) begin                                      
                    if(c_data[0] == 0) begin
                        if(n[0] == 0) begin
                            de0[n] <= 1;
                            dw0[n] <= 9'b100000000 | ((c_data-8) >> 1);
                            di0[n] <= NTToutEVEN[1];
                        end
                    
                        if(n[0] == 1) begin
                            de0[n] <= 0;
                            dw0[n] <= 0;
                            di0[n] <= 0;
                        end 
                    end
                    else begin
                        if(n[0] == 1) begin
                            de0[n] <= 1;
                            dw0[n] <= 9'b100000000 | ((c_data-8) >> 1);
                            di0[n] <= NTToutEVEN[1];
                        end
                    
                        if(n[0] == 0) begin
                            de0[n] <= 0;
                            dw0[n] <= 0;
                            di0[n] <= 0;
                        end
                    end
                end
                else if((c_data > 7) && (c_data < 520)) begin
                    if(c_data[0] == 0) begin
                        if(n[0] == 0) begin
                            de0[n] <= 1;
                            dw0[n] <= 9'b110000000 | ((c_data - 264) >> 1);
                            di0[n] <= NTToutEVEN[1];
                        end
                    
                        if(n[0] == 1) begin
                            de0[n] <= 0;
                            dw0[n] <= 0;
                            di0[n] <= 0;
                        end 
                    end
                    else begin
                        if(n[0] == 1) begin
                            de0[n] <= 1;
                            dw0[n] <= 9'b110000000 | ((c_data - 264) >> 1);
                            di0[n] <= NTToutEVEN[1];
                        end
                    
                        if(n[0] == 0) begin
                            de0[n] <= 0;
                            dw0[n] <= 0;
                            di0[n] <= 0;
                        end 
                    end
                end
                else if((c_data > 7) && (c_data < 584)) begin
                    if(n[0] == 0) begin
                        de0[n] <= 1;
                        dw0[n] <= (((c_data - 520) << 1) + 1);
                        di0[n] <= ADDout[0];
                    end
                    
                    if(n[0] == 1) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end
                end
                else if((c_data > 7) && (c_data < 648)) begin
                    if(n[0] == 1) begin
                        de0[n] <= 1;
                        dw0[n] <= (((c_data - 584) << 1) + 1);
                        di0[n] <= ADDout[0];
                    end
                    
                    if(n[0] == 0) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end
                end
                else if((c_data > 653) && (c_data < 718)) begin
                    if(n[0] == 0) begin
                        de0[n] <= 1;
                        dw0[n] <= ((c_data - 654) << 1);
                        di0[n] <= NTToutEVEN[0];
                    end
                    
                    if(n[0] == 1) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end
                end
                else if((c_data > 717) && (c_data < 782)) begin
                    if(n[0] == 1) begin
                        de0[n] <= 1;
                        dw0[n] <= ((c_data - 718) << 1);
                        di0[n] <= NTToutEVEN[0];
                    end
                    
                    if(n[0] == 0) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end
                end
                else begin
                    de0[n] <= 0;
                    dw0[n] <= 0;
                    di0[n] <= 0;
                end 
            end
            else if(curr_state == `OP_COEFMUL2) begin
                if(c_data < (`RING_SIZE >> (`PE_DEPTH + 1))) begin
                    if(n[0] == 0)
                        dr0[n] <= c_data;
                    
                    if(n[0] == 1)
                        dr0[n] <= (1'b1 << (`BRAM_DEPTH - 1)) | c_data;
                end
                else if(c_data < (`RING_SIZE >> `PE_DEPTH)) begin
                    if(n[0] == 1)
                        dr0[n] <= c_data - (`RING_SIZE >> (`PE_DEPTH + 1));
                    
                    if(n[0] == 0)
                        dr0[n] <= (1'b1 << (`BRAM_DEPTH - 1)) | (c_data - (`RING_SIZE >> (`PE_DEPTH + 1)));
                end
                else if(c_data < (`RING_SIZE >> `PE_DEPTH) + (`RING_SIZE >> `PE_DEPTH + 1)) begin    
                    if(n[0] == 0)
                        dr0[n] <= c_data - (`RING_SIZE >> `PE_DEPTH);
                    
                    if(n[0] == 1)
                        dr0[n] <= (1'b1 << (`BRAM_DEPTH - 1)) | (c_data - (`RING_SIZE >> `PE_DEPTH)); 
                end
                else if(c_data < ((`RING_SIZE >> `PE_DEPTH) << 1)) begin   
                    if(n[0] == 1)
                        dr0[n] <= c_data - (`RING_SIZE >> `PE_DEPTH) - (`RING_SIZE >> `PE_DEPTH + 1);
                    
                    if(n[0] == 0)
                        dr0[n] <= (1'b1 << (`BRAM_DEPTH - 1)) | ((c_data - (`RING_SIZE >> `PE_DEPTH)) - (`RING_SIZE >> `PE_DEPTH + 1)); 
                end
                else if((c_data >= ((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> (`PE_DEPTH + 1))) && (c_data < ((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH))) 
                    dr0[n] <= (1'b1 << (`BRAM_DEPTH - 2)) | (c_data - ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> (`PE_DEPTH + 1)));                
                else if((c_data >= ((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> (`PE_DEPTH + 1))) && c_data < (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + (`RING_SIZE >> `PE_DEPTH + 1))) 
                    dr0[n] <= (2'b11 << (`BRAM_DEPTH - 3)) | (c_data - ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> `PE_DEPTH));    
                else
                    dr0[n] <= 0;
                    
                if((c_data > 7) && (c_data < ((`RING_SIZE >> (`PE_DEPTH + 1)) + 8))) begin    
                    if(n[0] == 0) begin
                        de0[n] <= 1;
                        dw0[n] <= (1'b1 << (`BRAM_DEPTH - 2)) | (c_data-8);
                        di0[n] <= NTToutEVEN[n+1];
                    end
                    
                    if(n[0] == 1) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end                                        
                end
                else if((c_data > 7) && (c_data < ((`RING_SIZE >> `PE_DEPTH) + 8))) begin
                    if(n[0] == 1) begin
                        de0[n] <= 1;
                        dw0[n] <= (1'b1 << (`BRAM_DEPTH - 2)) | (c_data - (`RING_SIZE >> (`PE_DEPTH + 1)) - 8);
                        di0[n] <= NTToutEVEN[n];
                    end
                    
                    if(n[0] == 0) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end                    
                end
                else if (c_data > 7 && (c_data < ((ring_size >> `PE_DEPTH) + (ring_size >> `PE_DEPTH + 1) + 8))) begin
                    if(n[0] == 0) begin
                        de0[n] <= 1;
                        dw0[n] <= (2'b11 << (`BRAM_DEPTH - 3)) | (c_data - (`RING_SIZE >> `PE_DEPTH) - 8);
                        di0[n] <= NTToutEVEN[n+1];
                    end
                    
                    if(n[0] == 1) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end 
                end
                else if (c_data > 7 && (c_data < ((`RING_SIZE >> `PE_DEPTH) << 1) + 8)) begin
                    if(n[0] == 1) begin
                        de0[n] <= 1;
                        dw0[n] <= (2'b11 << (`BRAM_DEPTH - 3)) | (c_data - (ring_size >> `PE_DEPTH) - (ring_size >> `PE_DEPTH + 1) - 8);
                        di0[n] <= NTToutEVEN[n];
                    end
                    
                    if(n[0] == 0) begin
                        de0[n] <= 0;
                        dw0[n] <= 0;
                        di0[n] <= 0;
                    end 
                end
                else if((c_data >= (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> (`PE_DEPTH + 1)) + 5)) && (c_data < (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + 5))) begin                    
                    if(n[1:0] == 2'b10) begin
                        de0[n] <= 1;
                        dw0[n] <= (c_data -  ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> (`PE_DEPTH + 1)) - 5);
                        di0[n] <= ADDout[(n>>1)-1];
                    end
                    
                    if(n[1:0] == 2'b11) begin
                        de0[n] <= 1;
                        dw0[n] <= (c_data -  ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> (`PE_DEPTH + 1)) - 5);
                        di0[n] <= ADDout[(n>>1)];
                    end
                end
                else if((c_data >= (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + 8)) && (c_data < (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + (ring_size >> `PE_DEPTH + 1) + 8))) begin                    
                    if(n[1:0] == 2'b00) begin
                        de0[n] <= 1;
                        dw0[n] <= (c_data -  ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> `PE_DEPTH) - 8);
                        di0[n] <= NTToutEVEN[n];
                    end
                    
                    if(n[1:0] == 2'b01) begin
                        de0[n] <= 1;
                        dw0[n] <= (c_data -  ((`RING_SIZE >> `PE_DEPTH) << 1) - (`RING_SIZE >> `PE_DEPTH) - 8);
                        di0[n] <= NTToutEVEN[(n+1)];
                    end
                end
                else begin
                    de0[n] <= 0;
                    dw0[n] <= 0;
                    di0[n] <= 0;
                end                
            end
            else if(curr_state == `OP_SEND_DATA0) begin
                di0[n] <= 0;
                dw0[n] <= 0;
                de0[n] <= 0;                
                dr0[n] <= c_out;
            end          
            else begin
                di0[n] <= 0;
                dw0[n] <= 0;
                de0[n] <= 0;
                dr0[n] <= 0;
            end
    end
end

// ntt unit
integer ntt_loop = 0;

always @(posedge clk) begin
    for(ntt_loop = 0; ntt_loop<`PE; ntt_loop=ntt_loop+1) begin
        if(reset) begin
            NTTin0[ntt_loop] <= 32'd0;
            NTTin1[ntt_loop] <= 32'd0;
            MULin [ntt_loop] <= 32'd0;
        end
        else begin
            if(((curr_state == `OP_NTT)) || (curr_state == `OP_INTT)) begin
                NTTin0[ntt_loop] <= do0[(2*ntt_loop)];
                NTTin1[ntt_loop] <= do0[(2*ntt_loop)+1];
                MULin [ntt_loop] <= to[ntt_loop];
            end            
            else if((curr_state == `OP_POST) && c_data < ((ring_size >> (`PE_DEPTH + 1)) + 2)) begin
                NTTin0[ntt_loop] <= do0[(2*ntt_loop)];
                NTTin1[ntt_loop] <= {`PE{32'h00000000}};
                MULin [ntt_loop] <= {`PE{n_inv}};
            end
            else if((curr_state == `OP_POST) && c_data < ((ring_size >> (`PE_DEPTH)) + 2)) begin
                NTTin0[ntt_loop] <= do0[(2*ntt_loop)+1];
                NTTin1[ntt_loop] <= {`PE{32'h00000000}};
                MULin [ntt_loop] <= {`PE{n_inv}};
            end
            else if(curr_state == `OP_COEFMUL) begin
                NTTin0[ntt_loop] <= do0[(2*ntt_loop)];
                NTTin1[ntt_loop] <= {`PE{32'h00000000}};
                MULin [ntt_loop] <= do0[(2*ntt_loop)+1];
            end
            else if((curr_state == `OP_COEFMUL1) && (c_data < 514)) begin
                NTTin0[ntt_loop] <= do0[0];
                NTTin1[ntt_loop] <= {`PE{32'h00000000}};
                MULin [ntt_loop] <= do0[1];
            end
            else if((curr_state == `OP_COEFMUL1) && (c_data < 778)) begin
                NTTin0[ntt_loop] <= do0[0];
                NTTin1[ntt_loop] <= do0[1];
                
                if(c_data < 645)
                    MULin [ntt_loop] <= {`PE{32'h00000000}};
                else
                    MULin [ntt_loop] <= to[ntt_loop]; 
            end
            else if((curr_state == `OP_COEFMUL2) && (c_data < ((`RING_SIZE >> `PE_DEPTH) + 2))) begin
                NTTin0[ntt_loop] <= do0[(2*ntt_loop)];
                NTTin1[ntt_loop] <= {`PE{32'h00000000}};
                if(ntt_loop[0] == 1'b0)                     
                    MULin [ntt_loop] <= do0[((2*ntt_loop)+3)];                
                else 
                    MULin [ntt_loop] <= do0[((2*ntt_loop)-1)];
            end
            else if((curr_state == `OP_COEFMUL2) && (c_data < ((`RING_SIZE >> `PE_DEPTH) << 1) + 2)) begin
                NTTin0[ntt_loop] <= do0[(2*ntt_loop)];
                NTTin1[ntt_loop] <= {`PE{32'h00000000}};
                MULin [ntt_loop] <= do0[(2*ntt_loop)+1];                                
            end
            else if((curr_state == `OP_COEFMUL2) && (c_data < (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + (`RING_SIZE >> (`PE_DEPTH + 1)) + 2))) begin
                if(ntt_loop[0] == 1'b0) begin
                    NTTin0[ntt_loop] <= do0[(2*ntt_loop)];
                    NTTin1[ntt_loop] <= do0[(2*(ntt_loop+1))];
                end
                else begin
                    NTTin0[ntt_loop] <= do0[(2*ntt_loop)-1];
                    NTTin1[ntt_loop] <= do0[((2*ntt_loop)+1)];
                end
                
                if(c_data < (((`RING_SIZE >> `PE_DEPTH) << 1) + (`RING_SIZE >> `PE_DEPTH) + 2))
                    MULin [ntt_loop] <= {`PE{32'h00000000}};
                else
                    MULin [ntt_loop] <= to[ntt_loop];                 
            end                        
            else begin
                NTTin0[ntt_loop] <= NTTin0[ntt_loop];
                NTTin1[ntt_loop] <= NTTin1[ntt_loop];
                MULin [ntt_loop] <= MULin [ntt_loop];
            end
        end
    end
end

// ---------------------------------------------------------------- DONE, DOUT

// done
always @(posedge clk) begin
    if(reset)
        done <= 0;
    else
        done <= ((curr_state == `OP_SEND_DATA0) && (c_out2 == 0)) ? 1'b1 : 1'b0;
end

// dout
always @(posedge clk) begin
    if(curr_state == `OP_SEND_DATA0 && c_out2 >= 1) begin
        dout0 <= do0[c_out2-1];
    end
    else
        dout0 <= 0;   
end

// ---------------------------------------------------------------- CONTROL UNIT

AddressGenerator ag(clk,reset,
                    start_ntt_1p,
                    dsp,
                    ring_size, ring_depth, limit,
                    raddr0,
                    waddr0,waddr1,
                    wen0  ,wen1  ,
                    brsel0,brsel1,
                    brselen0,brselen1,
                    brscramble,
                    stage_count,
                    raddr_tw, nttdone
                    );

// ---------------------------------------------------------------- BRAMs

generate
genvar k;

    for(k=0; k<`PE ;k=k+1) begin: BRAM_GEN_BLOCK
        BRAM #(32,`DATA_SIZE,`BRAM_DEPTH)   bd00(clk,de0[2*k],dw0[2*k],di0[2*k],dr0[2*k],do0[2*k]);
        BRAM #(32,`DATA_SIZE,`BRAM_DEPTH)   bd01(clk,de0[(2*k)+1],dw0[(2*k)+1],di0[(2*k)+1],dr0[(2*k)+1],do0[(2*k)+1]);
        BRAM #(32,`DATA_SIZE_TW,`TW_DEPTH)  bt00(clk,te[k],tw[k],ti[k],tr[k],to[k]);
    end
endgenerate

// ---------------------------------------------------------------- PUs (NTT2 units)

generate
    genvar j;
   
    for(j=0; j<`PE ;j=j+1) begin: BTFLY_GEN_BLOCK
        butterfly btfu(NTTin0[j],NTTin1[j],
                       MULin[j],  
                       q,
                       conf, dsp,
                       clk,reset,  
                       NTToutEVEN[2*j+0], NTToutEVEN[2*j+1],MULout[2*j+0],
                       MULout[2*j+1], ADDout[j], SUBout[j]);
    end
endgenerate

// ----------------------------------------------------------------

endmodule
