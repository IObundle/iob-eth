# IOb-eth
IObundle's ethernet core.

This core implements raw socket ethernet communication. This corresponds to the
data link layer (2) of the OSI Model.

* * *
## Setup
The main steps to integrate iob-eth core into an iob-soc system:
1. Setup environment variables
    1. Add `RMAC_INTERFACE` to `~/.bashrc` of the machine directly connected to
    the FPGA Board. Check the Common Issues section for more details:
    ```
    RMAC_INTERFACE=<RMAC_INTERFACE>
    ``` 
2. Add iob-eth as a submodule/peripheral:
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
    4. Add `RMAC_ADDR` in `config.mk` file:
    ```
    RMAC_ADDR:=<RMAC_ADDR>
    ```
    Obtain `<RMAC_ADDR>` with the command:
    ```
    # On machine connected to FPGA Board
    ethtool -P $RMAC_INTERFACE | sed s/://g
    # From remote machine
    ssh user@<remove_server> 'ethtool -P $RMAC_INTERFACE | sed s/://g '
    ```
    5. Include iob-eth makefile segments in `hardware/hardware.mk` file:
    ```
    # ETHERNET
    include $(ETHERNET_DIR)/hardware/hardware.mk
    ```
    6. Include iob-eth makefile segments in `software/firmware/Makefile` file:
    ```
    # ethernet
    include $(ETHERNET_DIR)/software/embedded/embedded.mk
    ```
3. Define `SIM` for simulation:
    1. Add `SIM` variable in `hardware/simulation/simulation.mk` before
       including `hardware/hardware.mk`:
    ```Make
    SIM=1
    DEFINE+=$(defmacro)SIM=$(SIM)
    ```
    2. Add `SIM` to firmware in case of simulation in
       `software/firmware/Makefile`:
    ```Make
    ifeq ($(SIM),1)
    DEFINE+=$(defmacro)SIM=$(SIM)
    endif
    ```
    3. Set `SIM` variable in `Makefile` when making embedded sw for simulation:
    ```Make
    # Original make call
        sim-build:
            make fw-build
            make -C $(SIM_DIR) build
    # Make call with SIM variable
        sim-build:
            make fw-build SIM=1
            make -C $(SIM_DIR) build
    ```
4. Update FPGA Board files:
    1. Check 
    `ETHERNET/hardware/fpga/vivado/AES-KU040-DG-B/top_system_eth_template.vh`
    for details on the ports and logic to add to the top level module.
    2. Check `ETHERNET/hardware/fpga/vivado/AES-KU040-DB-G/iob_eth.xdc` for an
    example of constraints required for the ethernet core.
    Note: these files are for the `AES-KU040-DB-G` board. For other devices you
    need to adapt the examples.
5. Create python scripts to communicate with the FPGA Board.
    1. Check `ETHERNET/software/example_python.py` and
       `ETHERNET/software/python/` for examples.
    2. Check `ETHERNET/Makefile` for usage targets.
6. Update embedded firmware to use the iob-eth core
    1. Check `ETHERNET/software/example_firmware.c` for an example program with
    ethernet communication.
7. Use wrapper script to run console and python script in parallel
    1. Copy the wrapper script to the console location:
    ```
    cp submodules/ETHERNET/software/console/eth_console software/console/
    ```
    2. Replace the `CONSOLE_CMD` in `software/pc-emul/Makefile` to use
       `eth_console` script:
    ```Make
    # Old variable
    CONSOLE_CMD=$(ROOT_DIR)/software/console/console -L
    # Using eth_console script
    CONSOLE_CMD=$(ROOT_DIR)/software/console/eth_console -L
    ```
    3. Replace the `CONSOLE_CMD` in `hardware/fpga/fpga.mk` to use
       `eth_console` script:
    ```Make
    # Old variable
    CONSOLE_CMD=$(CONSOLE_DIR)/console -s /dev/usb-uart
    # Using eth_console script
    CONSOLE_CMD=$(CONSOLE_DIR)/eth_console -s /dev/usb-uart
    ```
    4. For remote fpga executions, copy back the `ethernet.log`. Add this
       command to the `fpga.mk` run target:
    ```Make
	scp $(BOARD_USER)@$(BOARD_SERVER):$(REMOTE_ROOT_DIR)/hardware/fpga/$(TOOL)/$(BOARD)/ethernet.log .
    ```
8. Run in PC-Emul, Simulation or FPGA:
    1. Use same targets as default `iob-soc`
    2. Console output is printed to terminal, ethernet script output is printed
       to `ethernet.log`.

* * *
## Common Issues
### Obtaining `RMAC_INTERFACE` value:
- on the machine that connects to the FPGA Board via ethernet run: `ip a`
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
  sudo ethtool -s $RMAC_INTERFACE speed 100 duplex full autoneg off
  ```
### `Failed to bind socket` on PC-Emul
- The pc-emul drivers create a local socket file in `/tmp/tmpLocalSocket`, but
  this socket is never closed by the drivers. This behaviour mirrors the
  embedded version, where there is no equivalent operation to close sockets.
- To remove the local socket file add the following target to `pc-emul/Makefile` clean target:
```Make
# pc-emul/Makefile clean target
clean:
    (...)
    make clean-eth-socket
```
