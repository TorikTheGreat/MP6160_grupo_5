//=============================================================================
// tb_setup_axi4if.vh -- arnes con axi4_if + wrapper del DUT.
//
// Reutiliza tb_common.vh y axi4_master_bfm.vh sin tocar el nucleo RTL:
// - el BFM maneja senales planas (aw*, w*, ar*, ...),
// - este arnes las puentea hacia axi4_if,
// - el wrapper axi4_ram_slave_axi4if conecta la interfaz al nucleo plano.
//=============================================================================

    //-------------------------------------------------------------------------
    // Reloj y reset
    //-------------------------------------------------------------------------
    reg aclk    = 1'b0;
    reg aresetn = 1'b0;

    //-------------------------------------------------------------------------
    // Senales del bus (lado BFM)
    //-------------------------------------------------------------------------
    reg  [ID_W-1:0]       awid    = 0;
    reg  [ADDR_W-1:0]     awaddr  = 0;
    reg  [7:0]            awlen   = 0;
    reg  [2:0]            awsize  = 3'b011;
    reg  [1:0]            awburst = 2'b01;
    reg                   awvalid = 0;
    wire                  awready;

    reg  [DATA_W-1:0]     wdata   = 0;
    reg  [DATA_W/8-1:0]   wstrb   = 0;
    reg                   wlast   = 0;
    reg                   wvalid  = 0;
    wire                  wready;

    wire [ID_W-1:0]       bid;
    wire [1:0]            bresp;
    wire                  bvalid;
    reg                   bready  = 1;

    reg  [ID_W-1:0]       arid    = 0;
    reg  [ADDR_W-1:0]     araddr  = 0;
    reg  [7:0]            arlen   = 0;
    reg  [2:0]            arsize  = 3'b011;
    reg  [1:0]            arburst = 2'b01;
    reg                   arvalid = 0;
    wire                  arready;

    wire [ID_W-1:0]       rid;
    wire [DATA_W-1:0]     rdata;
    wire [1:0]            rresp;
    wire                  rlast;
    wire                  rvalid;
    reg                   rready  = 1;

    //-------------------------------------------------------------------------
    // Interfaz AXI4 + wrapper del DUT
    //-------------------------------------------------------------------------
    axi4_if #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W),
        .ID_W  (ID_W)
    ) axi (
        .aclk(aclk),
        .aresetn(aresetn)
    );

    axi4_ram_slave_axi4if #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W),
        .ID_W  (ID_W),
        .MEM_WORDS(MEM_WORDS)
    ) dut (
        .axi(axi)
    );

    //-------------------------------------------------------------------------
    // Puente de senales planas (BFM) <-> interfaz axi4_if
    //-------------------------------------------------------------------------
    assign axi.awid    = awid;
    assign axi.awaddr  = awaddr;
    assign axi.awlen   = awlen;
    assign axi.awsize  = awsize;
    assign axi.awburst = awburst;
    assign axi.awvalid = awvalid;
    assign awready     = axi.awready;

    assign axi.wdata   = wdata;
    assign axi.wstrb   = wstrb;
    assign axi.wlast   = wlast;
    assign axi.wvalid  = wvalid;
    assign wready      = axi.wready;

    assign bid         = axi.bid;
    assign bresp       = axi.bresp;
    assign bvalid      = axi.bvalid;
    assign axi.bready  = bready;

    assign axi.arid    = arid;
    assign axi.araddr  = araddr;
    assign axi.arlen   = arlen;
    assign axi.arsize  = arsize;
    assign axi.arburst = arburst;
    assign axi.arvalid = arvalid;
    assign arready     = axi.arready;

    assign rid         = axi.rid;
    assign rdata       = axi.rdata;
    assign rresp       = axi.rresp;
    assign rlast       = axi.rlast;
    assign rvalid      = axi.rvalid;
    assign axi.rready  = rready;

    // Campos no usados por el nucleo, pero presentes en la interfaz.
    initial begin
        axi.awprot  = 3'b000;
        axi.awcache = 4'b0000;
        axi.awlock  = 1'b0;
        axi.awqos   = 4'b0000;
        axi.arprot  = 3'b000;
        axi.arcache = 4'b0000;
        axi.arlock  = 1'b0;
        axi.arqos   = 4'b0000;
    end

    // Vista unificada de memoria para los checkers del banco.
    function automatic [DATA_W-1:0] peek_mem;
        input integer idx;
        begin
            peek_mem = dut.core.mem[idx];
        end
    endfunction

    localparam [31:0] MEM_BYTES_TB = MEM_WORDS * 8;

    `include "tb_common.vh"
    `include "axi4_master_bfm.vh"
