`timescale 1ns/1ps

module tb_systemc_launcher;

    import "DPI-C" function int run_accelerator_adapter();

    int resultado;

    initial begin
        $display("");
        $display("========================================");
        $display(" LANZADOR DEL ACELERADOR SYSTEMC");
        $display("========================================");

        resultado = run_accelerator_adapter();

        if (resultado == 0) begin
            $display("[SV] SYSTEMC_LAUNCH_PASS");
        end
        else begin
            $display(
                "[SV] SYSTEMC_LAUNCH_FAIL: codigo=%0d",
                resultado
            );
        end

        $finish;
    end

endmodule