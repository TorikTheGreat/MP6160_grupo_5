//=============================================================================
// tb_setup.vh -- declaraciones del bus + instancia del DUT + arnes + BFM.
// Cada tb_stage*.v se reduce a: parametros, `include "tb_setup.vh"`, y su
// propio initial con la prueba.
//
// El ORDEN de este fichero importa: aclk y aresetn tienen que estar declarados
// ANTES de la instancia del DUT (si no, Verilog crea wires implicitos y el
// reloj no llega), y tb_common.vh va DESPUES de la instancia porque su checker
// de reset usa bvalid/rvalid.
//=============================================================================

    //-------------------------------------------------------------------------
    // Reloj y reset
    //-------------------------------------------------------------------------
    reg aclk    = 1'b0;
    reg aresetn = 1'b0;

    //-------------------------------------------------------------------------
    // Senales del bus
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
    // DUT. Se llama SIEMPRE `dut`: tb_common.vh y el BFM lo referencian asi.
    //-------------------------------------------------------------------------
    axi4_ram_slave #(
        .DATA_W    (DATA_W),
        .ADDR_W    (ADDR_W),
        .ID_W      (ID_W),
        .MEM_WORDS (MEM_WORDS)
    ) dut (
        .aclk(aclk), .aresetn(aresetn),
        .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize),
        .awburst(awburst), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize),
        .arburst(arburst), .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp), .rlast(rlast),
        .rvalid(rvalid), .rready(rready)
    );

    // UNICO punto del arnes que sabe como se llama la instancia y como se
    // llama su memoria por dentro. Todo lo demas mira la memoria por aqui, asi
    // que si el DUT se sustituye por otro esclavo solo cambia esta funcion.
    function automatic [DATA_W-1:0] peek_mem;
        input integer idx;
        begin
            peek_mem = dut.mem[idx];
        end
    endfunction

    localparam [31:0] MEM_BYTES_TB = MEM_WORDS * 8;

    `include "tb_common.vh"
    `include "axi4_master_bfm.vh"
