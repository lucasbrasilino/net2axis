#!/usr/bin/env python
"""
   ISC License (ISC)
   Copyright 2018-2021 Lucas Brasilino <lucas.brasilino@gmail.com>

   Refer to  LICENSE file.
"""

import sys
import logging
from os.path import abspath,basename
from pprint import pprint
from binascii import hexlify

try:
    logging.getLogger("scapy.runtime").setLevel(logging.ERROR)
    from scapy.all import rdpcap,wrpcap,raw
    from scapy.error import *
except ImportError as e:
    sys.stderr.write("Couldn't import scapy: {0}\n".format(e))
    sys.exit(1)
    
class Net2AXIS(object):
    END_BIG = 0
    END_LITTLE = 1
    endianness = {'big' : END_BIG, 'little' : END_LITTLE}
    
    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)
        if not self.file:
            raise ValueError("Input file not specified")
        self.extension = 'pcap' if self.to_pcap else 'dat'
        self.endianness = self.__check_endianness(self.endianness)
        self.pkts = None
        self.parsed = list()
        self.datawidth_bytes = int(self.datawidth/8)
        self.keepwidth_nibbles = int(self.datawidth_bytes/4)
        self.outputfile = self.file.split(".")[0]+"."+self.extension
        try:
            self.of = open(self.outputfile,"w")
        except IOError as e:
            sys.stderr.write("Couldn't write file: {0}\n".format(e))
            sys.exit(1)

    def __get_abspath(self,file):
        return abspath(file)

    def __get_out_file(self):
        return self.in_file.split(".")[0]+"."+self.out_extension

    def __check_endianness(self, _end):
        if not _end in Net2AXIS.endianness.keys():
            raise ValueError ("Invalid endianness: {0}".format(_end))
        return Net2AXIS.endianness[_end]

    def loadfile (self):
        pass

    def parse (self):
        pass

    def run(self):
        self.loadfile()
        self.parse()
        self.storefile()

class Net2AXISMaster(Net2AXIS):

    def __init__(self,**kwargs):
        super(Net2AXISMaster,self).__init__(**kwargs)
        self.out_extension = 'dat'
        self.in_file = self._Net2AXIS__get_abspath(file)
        self.out_file = self._Net2AXIS__get_out_file()

    def __parsepkt(self,pkt):
        __content = raw(pkt)
        __tdata = [__content[0+i:self.datawidth_bytes+i] for i in range(0,len(__content),self.datawidth_bytes)]
        __tkeep = [format(2**len(__word)-1,'x') for __word in __tdata ]
        return zip(__tdata,__tkeep)

    def loadfile(self):
        try:
            self.pkts = rdpcap (self.in_file)
        except (Scapy_Exception,FileNotFoundError) as e:
            sys.stderr.write("Couldn't read pcap file: {0}\n".format(self.in_file))
            sys.stderr.write("{0}\n".format(e))
            sys.exit(1)

    def parse(self):
        for p in self.pkts:
            self.parsed.append(self.__parsepkt(p))

    def dump(self):
        for w in self.parsed:
            print(f'{list(w)}')

    def storefile(self):
        try:
            self.of = open(self.out_file,"w")
        except IOError as e:
            sys.stderr.write("Couldn't write file: {0}\n".format(e))
            sys.exit(1)
        for o in self.parsed:
            __pkt = list(o)
            __last = len(__pkt)-1
            __i = 0
            for t in __pkt:
                __d = bytes(t[0])
                __k = t[1]
                self.of.write(f'{__d.hex()}{__k}')
                __last_str = '1' if __i == __last else '0'
                __i += 1
                self.of.write(f'{__last_str}\n')

def parse_args():
    import argparse
    _opt = argparse.ArgumentParser()
    _opt.add_argument ("file", default=None, help="Input file")
    _opt.add_argument ("-w","--datawidth",help="Data bus width (in bits)",
                       nargs="?",default=32, type=int, action="store")
    _opt.add_argument ("-i","--initdelay",help="Initial packet delay",
                       nargs="?",default=0, type=int, action="store")
    _opt.add_argument ("-d","--delay",help="Inter packet delay",
                       nargs="?",default=10, type=int, action="store")
    _opt.add_argument ("-e","--endianness",help="Set endianness",
                       nargs="?",default="little", action="store")
    _opt.add_argument ("-p","--to-pcap",help="Generate PCAP",
                       action="store_true")
    _kw = vars(_opt.parse_args())
    _file = _kw.pop("file")
    return (_file, { k : _kw[k] for k in _kw if _kw[k] != None })

if __name__ == '__main__':
    file,opts = parse_args()
    net = Net2AXISMaster(file=file,**opts)
    net.run()
