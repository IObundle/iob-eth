#!/usr/bin/env bash
# Script to relay raw ethernet frames from a network device to a file, and
# vice-versa. This allows ethernet access for the simulation tesbench.

import socket
import binascii

def write_to_file(hex_data, output_file):
    with open(output_file, 'ab') as file:
        file.write(hex_data)

def capture_frames(interface, input_file, output_file):
    with socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3)) as s:
        s.bind((interface, 0))

        try:
            with open(input_file, 'rb') as input_file:
                hex_data = input_file.read()
                s.sendall(binascii.unhexlify(hex_data))
        except FileNotFoundError:
            print(f"Error: File {input_file} not found.")

        while True:
            data, _ = s.recvfrom(65536)
            hex_representation = binascii.hexlify(data)
            write_to_file(hex_representation, output_file)


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <interface> <input_file> <output_file>")
        sys.exit(1)

    interface = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    try:
        capture_frames(interface, input_file, output_file)
    except PermissionError:
        print("Error: You need root privileges to capture and relay raw Ethernet frames.")
    except KeyboardInterrupt:
        print("\nRelaying stopped.")
