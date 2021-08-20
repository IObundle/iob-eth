#Import libraries
from ethBase import TimedPrintProgress,CreateSocket,FormPacket,ETH_NBYTES
from os.path import getsize
import sys

def SendFile(socket,input_filename):
    #Open input file
    f_input = open(input_filename, 'rb')

    #Frame parameters
    input_file_size = getsize(input_filename)
    if(input_file_size == 0):
        printf("File is empty. Check if filepath is correct")
        return 0

    num_frames_input = ((input_file_size - 1) // ETH_NBYTES) + 1
    print("input_file_size: %d" % input_file_size)
    print("num_frames_input: %d" % (num_frames_input+1))

    #Reset byte counter
    count_bytes = 0
    count_errors = 0

    # Loop to send input frames
    for j in range(num_frames_input):
        TimedPrintProgress(j,num_frames_input - 1)

        # check if it is last packet (not enough for full payload)
        if j == (num_frames_input - 1):
            bytes_to_send = input_file_size - count_bytes
        else:
            bytes_to_send = ETH_NBYTES

        #form frame
        payload = f_input.read(bytes_to_send)

        # accumulate sent bytes
        count_bytes += ETH_NBYTES

        #Send packet
        packet = FormPacket(payload)

        bytes_sent = socket.send(packet)

        #receive data back as ack
        rcv = socket.recv(4096)

        curErrors = count_errors
        for sent_byte, rcv_byte in zip(payload, rcv[14:bytes_to_send+14]):
            if sent_byte != rcv_byte:
                count_errors += 1

    #Close file
    f_input.close()
    print("\n\nFile transmitted with %d errors..." %(count_errors))

if __name__ == "__main__":
    print("\nStarting file transmission...")
    SendFile(CreateSocket(),sys.argv[3])
