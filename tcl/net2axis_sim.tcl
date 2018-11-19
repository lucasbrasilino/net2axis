###############################################################
# ISC License (ISC)                                           #
# Copyright 2018 Lucas Brasilino <lucas.brasilino@gmail.com>  #
#                                                             #
# Refer to  LICENSE file.                                     #
###############################################################

set project_name "net2axis"
set origin_dir "[file normalize "."]"
set project_dir "[file normalize "$origin_dir/project-sim"]"
set part "xc7z020clg484-1"

set data_file "$origin_dir/[lindex $argv 0]"
set mode [lindex $argv end]
create_project ${project_name} ${project_dir} -part ${part} -force

if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}
set src_fileset [get_filesets sources_1]
add_files -norecurse -fileset $src_fileset "$origin_dir/hdl/net2axis.v"

if {[string equal [get_filesets -quiet sim_1] ""]} {
   create_fileset -simset sim_1
}

set sim_fileset [get_filesets sim_1]
set sim_files [glob $origin_dir/sim/*]
add_files -norecurse -fileset $sim_fileset $sim_files
set_property -name "xsim.compile.xvlog.more_options" -value "-d DATAFILE=${data_file}" -objects $sim_fileset
set_property -name "xsim.simulate.runtime" -value "all" -objects $sim_fileset
set_property -name "top" -value "net2axis_tb" -objects $sim_fileset

launch_simulation
if {[string equal $mode "gui"]} {
  start_gui
}
