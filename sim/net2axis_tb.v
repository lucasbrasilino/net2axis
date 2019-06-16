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

    localparam TDATA_WIDTH = 32;

    localparam HALF_CORE_PERIOD = 5; // 100Mhz
    localparam PERIOD = HALF_CORE_PERIOD*2;
    localparam INPUTFILE = `TO_STRING(`DATAFILE);
    localparam HARD_TIMEOUT = 2000;

    reg                             ACLK;
    reg                             ARESETN;

    wire                            M_AXIS_TVALID;
    wire  [TDATA_WIDTH-1 : 0]       M_AXIS_TDATA;
    wire  [(TDATA_WIDTH/8)-1 : 0]   M_AXIS_TKEEP;
    wire                            M_AXIS_TLAST;
    reg                             M_AXIS_TREADY;
    wire                            DONE;
    reg                             START;

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
        START = 1'b0;
        wait (ARESETN == 1'b1);
        #(PERIOD * 15);
        START = 1'b1;
    end

    initial begin
        wait (ARESETN == 1'b1);
        #(PERIOD * HARD_TIMEOUT);
        $display("[%0t] Hard timeout reached. Simulation finished",$time);
        $finish;
    end

    initial begin
        wait (DONE == 1'b1);
        #(PERIOD * 10);
        $display("[%0t] Simulation finished",$time);
        $finish;
    end

    net2axis_master #(
        .INPUTFILE      (INPUTFILE         ),
        .TDATA_WIDTH    (TDATA_WIDTH       ),
        .START_EN       (1                 )
        ) net2axis (
        .ACLK             (ACLK            ),
        .ARESETN          (ARESETN         ),
        .DONE             (DONE            ),
        .START            (START           ),
        .M_AXIS_TVALID    (M_AXIS_TVALID   ),
        .M_AXIS_TDATA     (M_AXIS_TDATA    ),
        .M_AXIS_TKEEP     (M_AXIS_TKEEP    ),
        .M_AXIS_TLAST     (M_AXIS_TLAST    ),
        .M_AXIS_TREADY    (M_AXIS_TREADY   ));

endmodule
