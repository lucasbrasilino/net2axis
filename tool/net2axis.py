#!/usr/bin/env python
"""
   ISC License (ISC)
   Copyright 2018 Lucas Brasilino <lucas.brasilino@gmail.com>

   Refer to  LICENSE file.
"""

import sys
import logging
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
    
    def __init__(self, pcapfile=None, **kwargs):    
        self.pcapfile = pcapfile
        self.datawidth = int(kwargs.pop('datawidth', 32))
        self.keepwidth = int(self.datawidth/8)
        self.extension = kwargs.pop('extension','dat')
        _endianness = kwargs.pop('endianness','little')
        self.endianness = self._check_endianness(_endianness)
        self.pkts = None
        self.parsed = list()
        self.initdelay = kwargs.pop('initdelay',0);
        self.delay = kwargs.pop('delay',10);
        self.outputfile = self.pcapfile.split(".")[0]+"."+self.extension
        try:
            self.of = open(self.outputfile,"w")
        except IOError as e:
            sys.stderr.write("Couldn't write file: {0}\n".format(e))
            sys.exit(1)
        assert (not bool (kwargs)), "Illegal argument(s)"

    def loadpcapfile (self):
        self.pkts = rdpcap (self.pcapfile)

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
        self.loadpcapfile()
        self.parse()
        self.output()


def parse_args():
    import argparse
    _opt = argparse.ArgumentParser()
    _opt.add_argument ("pcapfile", default=None, help="Input PCAP file")
    _opt.add_argument ("-w","--datawidth",help="Data bus width (in bits)",
                       nargs="?",action="store")
    _opt.add_argument ("-i","--initdelay",help="Initial packet delay",
                       nargs="?",action="store")
    _opt.add_argument ("-d","--delay",help="Inter packet delay",
                       nargs="?",action="store")
    _opt.add_argument ("-e","--endianness",help="Set endianness",
                       nargs="?",action="store")
    _kw = vars(_opt.parse_args())
    _file = _kw.pop("pcapfile")
    return (_file, { k : _kw[k] for k in _kw if _kw[k] != None })

if __name__ == '__main__':
    (pcapfile,opts) = parse_args()
    net = Net2AXIS(pcapfile=pcapfile,**opts)
    net.run()
