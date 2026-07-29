`timescale 1ns/1ps
//=============================================================================
// Etapa 0 -- humo: compila, el reloj corre, el reset deja las salidas en su
// valor de reposo, la memoria arranca en cero y el volcado de ondas sirve.
//
// Ejercicio de esta etapa:  make hang   ->  make wave-hang
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    integer t0;

`ifndef HANG_DEMO
    initial begin
        $display("--- Etapa 0: humo, reset y volcado ---");
        bfm_idle;
        do_reset;

        @(posedge aclk);
        expect_true(bvalid  === 1'b0, "bvalid en reposo debe ser 0");
        expect_true(rvalid  === 1'b0, "rvalid en reposo debe ser 0");
        expect_true(awready === 1'b1, "awready en reposo debe ser 1");
        expect_true(arready === 1'b1, "arready en reposo debe ser 1");

        t0 = cycle_count;
        repeat (10) @(posedge aclk);
        expect_eq(cycle_count - t0, 10, "el reloj avanza 10 ciclos");

        expect_eq(peek_mem(0),  64'h0, "mem[0] inicializada a cero");
        expect_eq(peek_mem(17), 64'h0, "mem[17] inicializada a cero");

        finish_report("etapa 0");
    end
`else
    // Cuelgue deliberado: esperamos un wready que nunca va a subir.
    initial begin
        bfm_idle;
        do_reset;
        $display("HANG_DEMO: esperando wready, que nunca va a subir...");
        @(negedge aclk);
        wvalid = 1'b1;
        wait (wready === 1'b1);
        $display("esto no deberia imprimirse");
    end
`endif
endmodule
