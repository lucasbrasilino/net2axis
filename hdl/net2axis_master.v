`timescale 1ns/1ps
/**********************************************************************************
 * net2axis verilog module                                                        *
 *                                                                                *
 * ISC License (ISC)                                                              *
 *                                                                                *
 * Copyright 2018 Lucas Brasilino <lucas.brasilino@gmail.com>                     *
 *                                                                                *
 * Refer to LICENSE file.                                                         *
 **********************************************************************************/

module net2axis_master #(
        parameter           C_INPUTFILE           = "",
        parameter           C_TDATA_WIDTH         = 32,
        parameter           C_COUNTER_WIDTH       = 32
        ) (
        input wire        ACLK,
        input wire        ARESETN,

        input  wire                             ENABLE,
        input  wire                             START,
        input  wire                             LOOP,
        output wire                             DONE,
        output wire [C_COUNTER_WIDTH-1:0]       WORD_COUNTER,
        output wire [C_COUNTER_WIDTH-1:0]       PKT_COUNTER,
        output wire [C_COUNTER_WIDTH-1:0]       LOOP_COUNTER,
        output wire                             INTER_PKT_DELAY,
        output wire                             END_OF_SEQ,
        output wire                             M_AXIS_TVALID,
        output wire  [C_TDATA_WIDTH-1 : 0]      M_AXIS_TDATA,
        output wire  [(C_TDATA_WIDTH/8)-1 : 0]  M_AXIS_TKEEP,
        output wire                             M_AXIS_TLAST,
        input wire                              M_AXIS_TREADY
        );

    `include "net2axis.vh"

    localparam                      ST_RESET           = 0;
    localparam                      ST_DISABLED        = 1;
    localparam                      ST_WAIT_FOR_START  = 2;
    localparam                      ST_READ_MD         = 3;
    localparam                      ST_DELAY           = 4;
    localparam                      ST_WR              = 5;
    localparam                      ST_POST_WR         = 6;
    localparam                      ST_DONE            = 7;

    localparam                      STATE_WIDTH = clog2(ST_DONE);

    reg  [C_COUNTER_WIDTH-1 : 0]    delay_counter, file_delay_counter;
    wire [C_COUNTER_WIDTH-1 : 0]    delay_counter_next;
    wire                            delay_counter_exp;
    reg                             eof;
    wire                            read_pkt_data_en;
    integer                         errno;
    reg  [1024:0]                   strerr;

    reg [STATE_WIDTH-1:0]            state, state_next, state_resume_next;
    reg                              done;
    reg [C_TDATA_WIDTH-1 : 0]        tdata;
    reg [(C_TDATA_WIDTH/8)-1 : 0]    tkeep;
    reg                              tvalid;
    reg                              tlast;

    integer                         fd, ld;
    reg [7:0]                       md_flag_file;
    wire [7:0]                      md_flag;
    wire                            md_flag_found;
    reg [15:0]                      file_pkt_id, pkt_id;

    assign delay_counter_next =     delay_counter - 1;
    assign DONE               =     done;
    assign M_AXIS_TDATA       =     tdata;
    assign M_AXIS_TKEEP       =     tkeep;
    assign M_AXIS_TLAST       =     tlast;
    assign M_AXIS_TVALID      =     tvalid;
    assign INTER_PKT_DELAY    =     (state == ST_DELAY);

    assign delay_counter_exp  =     (delay_counter == 0);
    assign read_pkt_data_en   =     (delay_counter_exp || (state == ST_WR));
    assign md_flag            =     (state == ST_READ_MD) ? md_flag_file : 8'h00;
    assign md_flag_found      =     (md_flag == `MD_MARKER);

    initial begin
        $timeformat(-9, 2, " ns", 20);
        if (C_INPUTFILE == "") begin
            $display("net2axis_master: File opening error: inputfile NULL!");
            $finish;
        end
        else begin
            fd = $fopen(C_INPUTFILE,"r");
            if (fd == `NULL) begin
                errno = $ferror(fd,strerr);
                $display("net2axis_master: File opening error: errno=%d,strerr=%s",errno,strerr);
                $finish;
            end
        end
    end

    /*
    initial begin
        wait (ARESETN == 1'b1) $display("[%0t] Reset deasserted", $time);
    end*/
    always @(posedge ARESETN) $display("[%0t] Reset deasserted", $time);

    initial begin
        state_resume_next = ST_WAIT_FOR_START;
    end

    always @(posedge ACLK) begin: FILE_OPS
        case (state)
            ST_READ_MD: begin
                ld = $fscanf(fd,"%c: pkt=%d, delay=%d",md_flag_file, file_pkt_id, file_delay_counter);
            end
            ST_WR: begin
                $display("[%0t] entered ST_WR state",$time);
                if (M_AXIS_TREADY) begin
                    ld = $fscanf(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
                    #1 $display("[%0t] %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
                end
            end
        endcase
    end

    always @(posedge ACLK) begin: SAMPLE_FILE_OPS
        case (state)
            ST_READ_MD: begin
                pkt_id <= file_pkt_id;
            end
        endcase
    end

    always @(posedge ACLK) begin: DELAY
        case (state)
            ST_RESET: delay_counter <= 0;
            ST_READ_MD: delay_counter <= file_delay_counter;
            ST_DELAY: delay_counter <= delay_counter_next;
        endcase
    end
    /*
    always @(posedge ACLK) begin : READ_FILE
        if ((fd != `NULL) && ~eof) begin
            if (M_AXIS_TREADY) begin
                if (state == PREP_READ_MD) begin
                    ld = $fscanf(fd,"%c: pkt=%d, delay=%d",md_flag_file, pkt_id, delay_counter_val);
                    //$display("[%0t] Starting packet %0d after delay of %0d clock cycles",$time, pkt_id, delay_counter_val);
                end else
                if (read_pkt_data_en) begin
                    ld = $fscanf(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
                    //#1 $display("[%0t] %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
                end
            end
        end
    end
     */
    always @(posedge ACLK) begin : EOF
        if (~ARESETN)
            eof <= 1'b0;
        else
        if (~eof) begin
            if ($feof(fd)) begin
                eof <= 1'b1;
                /* $display("[%0t] End of file",$time); */
                $fclose(fd);
            end
        end
    end


    always @(*) begin : STATE_NEXT
        tvalid = 1'b0;
        done = 1'b0;
        state_next = state;
        case (state)
            ST_RESET: state_next = ST_DISABLED;
            ST_DISABLED: state_next = (ENABLE) ? state_resume_next : ST_DISABLED;
            ST_WAIT_FOR_START: state_next = (START) ? ST_READ_MD : ST_WAIT_FOR_START;
            ST_READ_MD: state_next = (md_flag_found && (file_delay_counter == 0)) ? ST_WR :
                (md_flag_found) ? ST_DELAY : ST_READ_MD;
            ST_DELAY: state_next = (delay_counter_exp) ? ST_WR : ST_DELAY;
            ST_WR: begin
                tvalid = 1'b1;
                state_next = (M_AXIS_TREADY && tlast) ? ST_POST_WR : ST_WR;
            end
            ST_POST_WR: begin
                done = eof;
                state_next = (eof) ? ST_DONE : ST_POST_WR;
            end
            ST_DONE: done = 1'b1;
        endcase
    end//always
/*
    always @(*) begin : STATE_NEXT
        state_next = state;
        case (state)
            IDLE: state_next = (M_AXIS_TREADY) ? PREP_READ_MD : IDLE;
            PREP_READ_MD: state_next = (M_AXIS_TREADY) ? READ_MD :  IDLE;
            READ_MD: state_next = (md_flag_found) ? DELAY : READ_MD;
            DELAY: state_next = (delay_counter_exp) ? WR : DELAY;
            WR: begin
                tvalid = 1'b1;
                state_next = (M_AXIS_TREADY && tlast) ? POST_WR : WR;
            end
            POST_WR: begin
                done = eof;
                state_next = (eof) ? LAST : IDLE;
            end
            LAST: done = 1'b1;
        endcase
    end//always
*/
    always @(posedge ACLK) begin : STATE
        if (~ARESETN)
            state <= ST_RESET;
        else
            state <= state_next;
    end

endmodule
