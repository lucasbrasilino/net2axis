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

function integer clog2;
    input integer value;
    begin
        value = value-1;
        for (clog2=0; value>0; clog2=clog2+1)
            value = value>>1;
    end
endfunction

function [255:0] log_write;
    input integer level;
    input integer msg_level;
    input reg [31:0] inst;
    input reg [255:0] msg;
    reg [255:0] ret;

    begin
        if (msg_level == level) begin
            $sformat(ret,"%s:%s",inst,msg);
            $display("%s",ret);
            log_write = ret;
        end
    end
endfunction

function [255:0] master_log_write;
    input integer level;
    input integer msg_level;
    input reg [255:0] msg;

    begin
        master_log_write = log_write(level,msg_level,"Net2axis master",msg);
    end
endfunction