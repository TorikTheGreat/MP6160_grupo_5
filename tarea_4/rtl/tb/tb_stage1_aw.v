`timescale 1ns/1ps
//=============================================================================
// Etapa 1 -- handshake de un solo canal (AW).
// La transferencia ocurre en el flanco donde awvalid && awready son AMBOS
// altos. Se prueba en los dos ordenes de llegada y con dos AW seguidas.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    // Solo AW: el resto de la rafaga se completa para no dejar el DUT colgado.
    task solo_aw;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input integer      delay;
        begin
            drive_aw(addr, alen, 3'b011, 2'b01, delay);
            expect_eq({{(64-ADDR_W){1'b0}}, dut.aw_addr_q}, {{(64-ADDR_W){1'b0}}, addr},
                      "aw_addr_q capturado en la handshake");
            expect_eq({56'd0, dut.aw_len_q}, {56'd0, alen},
                      "aw_len_q capturado en la handshake");
            // cerrar la rafaga para volver a W_IDLE
            drive_w(addr, alen, 32'hAA, {NB{1'b1}}, 0, 1'b1);
            wait_b(2'b00, "bresp");
        end
    endtask

    initial begin
        $display("--- Etapa 1: handshake del canal AW ---");
        bfm_idle;
        do_reset;

        // (a) el master pone valid y el esclavo ya tiene ready alto
        solo_aw(32'h0000_0040, 8'd0, 0);

        // (b) el master tarda: ready lleva 5 ciclos esperando
        solo_aw(32'h0000_0080, 8'd3, 5);

        // (c) dos AW consecutivas, sin ciclos muertos
        solo_aw(32'h0000_0100, 8'd1, 0);
        solo_aw(32'h0000_0108, 8'd1, 0);

        check_aw_b_pareados;
        finish_report("etapa 1");
    end
endmodule
