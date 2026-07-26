`timescale 1ns/1ps

module tb_axi_dpi_launcher;

    logic aclk;
    logic aresetn;

    /*
     * Es una tarea y no una función porque las operaciones AXI
     * esperan flancos del reloj dentro de SystemVerilog.
     */
    import "DPI-C" context task run_axi_dpi_test(
        output int resultado
    );

    int resultado;

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
    end

    initial begin
        wait(aresetn == 1'b1);

        repeat (2) @(posedge aclk);

        $display("");
        $display("======================================");
        $display(" PRUEBA C++ -> DPI -> AXI -> RAM");
        $display("======================================");

        run_axi_dpi_test(resultado);

        if (resultado == 0) begin
            $display("[SV] AXI_DPI_TEST_PASS");
        end
        else begin
            $display(
                "[SV] AXI_DPI_TEST_FAIL: codigo=%0d",
                resultado
            );
        end

        $finish;
    end

endmodule