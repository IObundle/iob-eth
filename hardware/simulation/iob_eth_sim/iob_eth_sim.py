# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    params = {
        # Type of interface for CSR bus
        "csr_if": "iob",
    }

    # Update params with values from py_params_dict
    for param in py_params_dict:
        if param in params:
            params[param] = py_params_dict[param]

    attributes_dict = {
        "name": "iob_uut",
        "generate_hw": True,
        "confs": [
            # ETH parameters
            {
                "name": "DATA_W",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "128",
                "descr": "Data bus width",
            },
            {
                "name": "ADDR_W",
                "type": "P",
                "val": "(12+2)",
                "min": "NA",
                "max": "128",
                "descr": "Address bus width",
            },
            # ETH External memory interface
            {
                "name": "AXI_ID_W",
                "type": "P",
                "val": "0",
                "min": "0",
                "max": "32",
                "descr": "AXI ID bus width",
            },
            {
                "name": "AXI_ADDR_W",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "32",
                "descr": "AXI address bus width",
            },
            {
                "name": "AXI_DATA_W",
                "type": "P",
                "val": "DATA_W",
                "min": "1",
                "max": "32",
                "descr": "AXI data bus width",
            },
            {
                "name": "AXI_LEN_W",
                "type": "P",
                "val": "4",
                "min": "1",
                "max": "4",
                "descr": "AXI burst length width",
            },
            # Ethernet
            {
                "name": "PHY_RST_CNT",
                "type": "P",
                "val": "20'hFFFFF",
                "min": "NA",
                "max": "NA",
                "descr": "PHY reset counter value. Sets the duration of the PHY reset signal",
            },
            {
                "name": "BD_NUM_LOG2",
                "type": "P",
                "val": "7",
                "min": "NA",
                "max": "7",
                "descr": "Log2 amount of buffer descriptors",
            },
            {
                "name": "BUFFER_W",
                "type": "P",
                "val": "11",
                "min": "0",
                "max": "32",
                "descr": "Buffer size",
            },
        ],
    }
    #
    # Ports
    #
    attributes_dict["ports"] = [
        {
            "name": "clk_en_rst_s",
            "descr": "Clock, clock enable and reset",
            "signals": {
                "type": "iob_clk",
            },
        },
        {
            "name": "pbus_s",
            "descr": "Testbench eth sim wrapper csrs interface",
            "signals": {
                "type": "iob",
                "ADDR_W": "(12+2)",
            },
        },
    ]
    #
    # Wires
    #
    attributes_dict["wires"] = [
        {
            "name": "split_reset",
            "descr": "Reset signal for iob_split components",
            "signals": [
                {"name": "arst_i"},
            ],
        },
        # AXISTREAM IN
        {
            "name": "axistream_in_interrupt",
            "descr": "Interrupt signal",
            "signals": [
                {
                    "name": "axistream_in_interrupt",
                    "width": "1",
                },
            ],
        },
        {
            "name": "axistream_in_axis",
            "descr": "AXI Stream interface signals",
            "signals": [
                {
                    "name": "axis_clk",
                    "width": "1",
                    "descr": "Clock.",
                },
                {
                    "name": "axis_cke",
                    "width": "1",
                    "descr": "Clock enable",
                },
                {
                    "name": "axis_arst",
                    "width": "1",
                    "descr": "Asynchronous and active high reset.",
                },
                {
                    "name": "axis_tdata",
                    "width": "DATA_W",
                    "descr": "Data.",
                },
                {
                    "name": "axis_tvalid",
                    "width": "1",
                    "descr": "Valid.",
                },
                {
                    "name": "axis_tready",
                    "width": "1",
                    "descr": "Ready.",
                },
                {
                    "name": "axis_tlast",
                    "width": "1",
                    "descr": "Last word.",
                },
            ],
        },
        {
            "name": "axistream_in_csrs",
            "descr": "axistream_in CSRs interface",
            "signals": {
                "type": "iob",
                "prefix": "axistream_in_csrs_",
                "ADDR_W": 10 - 2,
            },
        },
        # AXISTREAM OUT
        {
            "name": "axistream_out_interrupt",
            "descr": "Interrupt signal",
            "signals": [
                {
                    "name": "axistream_out_interrupt",
                    "width": "1",
                },
            ],
        },
        {
            "name": "axistream_out_axis",
            "descr": "AXI Stream interface signals",
            "signals": [
                {
                    "name": "axis_clk",
                    "width": "1",
                    "descr": "Clock.",
                },
                {
                    "name": "axis_cke",
                    "width": "1",
                    "descr": "Clock enable",
                },
                {
                    "name": "axis_arst",
                    "width": "1",
                    "descr": "Asynchronous and active high reset.",
                },
                {
                    "name": "axis_tdata",
                    "width": "DATA_W",
                    "descr": "Data.",
                },
                {
                    "name": "axis_tvalid",
                    "width": "1",
                    "descr": "Valid.",
                },
                {
                    "name": "axis_tready",
                    "width": "1",
                    "descr": "Ready.",
                },
                {
                    "name": "axis_tlast",
                    "width": "1",
                    "descr": "Last word.",
                },
            ],
        },
        {
            "name": "axistream_out_csrs",
            "descr": "axistream_out CSRs interface",
            "signals": {
                "type": "iob",
                "prefix": "axistream_out_csrs_",
                "ADDR_W": 10 - 2,
            },
        },
        # Ethernet
        {
            "name": "inta",
            "descr": "ethernet interrupt wire",
            "signals": [
                {"name": "inta"},
            ],
        },
        {
            "name": "phy_wires",
            "descr": "ethernet PHY interface wires",
            "signals": [
                {"name": "mtx_clk", "width": "1"},
                {"name": "mtx_en", "width": "1"},
                {"name": "mtx_d", "width": "4"},
                {"name": "mtx_err", "width": "1"},
                {"name": "mrx_clk", "width": "1"},
                {"name": "mrx_dv", "width": "1"},
                {"name": "mrx_d", "width": "4"},
                {"name": "mrx_err", "width": "1"},
                {"name": "mcoll", "width": "1"},
                {"name": "mcrs", "width": "1"},
                {"name": "mdc", "width": "1"},
                {"name": "mdio", "width": "1"},
                {"name": "phy_rstn", "width": "1"},
            ],
        },
        {
            "name": "eth_csrs",
            "descr": "eth CSRs interface",
            "signals": {
                "type": "iob",
                "prefix": "eth_csrs_",
                "ADDR_W": 10 - 2,
            },
        },
        # DMA
        {
            "name": "dma_csrs",
            "descr": "dma CSRs interface",
            "signals": {
                "type": "iob",
                "prefix": "dma_csrs_",
                "ADDR_W": 10 - 2,
            },
        },
        # Other
        {
            "name": "mii_cnt_en_rst",
            "descr": "mii counter reset and enable wires",
            "signals": [
                {"name": "mii_cnt_en", "width": 1},
                {"name": "mii_cnt_rst", "width": 1},
            ],
        },
        {
            "name": "mii_cnt",
            "descr": "mii counter output",
            "signals": [
                {"name": "mii_cnt", "width": 2},
            ],
        },
        {
            "name": "dma_axi",
            "descr": "DMA AXI connection wires",
            "signals": {
                "type": "axi",
                "prefix": "dma_",
                "ADDR_W": "AXI_ADDR_W",
            },
        },
        {
            "name": "eth_axi",
            "descr": "ETH AXI connection wires",
            "signals": {
                "type": "axi",
                "prefix": "eth_",
                "ADDR_W": "AXI_ADDR_W",
            },
        },
        {
            "name": "clk",
            "descr": "Clock signal",
            "signals": [
                {"name": "clk_i"},
            ],
        },
        {
            "name": "rst",
            "descr": "Reset signal",
            "signals": [
                {"name": "arst_i"},
            ],
        },
        {
            "name": "dma_axis_out",
            "descr": "AXIS OUT <-> DMA connection wires",
            "signals": [
                {"name": "axis_out_tdata", "width": "AXI_DATA_W"},
                {"name": "axis_out_tvalid", "width": "1"},
                {"name": "axis_out_tready", "width": "1"},
            ],
        },
        {
            "name": "dma_axis_in",
            "descr": "AXIS IN <-> DMA connection wires",
            "signals": [
                {"name": "axis_in_tdata", "width": "AXI_DATA_W"},
                {"name": "axis_in_tvalid", "width": "1"},
                {"name": "axis_in_tready", "width": "1"},
            ],
        },
        {
            "name": "interconnect_clk",
            "descr": "AXI interconnect clock",
            "signals": [
                {"name": "clk_i", "width": 1},
            ],
        },
        {
            "name": "interconnect_rst",
            "descr": "AXI interconnect reset",
            "signals": [
                {"name": "arst_i", "width": 1},
            ],
        },
        {
            "name": "interconnect_s_axi",
            "descr": "AXI subordinate bus for interconnect",
            "signals": {
                "type": "axi",
                "prefix": "intercon_s_",
                "mult": 2,
                "ID_W": "AXI_ID_W",
                "ADDR_W": "AXI_ADDR_W",
                "DATA_W": "AXI_DATA_W",
                "LOCK_W": 2,
            },
        },
        {
            "name": "interconnect_m_axi",
            "descr": "AXI manager bus for interconnect",
            "signals": {
                "type": "axi",
                "prefix": "intercon_m_",
                "mult": 1,
                "ID_W": "AXI_ID_W",
                "ADDR_W": "AXI_ADDR_W",
                "DATA_W": "AXI_DATA_W",
                "LOCK_W": 1,
            },
        },
        {
            "name": "axi_ram_mem",
            "descr": "Connect axi_ram to 'iob_ram_t2p_be' memory",
            "signals": {
                "type": "ram_t2p_be",
                "ADDR_W": "AXI_ADDR_W - 2",
                "prefix": "ext_mem_",
            },
        },
    ]
    #
    # Blocks
    #
    attributes_dict["subblocks"] = [
        {
            "core_name": "iob_counter",
            "instance_name": "mii_counter_inst",
            "instance_description": "ETH clk counter: 4x slower than system clk",
            "parameters": {
                "DATA_W": "2",
                "RST_VAL": "{2{1'b0}}",
            },
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "en_rst_i": "mii_cnt_en_rst",
                "data_o": "mii_cnt",
            },
        },
        {
            "core_name": "iob_axistream_in",
            "instance_name": "axistream_in0",
            "instance_description": "AXIS IN test instrument",
            "parameters": {
                "ADDR_W": "(ADDR_W-2)",
                "DATA_W": "DATA_W",
                "TDATA_W": "DATA_W",
                "FIFO_ADDR_W": "AXI_ADDR_W",
            },
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "interrupt_o": "axistream_in_interrupt",
                "axistream_io": "axistream_in_axis",
                "sys_axis_io": "dma_axis_in",
                "iob_csrs_cbus_s": (
                    "axistream_in_csrs",
                    ["axistream_in_csrs_iob_addr[2:0]"],
                ),
            },
        },
        {
            "core_name": "iob_axistream_out",
            "instance_name": "axistream_out0",
            "instance_description": "AXIS OUT test instrument",
            "parameters": {
                "ADDR_W": "(ADDR_W-2)",
                "DATA_W": "DATA_W",
                "TDATA_W": "DATA_W",
                "FIFO_ADDR_W": "AXI_ADDR_W",
            },
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "interrupt_o": "axistream_out_interrupt",
                "axistream_io": "axistream_out_axis",
                "sys_axis_io": "dma_axis_out",
                "iob_csrs_cbus_s": (
                    "axistream_out_csrs",
                    ["axistream_out_csrs_iob_addr[2:0]"],
                ),
            },
        },
        {
            "core_name": "iob_split",
            "name": "tb_pbus_split",
            "instance_name": "iob_pbus_split",
            "instance_description": "Split between testbench peripherals",
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "reset_i": "split_reset",
                "input_s": ("pbus_s", ["iob_addr_i[11:2]"]),  # Ignore 2 LSBs
                "output_0_m": "axistream_in_csrs",
                "output_1_m": "axistream_out_csrs",
                "output_2_m": "dma_csrs",
                "output_3_m": "eth_csrs",
            },
            "num_outputs": 4,
            "addr_w": 12 - 2,
        },
        {
            "core_name": "iob_eth",
            "instance_name": "eth_inst",
            "instance_description": "Unit Under Test (UUT) DMA instance.",
            "parameters": {
                "DATA_W": "DATA_W",
                "ADDR_W": "(ADDR_W-2)",
                "AXI_ADDR_W": "AXI_ADDR_W",
                "AXI_DATA_W": "AXI_DATA_W",
            },
            "csr_if": "iob",
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "iob_csrs_cbus_s": "eth_csrs",
                "axi_m": "eth_axi",
                "inta_o": "inta",
                "phy_io": "phy_wires",
            },
        },
        {
            "core_name": "iob_dma",
            "instance_name": "dma_inst",
            "instance_description": "DMA test instrument.",
            "parameters": {
                "DATA_W": "DATA_W",
                "ADDR_W": "(ADDR_W-2)",
                "AXI_ADDR_W": "AXI_ADDR_W",
                "AXI_DATA_W": "AXI_DATA_W",
            },
            "csr_if": "iob",
            "connect": {
                "clk_en_rst_s": "clk_en_rst_s",
                "rst_i": "rst",
                "iob_csrs_cbus_s": ("dma_csrs", ["dma_csrs_iob_addr[2:0]"]),
                "dma_input_io": "dma_axis_in",
                "dma_output_io": "dma_axis_out",
                "axi_m": "dma_axi",
            },
        },
        {
            "core_name": "iob_axi_interconnect",
            "instance_name": "iob_axi_interconnect_ram",
            "instance_description": "Interconnect core: DMA + ETH managers, AXI RAM subordinate",
            "parameters": {
                "ID_WIDTH": "AXI_ID_W",
                "DATA_WIDTH": "AXI_DATA_W",
                "ADDR_WIDTH": "AXI_ADDR_W",
                "S_COUNT": 2,
                "M_COUNT": 1,
                "M_ADDR_WIDTH": "AXI_ADDR_W",
            },
            "connect": {
                "clk_i": "interconnect_clk",
                "rst_i": "interconnect_rst",
                "s_axi_s": "interconnect_s_axi",
                "m_axi_m": "interconnect_m_axi",
            },
        },
        {
            "core_name": "iob_axi_ram",
            "instance_name": "axi_ram_inst",
            "instance_description": "AXI RAM test instrument to connect to DMA",
            "parameters": {
                "ID_WIDTH": "AXI_ID_W",
                "ADDR_WIDTH": "AXI_ADDR_W",
                "DATA_WIDTH": "AXI_DATA_W",
            },
            "connect": {
                "clk_i": "clk",
                "rst_i": "rst",
                "axi_s": "interconnect_m_axi",
                "external_mem_bus_m": "axi_ram_mem",
            },
        },
        {
            "core_name": "iob_ram_t2p_be",
            "instance_name": "iob_ram_t2p_be_inst",
            "instance_description": "AXI RAM external memory",
            "parameters": {
                "ADDR_W": "AXI_ADDR_W - 2",
                "DATA_W": "AXI_DATA_W",
            },
            "connect": {
                "ram_t2p_be_s": "axi_ram_mem",
            },
        },
    ]

    #
    # Snippets
    #
    attributes_dict["snippets"] = []
    snippet_code = """ """
    snippet_code += """
    assign axis_clk = clk_i;
    assign axis_cke = cke_i;
    assign axis_arst = arst_i;

    // MII Counter
    assign mii_cnt_en = 1'b1;
    assign mii_cnt_rst = 1'b0;

    // Ethernet PHY Interface loopback
    assign mtx_clk = mii_cnt[1];
    assign mrx_clk = mii_cnt[1];
    assign mrx_dv = mtx_en;
    assign mrx_d = mtx_d;
    assign mrx_err = 1'b0;
    assign mcoll = 1'b0;
    assign mcrs = 1'b0;
"""

    # TODO: connect interconnect subordinate interfaces
    # Connect all Manager AXI interfaces to interconnect
    AXI_IN_SIGNAL_NAMES = [
        ("araddr", "AXI_ADDR_W"),
        ("arvalid", 1),
        ("rready", 1),
        ("arid", "AXI_ID_W"),
        ("arlen", 8),
        ("arsize", 3),
        ("arburst", 2),
        ("arlock", 1),
        ("arcache", 4),
        ("arqos", 4),
        ("awaddr", "AXI_ADDR_W"),
        ("awvalid", 1),
        ("wdata", "AXI_DATA_W"),
        ("wstrb", "AXI_DATA_W / 8"),
        ("wvalid", 1),
        ("bready", 1),
        ("awid", "AXI_ID_W"),
        ("awlen", 8),
        ("awsize", 3),
        ("awburst", 2),
        ("awlock", 1),
        ("awcache", 4),
        ("awqos", 4),
        ("wlast", 1),
    ]
    AXI_OUT_SIGNAL_NAMES = [
        ("arready", 1),
        ("rdata", "AXI_DATA_W"),
        ("rresp", 2),
        ("rvalid", 1),
        ("rid", "AXI_ID_W"),
        ("rlast", 1),
        ("awready", 1),
        ("wready", 1),
        ("bresp", 2),
        ("bvalid", 1),
        ("bid", "AXI_ID_W"),
    ]
    MANAGERS = ["eth", "dma"]

    snippet_code += "    // Connect all manager AXI interfaces to interconnect\n"
    for sig_name, _ in AXI_OUT_SIGNAL_NAMES:
        assign_str = ""
        for manager_name in MANAGERS:
            prefix = f"{manager_name}_"
            assign_str = f"{prefix}axi_{sig_name}, " + assign_str
        assign_str = assign_str[:-2]
        snippet_code += (
            f"    assign intercon_m_axi_{sig_name} = {{" + assign_str + "};\n"
        )

    for sig_name, sig_size in AXI_IN_SIGNAL_NAMES:
        for idx, manager_name in enumerate(MANAGERS):
            prefix = f"{manager_name}_"
            bit_select = ""
            if type(sig_size) is not int or sig_size > 1:
                bit_select = f"[{idx}*{sig_size}+:{sig_size}]"
            else:
                bit_select = f"[{idx}]"
            snippet_code += f"    assign {prefix}axi_{sig_name} = intercon_m_axi_{sig_name}{bit_select}; \n"

    attributes_dict["snippets"] += [
        {"verilog_code": snippet_code},
    ]

    return attributes_dict
