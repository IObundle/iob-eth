#!/usr/bin/env python3
# Script to relay raw ethernet frames from a network device to a file, and
# vice-versa. This allows ethernet access for the simulation tesbench.

import socket
import binascii


def write_to_file(hex_data, output_file):
    with open(output_file, "ab") as file:
        file.write(hex_data)


def capture_frames(interface, input_file, output_file):
    with socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3)) as s:
        s.bind((interface, 0))

        # try:
        #    with open(input_file, 'rb') as input_file:
        #        hex_data = input_file.read()
        #        s.sendall(binascii.unhexlify(hex_data))
        # except FileNotFoundError:
        #    print(f"Error: File {input_file} not found.")

        while True:
            data, _ = s.recvfrom(65536)
            hex_representation = binascii.hexlify(data)
            write_to_file(hex_representation, output_file)
            # End line with 2 chars, to match a hex byte
            write_to_file(b"0\n", output_file)


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
    except PermissionError as e:
        print(e)
        print(
            "Error: This script requires privileges to capture and relay raw Ethernet frames."
        )
        print("Use the following command to set the necessary capabilities:")
        print(f"setcap cap_net_raw,cap_net_admin=eip {sys.argv[0]}")
    except KeyboardInterrupt:
        print("\nRelaying stopped.")
