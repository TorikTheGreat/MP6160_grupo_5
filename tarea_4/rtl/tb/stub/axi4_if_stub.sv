//=============================================================================
// ARCHIVO PROVISIONAL -- NO ES ENTREGABLE.
// Sustituto temporal de la axi4_if del rol B, para poder compilar y probar el
// wrapper antes de que B publique la suya. SE BORRA en cuanto exista la real.
// NADIE MAS DEBE INSTANCIARLO: si dos personas escriben su propia axi4_if,
// acabamos con dos interfaces divergentes.
//
// Las senales y los anchos son los del contrato (seccion "Propuesta de las
// decisiones de diseno" del plan de trabajo), incluidas awprot/awcache/awlock/
// awqos, que existen en la interfaz aunque el nucleo no las declare ni las use.
//=============================================================================
interface axi4_if #(
    parameter DATA_W = 64,
    parameter ADDR_W = 32,
    parameter ID_W   = 4
) (
    input wire aclk,
    input wire aresetn
);
    logic [ID_W-1:0]       awid;
    logic [ADDR_W-1:0]     awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic [2:0]             awprot;
    logic [3:0]             awcache;
    logic                   awlock;
    logic [3:0]             awqos;
    logic  awvalid;
    logic  awready;

    logic [DATA_W-1:0]     wdata;
    logic [(DATA_W/8)-1:0] wstrb;
    logic  wlast;
    logic  wvalid;
    logic  wready;

    logic [ID_W-1:0]       bid;
    logic [1:0]            bresp;
    logic  bvalid;
    logic  bready;

    logic [ID_W-1:0]       arid;
    logic [ADDR_W-1:0]     araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic [2:0]             arprot;
    logic [3:0]             arcache;
    logic                   arlock;
    logic [3:0]             arqos;
    logic  arvalid;
    logic  arready;

    logic [ID_W-1:0]       rid;
    logic [DATA_W-1:0]     rdata;
    logic [1:0]            rresp;
    logic  rlast;
    logic  rvalid;
    logic  rready;

    modport slave (
        input  aclk, aresetn,
        input  awid, awaddr, awlen, awsize, awburst, awvalid,
        input  awprot, awcache, awlock, awqos, output awready,
        input  wdata, wstrb, wlast, wvalid, output wready,
        output bid, bresp, bvalid, input bready,
        input  arid, araddr, arlen, arsize, arburst, arvalid,
        input  arprot, arcache, arlock, arqos, output arready,
        output rid, rdata, rresp, rlast, rvalid, input rready
    );
endinterface
