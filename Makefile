SOURCES = hdl/net2axis_master.v hdl/net2axis_slave.v
PCAPFILE = sim/arp.pcap
DATAFILE = $(PCAPFILE:.pcap=.dat) 
TOOL = tool/net2axis.py

ip: $(SOURCE)
	vivado -mode batch -source tcl/net2axis_ip.tcl

ip-clean: clean
	rm -rf ./project-ip

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
