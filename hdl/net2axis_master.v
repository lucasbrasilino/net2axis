`timescale 1ns/1ps
/**********************************************************************************
 * net2axis verilog module                                                        *
 *                                                                                *
 * ISC License (ISC)                                                              *
 *                                                                                *
 * Copyright 2018-2021 Lucas Brasilino <lucas.brasilino@gmail.com>                *
 *                                                                                *
 * Refer to LICENSE file.                                                         *
 **********************************************************************************/

module net2axis_master #(
        parameter           INPUTFILE           = "",
        parameter           INPUTFILE_LEN       = 0,
        parameter           TDATA_WIDTH         = 32,
        parameter           INITIAL_DELAY       = 0,
        parameter           INTER_PKT_DELAY     = 0
        ) (
        input wire        ACLK,
        input wire        ARESETN,

        input  wire                             ENABLE,
        input  wire                             SOFT_RESET,
        output wire                             EOS,
        output wire                             DELAY,
        output wire                             M_AXIS_TVALID,
        output wire  [TDATA_WIDTH-1 : 0]        M_AXIS_TDATA,
        output wire  [(TDATA_WIDTH/8)-1 : 0]    M_AXIS_TKEEP,
        output wire                             M_AXIS_TLAST,
        input wire                              M_AXIS_TREADY
        );

    `include "net2axis.vh"

    localparam  TKEEP_WIDTH = TDATA_WIDTH/8;
    localparam  TLAST_WIDTH = 4;
    localparam  MEM_WIDTH = TDATA_WIDTH + TKEEP_WIDTH + TLAST_WIDTH;
    localparam                      ST_RESET            = 0;
    localparam                      ST_IDLE             = 1;
    localparam                      ST_ENABLED          = 2;
    localparam                      ST_SOFT_RESET       = 3;
    localparam                      ST_DELAY = 4;         
 
    localparam                      STATE_WIDTH = clog2(ST_DELAY+1);

    localparam  COUNTER_WIDTH = (INITIAL_DELAY > INTER_PKT_DELAY) ? clog2(INITIAL_DELAY) : clog2(INTER_PKT_DELAY);
    reg  [ 0 : MEM_WIDTH-1]             mem [ 0 : INPUTFILE_LEN-1];
    wire [ 0 : MEM_WIDTH-1]             mem_curr; 
    reg  [ clog2(INPUTFILE_LEN-1) : 0 ] mem_ptr, mem_ptr_next;
    wire                                mem_ptr_last;
    reg  [COUNTER_WIDTH-1 : 0]      delay_counter;
    wire [COUNTER_WIDTH-1 : 0]      delay_counter_next;
    wire                            delay_counter_exp;
    wire                            delay_has_delay;
    reg                             delay_en;
 
    reg [STATE_WIDTH-1:0]            state, state_next, state_idle_decode_next;
    wire [TDATA_WIDTH-1 : 0]        tdata;
    wire [TKEEP_WIDTH-1 : 0]        tkeep;
    wire                             tvalid;
    wire                             tlast;

    assign mem_curr           =     mem[mem_ptr];
    assign mem_ptr_last       =     (mem_ptr == INPUTFILE_LEN-1);
    assign delay_counter_next =     delay_counter - 1;
    assign M_AXIS_TDATA       =     tdata;
    assign M_AXIS_TKEEP       =     tkeep;
    assign M_AXIS_TLAST       =     tlast;
    assign M_AXIS_TVALID      =     tvalid;
    assign EOS                =     ENABLE && tlast && (mem_ptr == INPUTFILE_LEN-1);
    assign DELAY              =     (state == ST_DELAY);

    assign delay_has_delay = ((INITIAL_DELAY != 0) || (INTER_PKT_DELAY != 0)) && delay_en;
    assign delay_counter_exp  =     (delay_counter == 0);

    assign tkeep = mem_curr[TDATA_WIDTH  +: TKEEP_WIDTH];
    assign tlast = (mem_curr[TDATA_WIDTH+TKEEP_WIDTH +: 4] == 1) ? 1'b1 : 1'b0;

    generate
        genvar i;
        for (i = 0; i < TDATA_WIDTH; i = i + 8) begin
            assign tdata[i +: 8] = mem_curr[ i +: 8];
        end
    endgenerate

    initial begin
        $timeformat(-9, 2, " ns", 20);
        if (INPUTFILE == "") begin
            $display("net2axis_master: File opening error: inputfile NULL!");
            $finish;
        end
        else begin
            $readmemh(INPUTFILE,mem);
        end
    end

    always @(posedge ARESETN) $display("[%0t] net2axis_master: Reset deasserted", $time);

    always @(posedge ACLK) begin
        if (~ARESETN) begin
            delay_counter <= INITIAL_DELAY;
        end else begin
            case (state)
                ST_SOFT_RESET: delay_counter <= INITIAL_DELAY;
                ST_ENABLED: delay_counter <= INTER_PKT_DELAY;
                ST_DELAY: delay_counter <= delay_counter - 1'b0;
            endcase
        end
    end

    always @(*) begin
        casez ({ENABLE,M_AXIS_TREADY,mem_ptr_last})
            3'b0??, 3'b100, 3'b101: mem_ptr_next = mem_ptr;
            3'b110: mem_ptr_next = mem_ptr + 1'b1;
            3'b111: mem_ptr_next = 0;
        endcase
    end
    assign tvalid = (state == ST_ENABLED) && ENABLE;
    always @(posedge ACLK) begin
        if (~ARESETN) begin
            mem_ptr <= 0;
        end else begin
        case (state)
        ST_SOFT_RESET: mem_ptr <= 0;
        ST_ENABLED: mem_ptr <= mem_ptr_next;
        endcase
        end
    end

    /* decode next state when in ST_IDLE */
    always @(*) begin 
        casez ({ENABLE,delay_has_delay})
            2'b0? : state_idle_decode_next = ST_IDLE;
            2'b10 : state_idle_decode_next = ST_ENABLED;
            2'b11 : state_idle_decode_next = ST_DELAY;
        endcase
    end
    always @(*) begin : STATE_NEXT
        state_next = state;
        case (state)
        ST_RESET: state_next = ST_IDLE;
        ST_IDLE: state_next = state_idle_decode_next;
        ST_ENABLED: begin
            if (~tlast) begin
                state_next = ST_ENABLED;
            end
            if (tlast && delay_has_delay) begin
                state_next = ST_DELAY;
            end else
            state_next = ST_ENABLED;
        end
        ST_SOFT_RESET: state_next = ST_IDLE;
        ST_DELAY: state_next = (delay_counter == 0) ? ST_ENABLED : ST_DELAY;
        endcase
    end//always

    always @(posedge ACLK) begin : STATE
        if (~ARESETN)
            state <= ST_RESET;
        else begin
           if (SOFT_RESET) 
           state <= ST_SOFT_RESET;
           else
            state <= state_next; 
        end
    end

endmodule
