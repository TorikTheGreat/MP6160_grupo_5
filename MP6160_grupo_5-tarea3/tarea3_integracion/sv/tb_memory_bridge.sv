`timescale 1ns/1ps

module tb_memory_bridge;

    import "DPI-C" function void dpi_write(
        input int unsigned addr,
        input int unsigned data
    );

    import "DPI-C" function int unsigned dpi_read(
        input int unsigned addr
    );

    int unsigned dato_leido;

    initial begin
        $display("");
        $display("======================================");
        $display(" PRUEBA DEL PUENTE DE MEMORIA DPI-C");
        $display("======================================");

        dpi_write(32'h00001000, 32'h12345678);

        dato_leido = dpi_read(32'h00001000);

        if (dato_leido == 32'h12345678) begin
            $display("[SV] MEMORY_BRIDGE_PASS");
        end
        else begin
            $display(
                "[SV] MEMORY_BRIDGE_FAIL: esperado=0x12345678 recibido=0x%08h",
                dato_leido
            );
        end

        $finish;
    end

endmodule