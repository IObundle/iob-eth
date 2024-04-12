#!/usr/bin/env python3
# Script to relay raw ethernet frames from a network device to a file, and
# vice-versa. This allows ethernet access for the simulation tesbench.

import socket
import os


def file_2_eth(socket_object, file_object):
    while True:
        # Get frame size
        frame_size = int.from_bytes(file_object.read(2), byteorder="little")
        # Send frame to socket
        socket_object.send(file_object.read(frame_size))


def eth_2_file(socket_object, file_object):
    while True:
        frame_data, _ = socket_object.recvfrom(65536)
        # Write two bytes with size of frame_data
        frame_size = len(frame_data).to_bytes(2, byteorder="little")
        file_object.write(frame_size + frame_data)


def relay_frames(interface, input_file, output_file):
    """Relay frames from network device to file and vice-versa.
    param interface: name of network device
    param input_file: path to the generated input file. Will be a named pipe.
    param output_file: path to the generated output file
    """
    with socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3)) as s:
        s.bind((interface, 0))

        # With a name pipe, we don't need keep polling and deleting chars from the file
        os.mkfifo(input_file)
        with open(input_file, "rb") as input_file:
            file_2_eth(s, input_file)

        with open(output_file, "ab") as output_file:
            eth_2_file(s, output_file)


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <interface> <input_file> <output_file>")
        sys.exit(1)

    interface = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    # Delete old files
    if os.path.exists(input_file):
        os.remove(input_file)
    if os.path.exists(output_file):
        os.remove(output_file)

    try:
        relay_frames(interface, input_file, output_file)
    except PermissionError as e:
        print(e)
        print(
            "Error: This script requires privileges to capture and relay raw Ethernet frames."
        )
        print("Use the following command to set the necessary capabilities:")
        print(f"setcap cap_net_raw,cap_net_admin=eip {sys.argv[0]}")
    except KeyboardInterrupt:
        print("\nRelaying stopped.")
