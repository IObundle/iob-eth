# IOb-eth
IObundle's ethernet core.

This core implements raw socket ethernet communication. This corresponds to the
data link layer (2) of the OSI Model.

* * *
## Setup
The main steps to integrate iob-eth core into an iob-soc system:
1. Add iob-eth as a submodule/peripheral:
    1. Add the submodule to the repository:
    ```
    git submodule add git@github.com:IObundle/iob-eth.git submodules/ETHERNET
    git submodule update --init --recursive
    ```
    2. Add `ETHERNET` to `PERIPHERALS` in `config.mk` file:
    ```
    PERIPHERALS ?= UART <...> ETHERNET
    ```
    3. Add path to iob-eth submodule in `config.mk` file:
    ```
    ETHERNET_DIR=$(ROOT_DIR)/submodules/ETHERNET
    ```
    4. Include iob-eth makefile segments in `hardware/hardware.mk` file:
    ```
    # ETHERNET
    include $(ETHERNET_DIR)/hardware/hardware.mk
    ```
    5. Include iob-eth makefile segments in `software/firmware/Makefile` file:
    ```
    # ethernet
    include $(ETHERNET_DIR)/software/embedded/embedded.mk
    ```
2. Setup environment variables
    1. Add `RMAC_INTERFACE` to `~/.bashrc`:
    ```
    RMAC_INTERFACE=<RMAC_INTERFACE>
    ``` 
    Check the Common Issues section for more details.
    2. [Optional] For remote execution add `ETH_SERVER` and `ETH_USER` 
    environment variables to `~/.bashrc`:
    ```
    ETH_SERVER=<machine.connected.to.server>
    ETH_USER=<user_in_machine>
    ```
3. Update FPGA Board files:
    1. Check 
    `ETHERNET/hardware/fpga/vivado/AES-KU040-DG-B/top_system_eth_template.vh`
    for details on the ports and logic to add to the top level module.
    2. Check `ETHERNET/hardware/fpga/vivado/AES-KU040-DB-G/iob_eth.xdc` for an
    example of constraints required for the ethernet core.
    Note: these files are for the `AES-KU040-DB-G` board. For other devices you
    need to adapt the examples.
4. Create python scripts to communicate with the FPGA Board.
    1. Check `ETHERNET/software/python` for examples.
    2. Check `ETHERNET/Makefile` for usage targets.
5. Update embedded firmware to use the iob-eth core
    1. Check `ETHERNET/software/example_firmware.c` for an example program with
    ethernet communication.
6. Add target to run FPGA firmware and python scripts in parallel
    1. TODO:

* * *
## Common Issues
### Obtaining `RMAC_INTERFACE` value:
- on the machine that connects to the FPGA Board via ethernet run: `ifconfig`
- this command will show multiple interfaces (at least 3):
  - lookback interface (with inet 127.0.0.1)
  - interface with internet connection: (enAAAA:)
    - this interface has inet set to the machine IP
    - this is the ethernet connection to the router/internet
  - another interface named enBBBB but without `inet` values
    - this should be the one connected to the FPGA BOARD
- set `RMAC_INTERFACE=enBBBB` in your `~/.bashrc`
### System simulation takes a long time to initialize ethernet:
- ethernet simulation requires `DEFINE+=$(defmacro)SIM` so that internal reset takes less time 
  - check for `SIM` in `ETHERNET/hardware/src/iob_eth.v` for more details
### No permissions to open raw sockets
- Running raw sockets requires elevated privileges. This is solved by 
configuring a dedicated python3 virtual environment where the interpreter has 
raw socket capabilities.
### No data transfered between Host Machine and FPGA Board:
- Make sure that the interface is configured with `speed = 100Mb/s` and `duplex = full`
  - check interface status with: `ethtool $RMAC_INTERFACE`
    - check the `speed`, `duplex` and `Auto-negotiation` fields
- you can setup the interface with:
  ```
  sudo ethtool -s $RMAC_INTERFACE speed 100 duplex full autoneg on
  ```

## DMA

The Ethernet core provides an internal DMA for fast memory transfers between the internal buffers and DDR.
Care must be taken when integrating the core with IOb-SoC: The memory address must reside in DDR space in order to take advantage of the DMA
