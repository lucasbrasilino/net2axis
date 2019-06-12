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

        output  wire                           DONE,
        input wire                             LAST_PKT,
        input  wire                            S_AXIS_TVALID,
        input  wire  [C_TDATA_WIDTH-1 : 0]     S_AXIS_TDATA,
        input  wire  [(C_TDATA_WIDTH/8)-1 : 0] S_AXIS_TKEEP,
        input  wire                            S_AXIS_TLAST,
        output wire                            S_AXIS_TREADY
        );

    localparam                      IDLE = 0;
    localparam                      RD = 1;
    localparam                      LAST_PKT_TEST = 2;
    localparam                      WAIT_FOR_PKT = 3;
    localparam                      END = 4;
    localparam                      HALT = 5;

    localparam                      COUNTER_WIDTH = 16;
    localparam                      STATE_WIDTH = $clog2(HALT);

    integer                         fd, ld, errno;

    reg [STATE_WIDTH-1:0]             state, state_next;
    wire                              last_pkt,last_pkt_flag;
    wire [C_TDATA_WIDTH-1 : 0]        tdata;
    wire [(C_TDATA_WIDTH/8)-1 : 0]    tkeep;
    wire                              tvalid;
    wire                              tlast;
    reg                               tready;
    reg  [15:0]                       pkt_id;
    reg                               last_pkt_r;
    reg                               done;
    reg  [15:0]                       wait_last_pkt_counter,wait_last_pkt_counter_next;

    assign tdata              = S_AXIS_TDATA;
    assign tkeep              = S_AXIS_TKEEP;
    assign tlast              = S_AXIS_TLAST;
    assign tvalid             = S_AXIS_TVALID;
    assign S_AXIS_TREADY      = tready;
    assign last_pkt           = LAST_PKT;
    assign DONE               = done;

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
        done = 1'b0;
        wait_last_pkt_counter_next = 16'h0;
        case (state)
            IDLE: begin
                tready = 1'b1;
                state_next = (tvalid) ? RD : IDLE;
            end
            RD: begin
                tready = 1'b1;
                state_next = (tvalid && tlast) ? LAST_PKT_TEST : RD;
            end
            LAST_PKT_TEST:begin
                tready = 1'b1;
                state_next = (last_pkt_flag) ? WAIT_FOR_PKT : IDLE;
            end
            WAIT_FOR_PKT: begin
                wait_last_pkt_counter_next = wait_last_pkt_counter + 1'b1;
                if (tvalid) begin
                   wait_last_pkt_counter_next = 0;
                    state_next = IDLE;
                end
                else if (wait_last_pkt_counter == 16'h14)
                    state_next = END;
            end
            END: state_next = HALT;
            HALT: begin
                done = 1'b1;
                state_next = HALT;
            end

        endcase
    end

    always @(posedge ACLK) begin : STATE
        if (~ARESETN)
            state <= IDLE;
        else
            state <= state_next;
    end

    always @(posedge ACLK) begin : WRITE_FILE
        case (state)
            IDLE: begin
                if (tvalid) begin
                    $display("[%0t] state=%x",$time,state);
                    $fwrite(fd,"M: packet=%0d, delay=10\n",pkt_id);
                    $display("[%0t] net2axis_slave:  %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
                    $fwrite(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
                end
            end
            RD: begin
                if (tvalid) begin
                    $display("[%0t] net2axis_slave: %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
                    $fwrite(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
                end
            end
            END: begin
                $display("[%0t] netaxis2_slave: Flushing output file: %s",$time,C_OUTPUTFILE);
                $display("[%0t] netaxis2_slave: Simulation end",$time);
                $fflush(fd);
                $fclose(fd);
                //$finish;
            end
            //default: $fflush(fd);
        endcase
    end//always

    always @(posedge ACLK) begin: PKT_ID
        if (~ARESETN)
            pkt_id <= 16'b1;
        else
        if (tvalid && (state==IDLE))
            pkt_id <= pkt_id + 1'b1;
    end

    assign last_pkt_flag = (last_pkt || last_pkt_r);
    always @(posedge ACLK) begin : DONE_REG
        if (~ARESETN)
            last_pkt_r <= 1'b0;
        else begin
            if (state==LAST_PKT_TEST)
                last_pkt_r <= 1'b0;
            else if (last_pkt)
                last_pkt_r <= 1'b1;
        end
    end

    always @(posedge ACLK) begin : WAIT_FOR_PKT_COUNTER
        if (~ARESETN)
            wait_last_pkt_counter <= 0;
        else
            wait_last_pkt_counter <= wait_last_pkt_counter_next;
    end
endmodule
