////////////////////////////////////////////////////////////////////////////////
// Top System Ethernet Template for AES-KU040-DB-G Board
//
// This file gives a template of the ports and logic that needs to be added to
// the top level for the ethernet interface.
// 
// The additions required are:
// 1. top_system module ports for ethernet interface
// 2. Logic to contatenate data pins and ethernet clock
// 3. System instance ports for ethernet interface
//
////////////////////////////////////////////////////////////////////////////////
module top_system(

        // other top_system ports
        // ....

        //
        // 1. top_system module ports for ethernet interface
        //
        output ENET_RESETN,
        input  ENET_RX_CLK,

        output ENET_GTX_CLK,
        input  ENET_RX_D0,
        input  ENET_RX_D1,
        input  ENET_RX_D2,
        input  ENET_RX_D3,
        input  ENET_RX_DV,
        output ENET_TX_D0,
        output ENET_TX_D1,
        output ENET_TX_D2,
        output ENET_TX_D3,
        output ENET_TX_EN,

        // other top_system ports
        // ...
    );

    // 
    // 2. Logic to contatenate data pins and ethernet clock
    //

    //buffered eth clock
    wire            ETH_CLK;

    //PLL
    wire            locked;

    //MII
    wire [3:0]      TX_DATA;   
    wire [3:0]      RX_DATA;

    assign {ENET_TX_D3, ENET_TX_D2, ENET_TX_D1, ENET_TX_D0} = TX_DATA;
    assign RX_DATA = {ENET_RX_D3, ENET_RX_D2, ENET_RX_D1, ENET_RX_D0};

    //eth clock
    IBUFG rxclk_buf (
          .I (ENET_RX_CLK),
          .O (ETH_CLK)
          );
    ODDRE1 ODDRE1_inst (
             .Q  (ENET_GTX_CLK),
             .C  (ETH_CLK),
             .D1 (1'b1),
             .D2 (1'b0),
             .SR (~ENET_RESETN)
             );

    assign locked = 1'b1; 

    //
    // TOP SYSTEM LOGIC
    //
    // (...)
`ifdef USE_DDR
    // AXI INTERCONNECT
    // DDR4 CONTROLLER / MIG
`endif

    //
    // SYSTEM INSTANCE
    //
    system system
        (
            // other system ports
            // ...
            
            //
            // 3. System instance ports for ethernet interface
            //

            //ETHERNET
            //PHY
            .ETH_PHY_RESETN(ENET_RESETN),

            //PLL
            .PLL_LOCKED(locked),

            //MII
            .RX_CLK(ETH_CLK),
            .RX_DATA(RX_DATA),
            .RX_DV(ENET_RX_DV),
            .TX_CLK(ETH_CLK),
            .TX_DATA(TX_DATA),
            .TX_EN(ENET_TX_EN)
        );

endmodule
