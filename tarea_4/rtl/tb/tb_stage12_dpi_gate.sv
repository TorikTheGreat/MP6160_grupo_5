`timescale 1ns/1ps
//=============================================================================
// Etapa 12 (rol D) -- primera puerta DPI.
// Demuestra ida y vuelta SV <-> C++ y consumo de tiempo de simulacion.
// El avance de reloj lo hace un proceso local del testbench alrededor de la
// llamada DPI; asi Verilator no necesita timing dentro de un export.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    // Contexto obligatorio: esta funcion en C++ hace callback a SV.
    import "DPI-C" context function int dpi_roundtrip(input int token, input int wait_cycles);

    // Exportamos una function para que C++ pueda leer un dato observado del
    // lado SV durante el roundtrip.
    export "DPI-C" function dpi_get_cycle_count;

    task automatic wait_cycles(input int ncycles);
        integer i;
        begin
            for (i = 0; i < ncycles; i = i + 1)
                @(posedge aclk);
        end
    endtask

    function int dpi_get_cycle_count;
        begin
            dpi_get_cycle_count = cycle_count;
        end
    endfunction

    integer c0;
    integer c1;
    integer r0;
    integer r1;

    initial begin
        $display("--- Etapa 12: puerta DPI SV<->C++ con tiempo de simulacion ---");
        bfm_idle;
        do_reset;

        // Primer round-trip: se avanza 7 ciclos alrededor de la llamada DPI.
        c0 = cycle_count;
        wait_cycles(7);
        r0 = dpi_roundtrip(16'h1234, 7);
        c1 = cycle_count;

        expect_eq(c1 - c0, 7, "dpi_roundtrip debe consumir exactamente 7 ciclos");
        expect_eq(r0, c1 + 16'h1234, "retorno C++ usa valor observado desde SV");

        // Segundo round-trip para descartar falso positivo de una sola llamada.
        c0 = cycle_count;
        wait_cycles(3);
        r1 = dpi_roundtrip(16'h0101, 3);
        c1 = cycle_count;

        expect_eq(c1 - c0, 3, "segunda llamada DPI consume 3 ciclos");
        expect_eq(r1, c1 + 16'h0101, "segunda llamada retorna valor consistente");

        finish_report("etapa 12 / puerta DPI");
    end
endmodule
