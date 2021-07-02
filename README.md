# eth

## Setup
The usage of iob-eth repo requires setting up an environment variable indicating the interface of the connection between the pc and the target fpga.
`eno1` is used as an example for the interface.
On `~/.bashrc` add:
```
export RMAC_INTERFACE=eno1
```
After that execute the command in the terminal:
```
source ~/.bashrc
```

## DMA

The Ethernet core provides an internal DMA for fast memory transfers between the internal buffers and DDR.
Care must be taken when integrating the core with IOb-SoC: The memory address must reside in DDR space in order to take advantage of the DMA