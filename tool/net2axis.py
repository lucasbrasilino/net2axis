#!/usr/bin/env python
"""
   ISC License (ISC)
   Copyright 2018 Lucas Brasilino <lucas.brasilino@gmail.com>

   Refer to  LICENSE file.
"""

import sys
import logging
from os.path import abspath,basename
from pprint import pprint
from binascii import hexlify

try:
    logging.getLogger("scapy.runtime").setLevel(logging.ERROR)
    from scapy.all import rdpcap
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
        self.endianness = self._check_endianness(self.endianness)
        self.pkts = None
        self.parsed = list()
        self.outputfile = self.file.split(".")[0]+"."+self.extension
        try:
            self.of = open(self.outputfile,"w")
        except IOError as e:
            sys.stderr.write("Couldn't write file: {0}\n".format(e))
            sys.exit(1)

    def loadfile (self):
        if self.to_pcap:
            self.lines = list()
            with open (self.file) as file:
                for line in file:
                    self.lines.append(line.strip())
        else:
            self.pkts = rdpcap (self.file)

    def _check_endianness(self, _end):
        if not _end in Net2AXIS.endianness.keys():
            raise ValueError ("Invalid endianness: {0}".format(_end))
        return Net2AXIS.endianness[_end]
        
    def _switch_endianness(self,_words):
        _ret = list()
        for _word in _words:
            _ret.append("".join(reversed([_word[i:i+2] for i in range(0, len(_word), 2)])))
        return _ret
            
    def _parsepkt(self, pkt):
        _content = hexlify(str(pkt))
        _nibble_offset = (self.datawidth/4)
        _tdata = [_content[i:i+_nibble_offset] for i in range(0,len(_content), _nibble_offset)]
        if self.endianness == Net2AXIS.END_LITTLE:
            _tdata = self._switch_endianness(_tdata)
        _tkeep = [str(hex(2**(len(w)/2)-1)).split("x",1)[1] for w in _tdata]
        _tlast = ['0' for w in _tdata[:-1]]
        _tlast.append('1')
        return [_tdata[i]+','+_tkeep[i]+','+_tlast[i] for i in range(0,len(_tdata))]

    def parse (self):
        if self.to_pcap:
            _tdata = list()
            _tkeep = list()
            _d_str = ""
            for i in range(0,len(self.lines)):
                l = self.lines[i]
                if l[0] != 'M':
                    _d,_k,_l = l.split(",")
                    _d_str += "".join(reversed([_d[i:i+2] for i in range(0, len(_d), 2)]))
                    if _l == "1":
                        _tdata.append(_d_str.decode("hex"))
                        _tkeep.append(_k)
                        _d_str=""
            self.parsed = _tdata
        else:
            _num_pkts = len(self.pkts)
            for p in self.pkts:
                self.parsed.append(self._parsepkt(p))

    def output(self):
        for i in range (0, len(self.parsed)):
            _pkt = self.parsed[i]
            _delay = self.initdelay if i == 0 else self.delay
            self.of.write("M: pkt={0}, delay={1}\n".format((i+1),_delay))
            for l in _pkt:
                self.of.write("{0}\n".format(l))

    def run(self):
        self.loadfile()
        self.parse()
        #self.output()

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
    net = Net2AXIS(file=file,**opts)
    net.run()
