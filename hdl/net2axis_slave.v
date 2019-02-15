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

`define MD_MARKER 8'h4d
`define NULL 0
module net2axis_slave
        #(
        parameter           C_OUTPUTFILE           = "",
        parameter           C_TDATA_WIDTH         = 32
        ) (
        input wire                             ACLK,
        input wire                             ARESETN,

        input  wire                            DONE,
        input  wire                            S_AXIS_TVALID,
        input  wire  [C_TDATA_WIDTH-1 : 0]     S_AXIS_TDATA,
        input  wire  [(C_TDATA_WIDTH/8)-1 : 0] S_AXIS_TKEEP,
        input  wire                            S_AXIS_TLAST,
        output wire                            S_AXIS_TREADY
        );

    localparam                      IDLE = 0;
    localparam                      RD = 1;
    localparam                      DONE_TEST = 2;
    localparam                      END = 3;

    localparam                      COUNTER_WIDTH = 16;
    localparam                      STATE_WIDTH = $clog2(END);

    integer                         fd, ld, errno;

    reg [STATE_WIDTH-1:0]             state, state_next;
    wire                              done,done_flag;
    wire [C_TDATA_WIDTH-1 : 0]        tdata;
    wire [(C_TDATA_WIDTH/8)-1 : 0]    tkeep;
    wire                              tvalid;
    wire                              tlast;
    reg                               tready;
    reg  [15:0]                       pkt_id;
    reg                               done_r;

    assign tdata              = S_AXIS_TDATA;
    assign tkeep              = S_AXIS_TKEEP;
    assign tlast              = S_AXIS_TLAST;
    assign tvalid             = S_AXIS_TVALID;
    assign S_AXIS_TREADY      = tready;
    assign done               = DONE;

    initial begin
        $timeformat(-9, 2, " ns", 20);
        if (C_OUTPUTFILE == "") begin
            $display("File opening error: outputfile NULL!");
            $finish;
        end
        else begin
            fd = $fopen(C_OUTPUTFILE,"w");
            if (fd == `NULL) begin
                errno = $ferror(fd);
                $display("File opening error: errno=%d",errno);
                $finish;
            end
        end
    end

    initial begin
        wait (ARESETN == 1'b1) $display("[%0t] Reset deasserted", $time);
    end

    always @(*) begin : STATE_NEXT
        state_next = state;
        tready = 1'b0;
        case (state)
            IDLE: begin
                tready = 1'b1;
                state_next = (S_AXIS_TVALID) ? RD : IDLE;
            end
            RD: begin
                tready = 1'b1;
                state_next = (S_AXIS_TVALID && S_AXIS_TLAST) ? DONE_TEST : RD;
            end
            DONE_TEST: state_next = (done_flag) ? END : IDLE;
            END: state_next = END;
        endcase
    end

    always @(posedge ACLK) begin : STATE
        if (~ARESETN)
            state <= IDLE;
        else
            state <= state_next;
    end

    always @(posedge ACLK) begin : WRITE_FILE
        if (fd && (state==IDLE)) begin
            if (S_AXIS_TVALID) begin
                $fwrite(fd,"M: packet=%0d, delay=10\n",pkt_id);
                $fwrite(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
                #1 $display("[%0t] %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
            end
        end
        if (fd && (state==RD)) begin
            if (S_AXIS_TVALID) begin
                $fwrite(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
            #1 $display("[%0t] %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
            end
        end
        if (fd && (state==END)) begin
            $display("[%0t] Flushing output file: %s",$time,C_OUTPUTFILE);
            $fflush(fd);
            $fclose(fd);
            #1 $display("[%0t] netaxis2_slave: Simulation end",$time);
            $finish;
        end
    end//always

    always @(posedge ACLK) begin: PKT_ID
        if (~ARESETN)
            pkt_id <= 16'b1;
        else
        if (S_AXIS_TVALID && (state==IDLE))
            pkt_id <= pkt_id + 1'b1;
    end

    assign done_flag = (done || done_r);
    always @(posedge ACLK) begin : DONE_REG
        if (~ARESETN)
            done_r <= 1'b0;
        else begin
            if (state==DONE_TEST)
                done_r <= 1'b0;
            else if (done)
                done_r <= 1'b1;
        end
    end
endmodule
