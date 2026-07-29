`timescale 1ns/1ps
//=============================================================================
// Etapa 2 -- escritura de un beat, por carriles, y respuesta B.
// AW y W son canales INDEPENDIENTES: se barren las 9 combinaciones de retardo
// {0,1,5}x{0,1,5}, incluido el caso en que W llega 5 ciclos ANTES que AW, que
// es el que cuelga a las FSM que exigen ver la direccion primero.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    integer ia, iw;
    integer dly [0:2];
    reg [ADDR_W-1:0] a;

    initial begin
        $display("--- Etapa 2: escritura de un beat + respuesta B ---");
        dly[0] = 0; dly[1] = 1; dly[2] = 5;
        bfm_idle;
        do_reset;

        for (ia = 0; ia < 3; ia = ia + 1)
          for (iw = 0; iw < 3; iw = iw + 1) begin
            a = 32'h0000_0100 + (ia*3 + iw)*8;
            axi_write_burst(a, 8'd0, 32'hC0DE_0000 + ia*16 + iw, dly[ia], dly[iw]);
            // comprobacion por la puerta trasera: el dato llego a la memoria
            expect_eq(peek_mem(a >> 3), beat_data(32'hC0DE_0000 + ia*16 + iw, 0),
                      "el beat quedo escrito en mem");
          end

        check_all("etapa 2");
        check_aw_b_pareados;
        finish_report("etapa 2");
    end
endmodule
