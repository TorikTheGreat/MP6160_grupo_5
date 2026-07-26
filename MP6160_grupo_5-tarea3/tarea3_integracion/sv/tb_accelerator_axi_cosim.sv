`timescale 1ns/1ps

module tb_accelerator_axi_cosim;

    logic aclk;
    logic aresetn;

    /*
     * Servidor RTL:
     * maestro AXI + RAM AXI4.
     */
    axi_dpi_server dut (
        .aclk(aclk),
        .aresetn(aresetn)
    );

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    initial begin
        aresetn = 1'b0;

        repeat (5) @(posedge aclk);

        aresetn = 1'b1;

        $display("");
        $display("========================================");
        $display(" COSIMULACION SYSTEMC + DPI + AXI");
        $display("========================================");
    end

    /*
     * Protección contra bloqueo.
     */
    initial begin
        #1000000;

        $fatal(
            1,
            "[SV] TIMEOUT: la cosimulacion no termino"
        );
    end

endmodule