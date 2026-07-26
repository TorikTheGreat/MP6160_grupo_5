`timescale 1ns/1ps

module tb_systemc_dpi_step_launcher;

    import "DPI-C" function int systemc_create();
    import "DPI-C" function int systemc_service();
    import "DPI-C" function int systemc_is_finished();
    import "DPI-C" function int systemc_passed();
    import "DPI-C" function void systemc_destroy();

    logic aclk;
    logic aresetn;
    int status;

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
        $display("======================================");
        $display(" RESET AXI FINALIZADO");
        $display("======================================");
    end

    initial begin
        wait (aresetn == 1'b1);
        repeat (2) @(posedge aclk);

        $display("");
        $display("======================================");
        $display(" INICIANDO CARGA DE IMAGEN POR DPI + AXI");
        $display("======================================");

        status = systemc_create();
        if (status != 0)
            $fatal(1, "[SV] No fue posible crear el controlador C++.");

        while (systemc_is_finished() == 0) begin
            @(posedge aclk);
            status = systemc_service();
            if (status != 0) begin
                systemc_destroy();
                $fatal(1, "[SV] Fallo systemc_service().");
            end
        end

        if (systemc_passed() == 0) begin
            systemc_destroy();
            $fatal(1, "[SV] La prueba cooperativa fallo.");
        end

        systemc_destroy();
        $display("");
        $display("======================================");
        $display(" CARGA DE IMAGEN FINALIZADA CORRECTAMENTE");
        $display("======================================");
        $finish;
    end

    initial begin
        #5000000000;
        $fatal(1, "[SV] TIMEOUT: la carga de imagen no termino.");
    end

endmodule
