`include "defines.v"

// control unit

/*
This module generates necessary address/control signals for NTT operations
*/

module AddressGenerator (input             clk,reset,
                         input      [2:0]  start_ntt_1p,
                         input      [1:0]  delay,
                         input      [11:0] size,
                         input      [3:0]  depth, limit,
                         output reg [`BRAM_DEPTH-1:0]  raddr0,
                         output reg [`BRAM_DEPTH-1:0]  waddr0,waddr1,
                         output reg        wen0  ,wen1  ,
                         output reg        brsel0,brsel1,
                         output reg        brselen0,brselen1,
                         output reg [2*`PE*(`PE_DEPTH+1)-1:0] brscramble0,
                         output reg [3:0]  stage_count,
                         output reg [`TW_DEPTH-1:0] raddr_tw,
                         output reg done);

// ---------------------------------------------------------------------------
/*
c_stage --> counter for stage
c_loop  --> counter for butterfly operations in each stage
c_tw    --> counter for twiddle factor reading in each stage
c_wait  --> counter for waiting between stages (This is necessary since input of one stage is the output of previous stage)
*/

// Control signals
reg [3:0] c_stage_limit;
reg [`BRAM_DEPTH-1:0] c_loop_limit, c_loop_limit2;

reg [3:0] c_stage;
reg [`BRAM_DEPTH-1:0] c_loop, c_loop2;
reg [`TW_DEPTH-1:0]     c_tw;

reg [3:0] c_wait_limit;
reg [3:0] c_wait;
reg [2*`PE*(`PE_DEPTH+1)-1:0] brscramble;

reg [2:0] curr_state,next_state;
reg       intt;
reg ntt2;

always @(posedge clk) begin
    if(reset)
        curr_state <= 0;
    else
        curr_state <= next_state;
end

always @(posedge clk) begin
    if(reset)
        intt <= 0;
    else begin 
        if(start_ntt_1p == 3'b100 || start_ntt_1p == 3'b101)
            intt <= 1'b0;
        else if(start_ntt_1p == 3'b111)
            intt <= 1'b1;
        else
            intt <= intt;
    end    
end

always @(posedge clk) begin
    if(reset)
        ntt2 <= 0;
    else begin
        if(start_ntt_1p == 3'b101)
            ntt2 <= 1;
        else if(start_ntt_1p == 3'b100 || start_ntt_1p == 3'b111 || start_ntt_1p == 3'b110)
            ntt2 <= 0;    
        else
            ntt2 <= ntt2;    
    end
end

always @(*) begin
    case(curr_state)
	// ---------------------------------------- IDLE
	`CU_IDLE: begin
		if     (start_ntt_1p == 3'b100 || start_ntt_1p == 3'b101) next_state = `CU_NTT1P_OP;
		else if(start_ntt_1p == 3'b111) next_state = `CU_INTT1P_OP;
		else                  next_state = `CU_IDLE;
	end
	// ---------------------------------------- NTT (1 POL)
	`CU_NTT1P_OP: begin
	   next_state = (c_loop == c_loop_limit) ? `CU_NTT1P_WAIT : `CU_NTT1P_OP;
	end
	`CU_NTT1P_WAIT: begin
        if(c_stage == c_stage_limit+1) next_state = `CU_IDLE;
        else if((c_stage == c_stage_limit) && (intt == 1'b0))
            next_state = (c_wait == c_wait_limit) ? `CU_NTT1P_LAST : `CU_NTT1P_WAIT;
        else if((c_stage == c_stage_limit) && (intt == 1'b1))
            next_state = (c_wait == c_wait_limit) ? `CU_INTT1P_LAST : `CU_NTT1P_WAIT;
        else if((intt == 1'b0))
            next_state = (c_wait == c_wait_limit) ? `CU_NTT1P_OP : `CU_NTT1P_WAIT;
        else
            next_state = (c_wait == c_wait_limit) ? `CU_INTT1P_OP : `CU_NTT1P_WAIT;
	end
	`CU_NTT1P_LAST: begin
        next_state = (c_loop == c_loop_limit) ? `CU_NTT1P_WAIT : `CU_NTT1P_OP;
	end
	`CU_INTT1P_OP: begin
	   next_state = (c_loop == c_loop_limit) ? `CU_NTT1P_WAIT : `CU_INTT1P_OP;
	end
	`CU_INTT1P_LAST: begin
        next_state = (c_loop == c_loop_limit) ? `CU_NTT1P_WAIT : `CU_INTT1P_OP;
	end
    default: begin
        next_state = `CU_IDLE;
    end
    endcase
end

// ---------------------------------------------------------------------------
// Control operations

always @(posedge clk) begin
    if(reset) begin
        c_wait_limit <= 0;
        c_wait       <= 0;
    end
    else begin
        c_wait_limit <= 4'd15;

        if(curr_state == `CU_NTT1P_WAIT)
            c_wait <= (c_wait < c_wait_limit) ? (c_wait + 1) : 0;
        else
            c_wait <= 0;
    end
end

// limit values (NTT)
always @(posedge clk) begin
    if(reset) begin
        {c_stage_limit,c_loop_limit,c_loop_limit2} <= {4'd000,9'd000,9'd000};
    end
    else begin
        if(start_ntt_1p) begin
            if(start_ntt_1p == 3'b111)
                c_stage_limit <= (depth - 1);
            else            
                c_stage_limit <= (limit - 1);
            
            c_loop_limit  <= ((size >> (`PE_DEPTH+1))-1);            
            c_loop_limit2 <= ((size >> (`PE_DEPTH+c_stage+1)) - 1);
        end
        else begin
            c_loop_limit <= c_loop_limit;
            
            c_stage_limit <= c_stage_limit;
            
            if((c_stage < (depth -`PE_DEPTH-1)) && ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST)))
                c_loop_limit2 <= ((size >> (`PE_DEPTH+c_stage+1)) - 1);
            else if((((curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST))))
                c_loop_limit2 <= ((size >> (c_stage_limit - c_stage+`PE_DEPTH+1)) - 1);
            else
                c_loop_limit2 <= c_loop_limit2; 
        end
    end
end

// counters (NTT)
always @(posedge clk) begin
    if(reset) begin
        {c_stage,c_loop,c_tw,c_loop2} <= {4'd000,9'd000,11'd000,9'd000};
    end
    else begin
        if(start_ntt_1p) begin            
            if(start_ntt_1p == 3'b111 && limit == 3'b111)
                c_stage <= 1;
            else
                c_stage <= 0;
            
            c_loop <= 0;
            c_loop2 <= 0;
            c_tw <= 0;
        end
        else begin
            // operation
            // ------------------------------- c_stage
            if(limit == 3'b111 && c_stage == c_stage_limit + 1)
                c_stage <= 1;
            else if(c_stage == c_stage_limit + 1)
                c_stage <= 0;
            else if((c_loop == c_loop_limit) && (curr_state != `CU_IDLE))
                c_stage <= c_stage + 1;
            else
                c_stage <= c_stage;

            // ------------------------------- c_loop                     
            if(c_stage <= c_stage_limit) begin
                if(c_loop == c_loop_limit) begin
                    c_loop <= 0;
                end
                else if((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST) || (curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST)) begin
                    c_loop <= c_loop + 1;
                end
                else begin
                    c_loop <= c_loop;
                end
            end
            else begin
                c_loop <= c_loop;
            end
            
            if((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST)) begin
                if(c_loop2 == c_loop_limit2)
                    c_loop2 <= 0;                
                else if((c_stage >= (depth -`PE_DEPTH-1)) && ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST)))
                    c_loop2 <= 0;
                else
                    c_loop2 <= c_loop2 + 1;
                end
            else
                c_loop2 <= c_loop2;            
            
            if(((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST) || (curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST)) && (c_loop != c_loop_limit)) begin
                if(((c_stage >= (depth -`PE_DEPTH-1)) && ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST))) || ((c_stage <= `PE_DEPTH) && ((curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST))))
                    c_tw <= c_tw + 1;                
                else if ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST))begin
                    if(c_loop2 == c_loop_limit2)
                        c_tw <= c_tw + 1;
                    else
                        c_tw <= c_tw;
                end
                else begin
                    if((c_loop & (`MAX >> (8 - c_stage + `PE_DEPTH))) == {c_loop_limit2[`BRAM_DEPTH-2:0],1'b1})
                        c_tw <= c_tw + 1;
                    else if(c_stage == c_stage_limit)
                        c_tw <= c_tw;
                    else if(c_loop[0] == 0)
                        c_tw <= c_tw + 1;                    
                    else 
                        c_tw <= c_tw -1;                  
                end                    
            end
            else if((curr_state == `CU_NTT1P_WAIT) && (c_wait == c_wait_limit)) begin
                c_tw <= c_tw + 1;
            end
            else begin
                c_tw <= c_tw;
            end
        end
    end
end

// --------------------------------------------------------------------------- signals

reg [`BRAM_DEPTH-2:0]  raddr;
reg [`BRAM_DEPTH-2:0] waddre,waddro;
reg       wen;
reg       brsel;
reg       brselen;

// --------------------------------------------------------------------------- raddr (c_loop)

always @(posedge clk) begin
    if(start_ntt_1p) begin
        raddr <= 0;
    end
    else if((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST) || (curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST)) begin  
        if((c_stage < (depth-`PE_DEPTH-1)) && ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST))) begin
            if(~c_loop[0])
                raddr <= (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage+1))+1)) << ((depth-`PE_DEPTH-1) - (c_stage+1)));
            else
                raddr <= (1 << ((depth-`PE_DEPTH-1) - (c_stage+1))) + (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage+1))+1)) << ((depth-`PE_DEPTH-1) - (c_stage+1)));
        end
        else if((c_stage >= `PE_DEPTH) && (c_stage != c_stage_limit) && ((curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST))) begin
            if(~c_loop[0])
                raddr <= (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage))+1)) << ((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage)));
            else
                raddr <= (1 << ((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage))) + (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage))+1)) << ((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage)));
        end
        else
            raddr <= c_loop;
    end       
    else 
        raddr <= 0;      
end

// --------------------------------------------------------------------------- waddr,wen,brsel (c_loop)

always @(posedge clk) begin
    if(start_ntt_1p) begin
        waddre      <= 0;
        waddro      <= 0;
        wen         <= 0;
        brsel       <= 0;
        brselen     <= 0;
    end
    else if ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST) || (curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST))begin    
        wen         <= 1;
        brsel       <= c_loop[0];
        brselen     <= 1;
            
        if((c_stage < (depth-`PE_DEPTH-1)) && (c_stage != 6 || limit != 3'b111) && ((curr_state == `CU_NTT1P_OP) || (curr_state == `CU_NTT1P_LAST))) begin               
            waddre <= (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage+1))+1)) << ((depth-`PE_DEPTH-1) - (c_stage+1)));
            waddro <= (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage+1))+1)) << ((depth-`PE_DEPTH-1) - (c_stage+1))) + (1 << ((depth-`PE_DEPTH-1) - (c_stage+1)));
        end
        else if((c_stage >= `PE_DEPTH) && (c_stage != c_stage_limit) && ((curr_state == `CU_INTT1P_OP) || (curr_state == `CU_INTT1P_LAST))) begin               
            waddre <= (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage))+1)) << ((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage)));
            waddro <= (c_loop >> 1) + ((c_loop >> (((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage))+1)) << ((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage))) + (1 << ((depth-`PE_DEPTH-1) - (c_stage_limit - c_stage)));
        end
        else begin
            waddre <= (c_loop);
            waddro <= (c_loop);
        end            
    end
    else begin
        waddre     <= 0;
        waddro     <= 0;
        wen        <= 0;
        brsel      <= 0;
        brselen    <= 0;
    end
end

// --------------------------------------------------------------------------- brscrambled

wire [`PE_DEPTH:0] brscrambled_temp;
wire [`PE_DEPTH:0] brscrambled_temp2;
wire [`PE_DEPTH:0] brscrambled_temp3;
wire [`PE_DEPTH:0] brscrambled_temp4;
wire [`PE_DEPTH:0] brscrambled_temp5;
wire [`PE_DEPTH:0] brscrambled_temp6;
assign brscrambled_temp  = (`PE >> (c_stage-(depth- `PE_DEPTH-1)));
assign brscrambled_temp2 = (`PE_DEPTH - (c_stage-(depth-`PE_DEPTH-1)));
assign brscrambled_temp3 = ((`PE_DEPTH+1) - (c_stage-(depth-`PE_DEPTH-1)));

assign brscrambled_temp4  = (`PE >> ((`PE_DEPTH - 1) - c_stage));
assign brscrambled_temp5 = (`PE_DEPTH - ((`PE_DEPTH - 1) - c_stage));
assign brscrambled_temp6 = ((`PE_DEPTH+1) - ((`PE_DEPTH - 1) - c_stage));

always @(posedge clk) begin: B_BLOCK
    integer n;
    for(n=0; n < (2*`PE); n=n+1) begin: LOOP_1
        if((c_stage >= (depth-`PE_DEPTH-1) && (curr_state == `CU_NTT1P_OP || curr_state == `CU_NTT1P_LAST))) begin
            brscramble[(`PE_DEPTH+1)*n+:(`PE_DEPTH+1)] <= (brscrambled_temp*n[0]) +
                                                              (((n>>1)<<1) & (brscrambled_temp-1)) +
                                                              ((n>>(brscrambled_temp2+1))<<(brscrambled_temp3)) +
                                                              ((n>>brscrambled_temp2) & 1);
        end
        else if((c_stage <= `PE_DEPTH && (curr_state == `CU_INTT1P_OP || curr_state == `CU_INTT1P_LAST))) begin
            brscramble[(`PE_DEPTH+1)*n+:(`PE_DEPTH+1)] <= (brscrambled_temp4*n[0]) +
                                                              (((n>>1)<<1) & (brscrambled_temp4-1)) +
                                                              ((n>>(brscrambled_temp5+1))<<(brscrambled_temp6)) +
                                                              ((n>>brscrambled_temp5) & 1);
        end
        else begin
            brscramble[(`PE_DEPTH+1)*n+:(`PE_DEPTH+1)] <= 0;
        end
    end
end

// --------------------------------------------------------------------------- outputs (raddr_tw)
// raddr (tw)

reg[`TW_DEPTH:0] twd;

always @(posedge clk) begin
    twd <= c_tw;
    raddr_tw  <= twd;
end

// --------------------------------------------------------------------------- outputs (data brams -- read)
// raddr
always @(posedge clk) begin
    raddr0 <= {ntt2,raddr};
end

// --------------------------------------------------------------------------- outputs (DELAYS)

// brascambled
wire [2*`PE*(`PE_DEPTH+1)-1:0] brscramble_w;

wire [2:0] sel, sel2;

assign sel = {1'b0,delay} + 1;
assign sel2 = sel + 1;

ShiftReg #(.DATA(2*`PE*(`PE_DEPTH+1))) sr99(clk,reset,sel,brscramble,brscramble_w);

always @(*) begin
    brscramble0 = brscramble_w;
end

wire nttdone, nttdoned;
assign nttdone = ((curr_state == `CU_NTT1P_WAIT) && (c_stage == c_stage_limit+1)) ? 1'b1 : 1'b0;

wire [`BRAM_DEPTH-1:0] waddre_d32;
wire [`BRAM_DEPTH-1:0] waddro_d32;

wire       wene_d32;
wire       weno_d32;
wire       brsele_d32;
wire       brselo_d32;
wire       brselene_d32;
wire       brseleno_d32;
wire [3:0] stage_count0;

// waddr
ShiftReg #(.DATA(`BRAM_DEPTH))sre02(clk,reset,{1'b0,delay},{ntt2,waddre},waddre_d32);
ShiftReg #(.DATA(`BRAM_DEPTH))sro02(clk,reset,sel,{ntt2,waddro},waddro_d32);

// wen
ShiftReg #(.DATA(1))srel2(clk,reset,{1'b0,delay},wen,wene_d32);
ShiftReg #(.DATA(1))srol2(clk,reset,sel,wen,weno_d32);

// brsel
ShiftReg #(.DATA(1))sre22(clk,reset,{1'b0,delay},brsel,brsele_d32);
ShiftReg #(.DATA(1))sro22(clk,reset,sel,brsel,brselo_d32);

// brselen
ShiftReg #(.DATA(1))sree22(clk,reset,{1'b0,delay},brselen,brselene_d32);
ShiftReg #(.DATA(1))sroo22(clk,reset,sel,brselen,brseleno_d32);

// stage count
ShiftReg #(.DATA(4))srs0(clk,reset,sel2,c_stage,stage_count0);
ShiftReg #(.DATA(1))srs1(clk,reset,sel2,nttdone,nttdoned);

always @(posedge clk) begin
    waddr0 <= waddre_d32;
    waddr1 <= waddro_d32;
      
    wen0 <= wene_d32;
    wen1 <= weno_d32;

    brsel0 <= brsele_d32;
    brsel1 <= brselo_d32;

    brselen0 <= brselene_d32;
    brselen1 <= brseleno_d32;
            
    stage_count <= stage_count0;
    done <= nttdoned;   
end

endmodule
