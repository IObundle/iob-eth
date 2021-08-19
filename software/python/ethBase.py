from socket import socket, AF_PACKET, SOCK_RAW, htons
import time
import sys

def PrintBaseUsage():
    print "<usage>: python eth_comm.py <interface> <RMAC> <file path>",

#Check arguments common to all scripts
if len(sys.argv) < 4:
    PrintBaseUsage()
    sys.exit()

#Ethernet parameters
interface = sys.argv[1]
src_addr = bytearray.fromhex(sys.argv[2])   # sender MAC address
dst_addr = "\x01\x60\x6e\x11\x02\x0f"       # receiver MAC address
eth_type = "\x60\x00"                       # ethernet frame type
ETH_P_ALL = 0x6000  

#Frame parameters
ETH_NBYTES = 1500
ETH_MINIMUM_NBYTES = (64-18)

#Frame header
ETH_HEADER = dst_addr + src_addr + eth_type

#Open socket and bind
def CreateSocket():
    s = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))
    s.bind((interface, 0))

    return s

def FormPacket(payload):
    length = len(payload)
    if(length < ETH_MINIMUM_NBYTES):
        payload = payload + (b'\x00' * (ETH_MINIMUM_NBYTES - length))

    return ETH_HEADER + payload

# Print progress every so often 
def TimedPrintProgress(current,n_frames):
    TimedPrintProgress.storedMilli
    milli = int(round(time.time() * 1000))

    if(milli > (TimedPrintProgress.storedMilli + 100) or current == 0 or current == n_frames):
        print "\rProgress: %d / %d" % (current + 1,n_frames + 1),
        sys.stdout.flush()
        TimedPrintProgress.storedMilli = milli

TimedPrintProgress.storedMilli = 0