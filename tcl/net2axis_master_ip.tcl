###############################################################
# ISC License (ISC)                                           #
# Copyright 2018 Lucas Brasilino <lucas.brasilino@gmail.com>  #
#                                                             #
# Refer to  LICENSE file.                                     #
###############################################################

set design net2axis_master
set top $design
set proj_dir "./${design}-ip-project"
set component_dir "./$design"
set ip_version 1.1
set lib_name LB
set vendor_name "lucasbrasilino.com"
set vendor_display_name "www.lucasbrasilino.com"
set display_name "Net2AXIS master"
set url "https://github.com/lucasbrasilino/net2axis"
set taxonomy "{/AXIS Infrastructure}"

create_project -name ${design} -force -dir "./${proj_dir}"  -ip
set_property source_mgmt_mode All [current_project]
set_property top ${top} [current_fileset]
read_verilog "./hdl/net2axis_master.v"

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
ipx::package_project -root_dir $component_dir -generated_files -verbose

set net2axis_ip [ipx::current_core]
set_property -dict [ list \
    name ${design} \
    library ${lib_name} \
    vendor_display_name $vendor_display_name \
    company_url $url \
    vendor $vendor_name \
    taxonomy $taxonomy \
    version ${ip_version} \
    display_name ${display_name} \
    description $display_name \
] $net2axis_ip

set_property SUPPORTED_FAMILIES { \
  artix7 Pre-Production \
  artix7l Pre-Production \
  kintex7 Pre-Production \
  kintex7l Pre-Production \
  kintexu Pre-Production \
  kintexuplus Pre-Production \
  virtex7 Pre-Production \
  virtexu Pre-Production \
  virtexuplus Pre-Production \
  zynq Pre-Production \
  zynquplus Pre-Production \
  aartix7 Pre-Production \
  azynq Pre-Production \
  qartix7 Pre-Production \
  qkintex7 Pre-Production \
  qkintex7l Pre-Production \
  qvirtex7 Pre-Production \
  qzynq Pre-Production \
} $net2axis_ip

set aclk_interf [ipx::get_bus_interfaces ACLK -of_objects $net2axis_ip]
set aclk_interf_param [ipx::add_bus_parameter ASSOCIATED_BUSIF $aclk_interf]
set_property value M_AXIS $aclk_interf_param

ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
update_ip_catalog

close_project
file delete -force ${proj_dir}
