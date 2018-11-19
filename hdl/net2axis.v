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

module net2axis #(
        parameter           C_INPUTFILE           = "",
        parameter           C_TDATA_WIDTH         = 32
        ) (
        input wire        ACLK,
        input wire        ARESETN,

        output wire                            DONE,
        output wire                            M_AXIS_TVALID,
        output wire  [C_TDATA_WIDTH-1 : 0]     M_AXIS_TDATA,
        output wire  [(C_TDATA_WIDTH/8)-1 : 0] M_AXIS_TKEEP,
        output wire                            M_AXIS_TLAST,
        input wire                             M_AXIS_TREADY
        );

    function integer clog2;
        input integer value;
        begin
            value = value-1;
            for (clog2=0; value>0; clog2=clog2+1)
                value = value>>1;
        end
    endfunction

    localparam                      IDLE = 0;
    localparam                      PREP_READ_MD = 1;
    localparam                      READ_MD = 2;
    localparam                      DELAY = 3;
    localparam                      WR = 4;
    localparam                      POST_WR = 5;
    localparam                      LAST = 6;

    localparam                      COUNTER_WIDTH = 16;
    localparam                      STATE_WIDTH = clog2(LAST);

    reg [COUNTER_WIDTH-1 : 0]       delay_counter, delay_counter_val;
    wire [COUNTER_WIDTH-1 : 0]      delay_counter_next;
    wire                            delay_counter_exp;
    reg                             eof;
    wire                            read_pkt_data_en;

    reg [STATE_WIDTH-1:0]            state, state_next;
    reg                              done;
    reg [C_TDATA_WIDTH-1 : 0]        tdata;
    reg [(C_TDATA_WIDTH/8)-1 : 0]    tkeep;
    reg                              tvalid;
    reg                              tlast;

    integer                         fd, ld;
    reg [7:0]                       md_flag_file;
    wire [7:0]                      md_flag;
    wire                            md_flag_found;
    reg [15:0]                      pkt_id;

    assign delay_counter_next =     delay_counter - 1;
    assign DONE               =     done;
    assign M_AXIS_TDATA       =     tdata;
    assign M_AXIS_TKEEP       =     tkeep;
    assign M_AXIS_TLAST       =     tlast;
    assign M_AXIS_TVALID      =     tvalid;

    assign delay_counter_exp  =     (delay_counter == 0);
    assign read_pkt_data_en   =     (delay_counter_exp || (state == WR));
    assign md_flag            =     (state == READ_MD) ? md_flag_file : 8'h00;
    assign md_flag_found      =     (md_flag == `MD_MARKER);

    initial begin
        $timeformat(-9, 2, " ns", 20);
        if (C_INPUTFILE == "") begin
            $display("Erro: inputfile NULL!");
            $finish;
        end
        else
            fd = $fopen(C_INPUTFILE,"r");
    end

    initial begin
        wait (ARESETN == 1'b1) $display("[%0t] Reset deasserted", $time);
    end

    always @(*) begin : STATE_NEXT
        tvalid = 1'b0;
        done = 1'b0;
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

    always @(posedge ACLK) begin : STATE
        if (~ARESETN)
            state <= IDLE;
        else
            state <= state_next;
    end

    always @(posedge ACLK) begin
        if (~ARESETN)
            delay_counter <= 0;
        else
        if (M_AXIS_TREADY)
            delay_counter <= (state == READ_MD) ? delay_counter_val : delay_counter_next;
    end

    always @(posedge ACLK) begin : READ_FILE
        if (~eof) begin
            if (M_AXIS_TREADY) begin
                if (state == PREP_READ_MD) begin
                    ld = $fscanf(fd,"%c: pkt=%d, delay=%d",md_flag_file, pkt_id, delay_counter_val);
                    $display("[%0t] Starting packet %0d after delay of %0d clock cycles",$time, pkt_id, delay_counter_val);
                end else
                if (read_pkt_data_en) begin
                    ld = $fscanf(fd, "%x,%x,%x\n",tdata,tkeep,tlast);
                    #1 $display("[%0t] %x | %x | %x | %x",$time,tvalid, tdata,tkeep,tlast);
                end
            end
        end
    end

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
endmodule
