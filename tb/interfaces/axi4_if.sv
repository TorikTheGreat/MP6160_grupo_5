interface axi4_if #(
    parameter int DATA_W = 64,
    parameter int ADDR_W = 32,
    parameter int ID_W = 4
) (
    input logic aclk,
    input logic aresetn
);

    // Canales de Escritura (AW, W, B)
    logic [ID_W-1:0]   awid;
    logic [ADDR_W-1:0] awaddr;
    logic [7:0]        awlen;
    logic [2:0]        awsize;
    logic [1:0]        awburst;
    logic              awvalid;
    logic              awready;
    logic [2:0]        awprot;
    logic [3:0]        awcache;
    logic [1:0]        awlock;
    logic [3:0]        awqos;

    logic [DATA_W-1:0] wdata;
    logic [(DATA_W/8)-1:0] wstrb;
    logic              wlast;
    logic              wvalid;
    logic              wready;

    logic [ID_W-1:0]   bid;
    logic [1:0]        bresp;
    logic              bvalid;
    logic              bready;

    // Canales de Lectura (AR, R)
    logic [ID_W-1:0]   arid;
    logic [ADDR_W-1:0] araddr;
    logic [7:0]        arlen;
    logic [2:0]        arsize;
    logic [1:0]        arburst;
    logic              arvalid;
    logic              arready;
    logic [2:0]        arprot;
    logic [3:0]        arcache;
    logic [1:0]        arlock;
    logic [3:0]        arqos;

    logic [ID_W-1:0]   rid;
    logic [DATA_W-1:0] rdata;
    logic [1:0]        rresp;
    logic              rlast;
    logic              rvalid;
    logic              rready;

    // Modport para el DUT (Esclavo)
    modport slave (
        input  aclk, aresetn,
        input  awid, awaddr, awlen, awsize, awburst, awvalid, awprot, awcache, awlock, awqos,
        output awready,
        input  wdata, wstrb, wlast, wvalid,
        output wready,
        output bid, bresp, bvalid,
        input  bready,
        input  arid, araddr, arlen, arsize, arburst, arvalid, arprot, arcache, arlock, arqos,
        output arready,
        output rid, rdata, rresp, rlast, rvalid,
        input  rready
    );

    // Modport para el Testbench / BFM (Maestro)
    modport master (
        input  aclk, aresetn,
        output awid, awaddr, awlen, awsize, awburst, awvalid, awprot, awcache, awlock, awqos,
        input  awready,
        output wdata, wstrb, wlast, wvalid,
        input  wready,
        input  bid, bresp, bvalid,
        output bready,
        output arid, araddr, arlen, arsize, arburst, arvalid, arprot, arcache, arlock, arqos,
        input  arready,
        input  rid, rdata, rresp, rlast, rvalid,
        output rready
    );

    // --- SVA Protocol Checkers ---
    
    // 1. Handshakes y 2. $stable
    property p_aw_handshake;
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> awvalid && $stable(awaddr) && $stable(awlen) && $stable(awsize);
    endproperty
    assert property(p_aw_handshake) else $error("AWVALID cayó o sus variables mutaron sin AWREADY");

    property p_w_handshake;
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> wvalid && $stable(wdata) && $stable(wstrb) && $stable(wlast);
    endproperty
    assert property(p_w_handshake) else $error("WVALID cayó o data mutó sin WREADY");

    // 4. Regla de 4 KB (Ejemplo para AW - una ráfaga no puede cruzar una frontera de 4KB)
    property p_4kb_rule_aw;
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> ((awaddr[11:0] + ((awlen + 1) * (1 << awsize))) <= 4096);
    endproperty
    assert property(p_4kb_rule_aw) else $error("Ráfaga de escritura cruza el límite de 4KB");

endinterface
