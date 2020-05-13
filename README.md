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