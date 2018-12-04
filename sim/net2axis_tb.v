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

`ifndef DATAFILE
    `define DATAFILE ""
`endif

`define TO_STRING(s) `"s`"

module net2axis_tb;

    localparam C_TDATA_WIDTH = 32;

    localparam HALF_CORE_PERIOD = 5; // 100Mhz
    localparam PERIOD = HALF_CORE_PERIOD*2;
    localparam INPUTFILE = `TO_STRING(`DATAFILE);

    reg                             ACLK;
    reg                             ARESETN;

    wire                            M_AXIS_TVALID;
    wire  [C_TDATA_WIDTH-1 : 0]     M_AXIS_TDATA;
    wire  [(C_TDATA_WIDTH/8)-1 : 0] M_AXIS_TKEEP;
    wire                            M_AXIS_TLAST;
    reg                             M_AXIS_TREADY;
    wire                            DONE;

    initial begin
        $timeformat(-9, 2, " ns", 20);
        ACLK = 1'b0;
        #(HALF_CORE_PERIOD);
        forever
            #(HALF_CORE_PERIOD) ACLK = ~ACLK;
    end

    initial begin
        ARESETN = 1'b0;
        #(PERIOD * 12);
        ARESETN = 1'b1;
    end

    initial begin
        M_AXIS_TREADY = 1'b0;
        wait (ARESETN == 1'b1);
        #(PERIOD * 10);
        M_AXIS_TREADY = 1'b1;
    end

    initial begin
        wait (DONE == 1'b1);
        #(PERIOD * 10);
        $display("[%0t] Simulation finished",$time);
        $finish;
    end

    net2axis #(
        .C_INPUTFILE      (INPUTFILE),
        .C_TDATA_WIDTH    (C_TDATA_WIDTH   )
        ) net2axis (
        .ACLK             (ACLK            ),
        .ARESETN          (ARESETN         ),
        .DONE             (DONE            ),
        .M_AXIS_TVALID    (M_AXIS_TVALID   ),
        .M_AXIS_TDATA     (M_AXIS_TDATA    ),
        .M_AXIS_TKEEP     (M_AXIS_TKEEP    ),
        .M_AXIS_TLAST     (M_AXIS_TLAST    ),
        .M_AXIS_TREADY    (M_AXIS_TREADY   ));

endmodule
