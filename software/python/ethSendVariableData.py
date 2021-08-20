#Import libraries
from ethBase import CreateSocket,FormPacket
from ethSendData import SendFile
from os.path import getsize
import sys
import struct

def SendVariableFile(socket,input_filename):
    input_file_size = getsize(input_filename)

    #Send first frame with input_file_size
    packet = FormPacket(struct.pack("<i",input_file_size))

    bytes_sent = socket.send(packet)

    #Wait for ack
    rcv = socket.recv(4096)

    rcv_file_size = struct.unpack("<i",rcv[14:18])[0]

    print "Size: %d " % rcv_file_size

    if(rcv_file_size != input_file_size):
        print("Error sending file size")

    SendFile(socket,input_filename)

if __name__ == "__main__":
    print("\nStarting file transmission...")
    SendVariableFile(CreateSocket(),sys.argv[3])
