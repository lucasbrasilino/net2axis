SOURCES = hdl/net2axis_master.v hdl/net2axis_slave.v
PCAPFILE = sim/arp.pcap
DATAFILE = $(PCAPFILE:.pcap=.dat) 
TOOL = tool/net2axis.py

ip: $(SOURCES)
	vivado -mode batch -source tcl/net2axis_master_ip.tcl
	vivado -mode batch -source tcl/net2axis_slave_ip.tcl

ip-clean: clean
	-rm -rf ./ip_user_files
	-rm -rf ./net2axis_master
	-rm -rf ./net2axis_slave

sim: $(SOURCES) $(DATAFILE)
	vivado -mode batch -source tcl/net2axis_sim.tcl -tclargs $(DATAFILE)

sim-gui: $(SOURCES) $(DATAFILE)
	vivado -mode batch -source tcl/net2axis_sim.tcl -tclargs $(DATAFILE) gui

sim-clean: clean
	rm -f $(DATAFILE)
	rm -rf ./project-sim

clean:
	rm -rf vivado*.* .Xil* *.*~ *.zip webtalk*

$(DATAFILE):
	$(TOOL) $(PCAPFILE)
