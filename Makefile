SOURCE = hdl/net2axis.v
PCAPFILE = sim/arp.pcap
DATAFILE = $(PCAPFILE:.pcap=.dat) 
TOOL = tool/net2axis.py


sim: $(SOURCE) $(DATAFILE)
	vivado -mode batch -source tcl/net2axis_sim.tcl -tclargs $(DATAFILE)

sim-gui: $(SOURCE) $(DATAFILE)
	vivado -mode batch -source tcl/net2axis_sim.tcl -tclargs $(DATAFILE) gui

sim-clean:
	rm -f $(DATAFILE)
	rm -rf ./project-sim
	rm -rf vivado*.* .Xil* *.*~ *.zip webtalk*

$(DATAFILE):
	$(TOOL) $(PCAPFILE)
