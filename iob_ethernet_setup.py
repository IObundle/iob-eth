#!/usr/bin/env python3

import os, sys
sys.path.insert(0, os.getcwd()+'/submodules/LIB/scripts')
import setup

meta = \
{
'name':'iob_ethernet',
'version':'V0.10',
'flows':'sim emb',
'setup_dir':os.path.dirname(__file__)}
meta['build_dir']=f"../{meta['name']+'_'+meta['version']}"
meta['submodules'] = {
    'hw_setup': {
        'headers' : [ 'iob_s_port', 'iob_s_portmap' ],
        'modules': [ 'iob_reg.v', 'iob_reg_e.v' ]
    },
}

confs = \
[
    # Macros

    # Parameters
    {'name':'DATA_W',      'type':'P', 'val':'32', 'min':'NA', 'max':'NA', 'descr':"Data bus width"},
    {'name':'ADDR_W',      'type':'P', 'val':'`IOB_ETHERNET_SWREG_ADDR_W', 'min':'NA', 'max':'NA', 'descr':"Address bus width"},
    {'name':'ETH_MAC_ADDR','type':'P', 'val':'`ETH_MAC_ADDR', 'min':'NA', 'max':'NA', 'descr':"Ethernet MAC address"},
    {'name':'PHY_RST_CNT', 'type':'P', 'val':"\"20'hFFFFF\"", 'min':'NA', 'max':'NA', 'descr':"Reset counter value"},
]

ios = \
[
    {'name': 'iob_s_port', 'descr':'CPU native interface', 'ports': [
    ]},
    {'name': 'general', 'descr':'General interface signals', 'ports': [
        {'name':"clk_i" , 'type':"I", 'n_bits':'1', 'descr':"System clock input"},
        {'name':"arst_i", 'type':"I", 'n_bits':'1', 'descr':"System reset, asynchronous and active high"},
        {'name':"cke_i" , 'type':"I", 'n_bits':'1', 'descr':"System reset, asynchronous and active high"}
    ]},
    {'name': 'ethernet', 'descr':'Ethernet interface', 'ports': [
        {'name':'ETH_PHY_RESETN', 'type':'O', 'n_bits':'1', 'descr':'PHY reset'},
        {'name':'PLL_LOCKED', 'type':'I', 'n_bits':'1', 'descr':'PLL locked'},
        # RX
        {'name':'RX_CLK', 'type':'I', 'n_bits':'1', 'descr':'RX clock'},
        {'name':'RX_DATA', 'type':'I', 'n_bits':'4', 'descr':'RX data nibble'},
        {'name':'RX_DV', 'type':'I', 'n_bits':'1', 'descr':'RX DV signal'},
        # TX
        {'name':'TX_CLK', 'type':'I', 'n_bits':'1', 'descr':'TX clock'},
        {'name':'TX_EN', 'type':'O', 'n_bits':'1', 'descr':'TX enable'},
        {'name':'TX_DATA', 'type':'O', 'n_bits':'4', 'descr':'TX data nibble'},
    ]}
]

regs = \
[
    {'name': 'ethernet', 'descr':'Ethernet software accessible registers.', 'regs': [
        {'name':'ETH_STATUS', 'type':'R', 'n_bits':4, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Ethernet core status flags.'},
        {'name':'ETH_SEND', 'type':'W', 'n_bits':1, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Trigger send operation.'},
        {'name':'ETH_RCVACK', 'type':'W', 'n_bits':1, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Acknowledge frame reception.'},
        {'name':'ETH_SOFTRST', 'type':'W', 'n_bits':1, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Reset ethernet core.'},
        {'name':'ETH_DUMMY_W', 'type':'W', 'n_bits':4, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Dummy SWREG for writting configuration.'},
        {'name':'ETH_DUMMY_R', 'type':'R', 'n_bits':4, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Dummy SWREG for reading configuration.'},
        {'name':'ETH_TX_NBYTES', 'type':'W', 'n_bits':2, 'rst_val':46, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Number of bytes for outcomming frames. '},
        {'name':'ETH_CRC', 'type':'R', 'n_bits':4, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'CRC of last received frame.'},
        {'name':'ETH_RCV_SIZE', 'type':'R', 'n_bits':2, 'rst_val':0, 'addr':-1, 'log2n_items':0, 'autologic':True, 'descr':'Number of bytes of last received frame.'},
        {'name':'ETH_DATA_WR', 'type':'W', 'n_bits':1, 'rst_val':0, 'addr':-1, 'log2n_items':11, 'autologic':True, 'descr':'TX Buffer.'},
        {'name':'ETH_DATA_RD', 'type':'R', 'n_bits':1, 'rst_val':0, 'addr':-1, 'log2n_items':11, 'autologic':True, 'descr':'RX Buffer.'},
    ]}
]

blocks = []

# Main function to setup this core and its components
def main():
    setup.setup(sys.modules[__name__])

if __name__ == "__main__":
    main()
