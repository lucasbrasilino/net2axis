SOURCE = hdl/net2axis.v
PCAPFILE = sim/arp.pcap
DATAFILE = $(PCAPFILE:.pcap=.dat) 
TOOL = tool/net2axis.py

ip: $(SOURCE)
	vivado -mode batch -source tcl/net2axis_ip.tcl

ip-clean: clean
	rm -rf *.xml
	rm -rf ./project-ip

sim: $(SOURCE) $(DATAFILE)
	vivado -mode batch -source tcl/net2axis_sim.tcl -tclargs $(DATAFILE)

sim-gui: $(SOURCE) $(DATAFILE)
	vivado -mode batch -source tcl/net2axis_sim.tcl -tclargs $(DATAFILE) gui

sim-clean: clean
	rm -f $(DATAFILE)
	rm -rf ./project-sim

clean:
	rm -rf vivado*.* .Xil* *.*~ *.zip webtalk*

$(DATAFILE):
	$(TOOL) $(PCAPFILE)
