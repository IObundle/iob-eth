# IOb-eth
IObundle's ethernet core.

This core implements raw socket ethernet communication. This corresponds to the
data link layer (2) of the OSI Model.

This core is driver-compatible with the [ethmac](https://opencores.org/projects/ethmac) core, as it contains a similar SWreg interface.

This peripheral can be used as a verification tool for the [OpenCryptoTester](https://nlnet.nl/project/OpenCryptoTester#ack) project.

## Integrate in SoC ##

* Check out [IOb-SoC-SUT](https://github.com/IObundle/iob-soc-sut)

## Usage

The main class that describes this core is located in the `iob_eth.py` Python module. It contains a set of methods useful to set up and instantiate this core.

The following steps describe the process of creating an Ethernet peripheral in an IOb-SoC-based system:
1) Import the `iob_eth` class
2) Add the `iob_eth` class to the submodules list. This will copy the required sources of this module to the build directory.
3) Run the `iob_eth(...)` constructor to create a Verilog instance of the Ethernet peripheral.
4) To use this core as a peripheral of an IOb-SoC-based system:
  1) Add the created instance to the peripherals list of the IOb-SoC-based system.
  2) Use the `_setup_portmap()` method of IOb-SoC to map IOs of the Ethernet peripheral.
  3) Write the firmware to run in the system, including the `iob-eth.h` C header, and use its driver functions to control this core.
