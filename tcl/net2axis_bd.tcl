set design_name net2axis_bd
set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${cur_design} eq "" } {
    create_bd_design $design_name
}
set M_AXIS [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS ]

set DONE [ create_bd_port -dir O DONE ]
set clk [ create_bd_port -dir O -type clk clk ]
set_property -dict [ list \
    CONFIG.ASSOCIATED_BUSIF {M_AXIS} \
] $clk
set sync_rst [ create_bd_port -dir O -type rst sync_rst ]

set net2axis_0 [ create_bd_cell -type ip -vlnv lucasbrasilino.com:LB:net2axis_master:1.1 net2axis_0 ]
set_property -dict [ list \
    CONFIG.C_INPUTFILE {} \
] $net2axis_0

set sim_clk_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:sim_clk_gen:1.0 sim_clk_gen_0 ]
set_property -dict [ list \
    CONFIG.INITIAL_RESET_CLOCK_CYCLES {10} \
] $sim_clk_gen_0

connect_bd_intf_net -intf_net net2axis_0_M_AXIS [get_bd_intf_ports M_AXIS] [get_bd_intf_pins net2axis_0/M_AXIS]

connect_bd_net -net net2axis_0_DONE [get_bd_ports DONE] [get_bd_pins net2axis_0/DONE]
connect_bd_net -net sim_clk_gen_0_clk [get_bd_ports clk] [get_bd_pins net2axis_0/ACLK] [get_bd_pins sim_clk_gen_0/clk]
connect_bd_net -net sim_clk_gen_0_sync_rst [get_bd_ports sync_rst] [get_bd_pins net2axis_0/ARESETN] [get_bd_pins sim_clk_gen_0/sync_rst]