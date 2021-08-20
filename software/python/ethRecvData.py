#Import libraries
from ethBase import PrintBaseUsage,TimedPrintProgress,CreateSocket,FormPacket,ETH_NBYTES
from os.path import getsize
import sys
import struct
import time

def RecvFile(socket,output_filename,expected_size):
    if(expected_size == 0):
        printf("Expected size is zero. Check if parameters are correct")
        return

    #Frame parameters
    num_frames = ((expected_size - 1) // ETH_NBYTES) + 1
    print("file_size: %d" % expected_size)
    print("num_frames: %d" % num_frames)

    #Send empty packet to signal ready to receive
    bytes_sent = socket.send(FormPacket(''))

    #Open output file
    f_output = open(output_filename, 'wb')

    #Reset byte counter
    count_bytes = 0

    # Loop to send input frames
    for j in range(num_frames):
        TimedPrintProgress(j,num_frames - 1)

        #receive data
        rcv = socket.recv(4096)

        # check if it is last packet (not enough for full payload)
        if j == (num_frames - 1):
            bytes_to_recv = expected_size - count_bytes
        else:
            bytes_to_recv = ETH_NBYTES

        #form frame
        payload = rcv[14:bytes_to_recv+14]

        # Write into file
        f_output.write(payload)

        # accumulate sent bytes
        count_bytes += ETH_NBYTES

        #Send packet as ack
        packet = FormPacket(payload)

        bytes_sent = socket.send(packet)

    #Close file
    f_output.close()

if __name__ == "__main__":
    if(len(sys.argv) < 5):
        PrintBaseUsage()
        print "<expected size>"
        sys.exit()
    
    print("\nStarting file reception...")
    RecvFile(CreateSocket(),sys.argv[3],int(sys.argv[4]))
