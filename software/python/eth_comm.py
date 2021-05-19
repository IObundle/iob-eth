#Import libraries
from socket import socket, AF_UNIX, SOCK_STREAM
from os.path import getsize
import sys
import struct

#Ethernet parameters
interface = "/tmp/tmpLocalSocket"
src_addr = "\x02\x60\x6e\x11\x02\x0f"       # sender MAC address
dst_addr = "\x01\x60\x6e\x11\x02\x0f"       # receiver MAC address
eth_type = "\x08\x00"                       # ethernet frame type
ETH_P_ALL = 0x0800  

#Frame parameters
eth_nbytes = 1024-18
    
#Open socket and bind
s = socket(AF_UNIX, SOCK_STREAM)
s.connect(interface)

################################# SEND DATA.BIN FILE ##############################################

s.send("ola")

s.close()