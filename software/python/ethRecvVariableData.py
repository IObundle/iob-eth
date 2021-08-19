#Import libraries
from ethBase import CreateSocket,FormPacket
from ethRecvData import RecvFile
import sys
import struct

def RecvVariableFile(socket,output_filename):
    socket = CreateSocket()

    #Send empty packet to signal ready to receive
    bytes_sent = socket.send(FormPacket(''))

    #Receive file size
    rcv = socket.recv(4096)

    rcv_file_size = struct.unpack("<i",rcv[14:18])[0]

    RecvFile(socket,output_filename,rcv_file_size)

if __name__ == "__main__":
    print("\nStarting file reception...")
    RecvVariableFile(CreateSocket(),sys.argv[3])