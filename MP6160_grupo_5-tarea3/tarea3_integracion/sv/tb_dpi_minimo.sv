`timescale 1ns/1ps

module tb_dpi_minimo;

    import "DPI-C" function int dpi_sumar(
        input int a,
        input int b
    );

    int resultado;

    initial begin
        $display("");
        $display("====================================");
        $display("   PRUEBA MINIMA DPI-C");
        $display("====================================");

        resultado = dpi_sumar(20, 22);

        if (resultado == 42) begin
            $display("[SV] DPI_PASS: resultado = %0d", resultado);
        end
        else begin
            $display("[SV] DPI_FAIL: esperado = 42, recibido = %0d",
                     resultado);
        end

        $finish;
    end

endmodule