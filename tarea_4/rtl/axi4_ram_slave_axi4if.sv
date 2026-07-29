//=============================================================================
// axi4_ram_slave_axi4if.sv -- wrapper fino: conecta la axi4_if del rol B a los
// puertos planos del nucleo en Verilog.
//
// Por que existe: el entregable pide el modulo "en Verilog", y la interfaz de
// SystemVerilog todavia no existia cuando se escribio el nucleo. Manteniendo el
// nucleo con puertos planos, si B renombra una senal solo cambia ESTE fichero
// (~40 lineas): ni el nucleo ni las doce pruebas se tocan.
//
// La tabla de conexion puerto<->senal esta en README.md, para que B o D
// puedan rehacer este wrapper sin leer el codigo.
//=============================================================================
module axi4_ram_slave_axi4if #(
    parameter DATA_W    = 64,
    parameter ADDR_W    = 32,
    parameter ID_W      = 4,
    parameter MEM_WORDS = 8388608
) (
    axi4_if.slave axi
);

    // Los parametros del wrapper y los de la interfaz son independientes: sin
    // esta guarda, conectar una axi4_if de 32 bits a un wrapper de 64 compila
    // limpio y trunca los datos en silencio (y el -Wno-WIDTHEXPAND de la
    // receta de stage9 apagaria hasta el aviso).
    initial begin
        if ($bits(axi.wdata) != DATA_W) begin
            $display("ERROR: axi.wdata tiene %0d bits y DATA_W es %0d",
                     $bits(axi.wdata), DATA_W);
            $fatal(1);
        end
        if ($bits(axi.awaddr) != ADDR_W) begin
            $display("ERROR: axi.awaddr tiene %0d bits y ADDR_W es %0d",
                     $bits(axi.awaddr), ADDR_W);
            $fatal(1);
        end
    end

    axi4_ram_slave #(
        .DATA_W    (DATA_W),
        .ADDR_W    (ADDR_W),
        .ID_W      (ID_W),
        .MEM_WORDS (MEM_WORDS)
    ) core (
        .aclk    (axi.aclk),    .aresetn (axi.aresetn),

        .awid    (axi.awid),    .awaddr  (axi.awaddr),  .awlen   (axi.awlen),
        .awsize  (axi.awsize),  .awburst (axi.awburst), .awvalid (axi.awvalid),
        .awready (axi.awready),

        .wdata   (axi.wdata),   .wstrb   (axi.wstrb),   .wlast   (axi.wlast),
        .wvalid  (axi.wvalid),  .wready  (axi.wready),

        .bid     (axi.bid),     .bresp   (axi.bresp),   .bvalid  (axi.bvalid),
        .bready  (axi.bready),

        .arid    (axi.arid),    .araddr  (axi.araddr),  .arlen   (axi.arlen),
        .arsize  (axi.arsize),  .arburst (axi.arburst), .arvalid (axi.arvalid),
        .arready (axi.arready),

        .rid     (axi.rid),     .rdata   (axi.rdata),   .rresp   (axi.rresp),
        .rlast   (axi.rlast),   .rvalid  (axi.rvalid),  .rready  (axi.rready)
    );

endmodule