5) Set the `RMAC_ADDR` and `IOB_CONSOLE_PYTHON_ENV` environment variables, as described [here](https://github.com/IObundle/iob-soc#ethernet).

## Example configuration

The `iob_soc_sut.py` script of the [IOb-SoC-SUT](https://github.com/IObundle/iob-soc-sut) system, uses the following lines of code to instantiate an Ethernet peripheral with the instance name `ETH0`:
```Python
# Import the iob_eth class
from iob_eth import iob_eth

# Class of the SUT system
class iob_soc_sut(iob_soc):
  ...
  @classmethod
  def _create_submodules_list(cls):
      """Create submodules list with dependencies of this module"""
      super()._create_submodules_list(
          [
              iob_eth,
              ...
          ]
      )
  # Method that runs the setup process of the SUT system
  @classmethod
  def _specific_setup(cls):
    ...
    # Create a Verilog instance of this module, named 'ETH0', and add it to the peripherals list of the system.
    cls.peripherals.append(
        iob_eth(
            "ETH0",
            "Ethernet interface",
            # These parameters configure the core's memory interface to match the system's memory.
            parameters={
                "AXI_ID_W": "AXI_ID_W",
                "AXI_LEN_W": "AXI_LEN_W",
                "AXI_ADDR_W": "AXI_ADDR_W",
                "AXI_DATA_W": "AXI_DATA_W",
                "MEM_ADDR_OFFSET": "MEM_ADDR_OFFSET",
            },
        )
    )
  ...
  # SUT system method to map IOs of peripherals
  @classmethod
  def _setup_portmap(cls):
      super()._setup_portmap()
      cls.peripheral_portmap += [
          ...
          # ETH0 IO --- Connect IOs of the Ethernet core
          # interrupt - connect to interrupt signal
          (
              {
                  "corename": "ETH0",
                  "if_name": "general",
                  "port": "inta_o",
                  "bits": [],
              },
              {
                  "corename": "internal",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          # phy - connect to external interface
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MTxClk",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MTxD",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MTxEn",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MTxErr",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MRxClk",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MRxDv",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MRxD",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MRxErr",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MColl",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MCrS",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MDC",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "MDIO",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
          (
              {
                  "corename": "ETH0",
                  "if_name": "phy",
                  "port": "phy_rstn_o",
                  "bits": [],
              },
              {
                  "corename": "external",
                  "if_name": "ETH0",
                  "port": "",
                  "bits": [],
              },
          ),
      ]
  ...
  @classmethod
  def _post_setup(cls):
    ...
        if cls.is_top_module:
            # Append ethernet variables to the `config_build.mk` file of the build directory
            append_str_config_build_mk(
                """
                # Mac address of PC network interface connected to the ethernet peripheral
                RMAC_ADDR ?=989096c0632c
                export RMAC_ADDR
                # Path to custom python interpreter with `CAP_NET_RAW` capability
                IOB_CONSOLE_PYTHON_ENV ?= /opt/pyeth3/bin/python
                """,
                cls.build_dir,
            )
```

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
- ethernet simulation has an internal reset counter, configurable by a Verilog parameter
  - check for `PHY_RST_CNT` in `ETHERNET/hardware/src/iob_eth.v` for more details
### No permissions to open raw sockets
- Running raw sockets requires elevated privileges. This is solved by 
configuring a dedicated python3 virtual environment where the interpreter has 
raw socket capabilities.
### No data transferred between the Host Machine and FPGA Board:
- Make sure that the interface is configured with `speed = 100Mb/s` and `duplex = full`
  - check interface status with: `ethtool $RMAC_INTERFACE`
    - check the `speed`, `duplex`, and `Auto-negotiation` fields
- you can setup the interface with:
  ```
  sudo ethtool -s $RMAC_INTERFACE speed 100 duplex full autoneg off
  ```
### `Failed to bind socket` on PC-Emul
- The pc-emul drivers create a local socket file in `/tmp/tmpLocalSocket`, but
  this socket is never closed by the drivers. This behavior mirrors the
  embedded version, where there is no equivalent operation to close sockets.
- To remove the local socket file add the following target to `pc-emul/Makefile` clean target:
```Make
# pc-emul/Makefile clean target
clean:
    (...)
    make clean-eth-socket
```

## Brief description of C interface ##

List of available bare-metal driver functions:

```C
// Alternative to `eth_init_clear_cache` and `eth_init_mac`. Auto-initializes MAC addresses.
void eth_init(int base_address, void (*clear_cache_func)(void));

// Set function to clear cache
void eth_init_clear_cache( void (*clear_cache_func)(void) );

// Set Ethernet base address and MAC addresses
void eth_init_mac(int base_address, uint64_t mac_addr, uint64_t dest_mac_addr);

// Get payload size from the given buffer descriptor
unsigned short int eth_get_payload_size(unsigned int idx);

// Set payload size in the given buffer descriptor
void eth_set_payload_size(unsigned int idx, unsigned int size);

// Care when using this function directly, too small a size or too large might not work (frame does not get sent)
void eth_send_frame(char *data_to_send, unsigned int size);

/* Function name: eth_rcv_frame
 * Inputs:
 * 	- data_rcv: char array where data received will be saved
 * 	- size: number of bytes to be received
 * 	- timeout: number of cycles (approximately) in which the data should be received
 * Output: 
 * 	- Return -1 if a timeout occurs (no data received), or 0 if data is
 * 	successfully received
 */
int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout);

// Set timeout for receive operations
void eth_set_receive_timeout(unsigned int timeout);

// Receive a file
unsigned int eth_rcv_file(char *data, int size);

// Send a file
unsigned int eth_send_file(char *data, int size);

// Receive a file of unknown size
unsigned int eth_rcv_variable_file(char *data);

// Send a file and send the file size during the handshake, so that the receiver can know its size
unsigned int eth_send_variable_file(char *data, int size);

// Delay until phy reset is released
void eth_wait_phy_rst();

// Print ethernet status
void eth_print_status(void);
```

## Generate Quartus IP

Use the following command to generate the `ddio_out_clkbuf` IP module.
```
/opt/intelFPGA/20.1/nios2eds/nios2_command_shell.sh qmegawiz -silent wizard=altddio_out \
INTENDED_DEVICE_FAMILY="Cyclone V" \
INVERT_OUTPUT=OFF \
LPM_HINT=UNUSED \
LPM_TYPE=altddio_out \
WIDTH=1 \
DEVICE_FAMILY="Cyclone V" \
CBX_AUTO_BLACKBOX=ALL \
ddio_out_clkbuf.v
```

More info: https://cdrdv2-public.intel.com/705131/ug_intro_to_megafunctions_131-683102-705131.pdf


# Acknowledgement
The [OpenCryptoTester](https://nlnet.nl/project/OpenCryptoTester#ack) project is funded through the NGI Assure Fund, a fund established by NLnet
with financial support from the European Commission's Next Generation Internet
programme, under the aegis of DG Communications Networks, Content and Technology
under grant agreement No 957073.

<table>
    <tr>
        <td align="center" width="50%"><img src="https://nlnet.nl/logo/banner.svg" alt="NLnet foundation logo" style="width:90%"></td>
        <td align="center"><img src="https://nlnet.nl/image/logos/NGIAssure_tag.svg" alt="NGI Assure logo" style="width:90%"></td>
    </tr>
</table>
