`timescale 1ns/1ps
//=============================================================================
// Etapa 4 -- rafagas INCR. La etapa dura.
//   AWLEN codifica beats-1;  awsize=3 => +8 bytes por beat;  wlast y rlast en
//   el beat AWLEN;  una sola B por rafaga.
// Se verifica por LOS DOS CAMINOS:
//   (a) check_all(): ref_mem contra la memoria (peek_mem)  -> caza off-by-one de ESCRITURA
//   (b) axi_read_burst(): relectura por el canal R, beat a beat, con rlast,
//       rid y conteo -> caza los de LECTURA, que (a) no puede ver.
// AWLEN=255 es obligatorio: es el borde del contador de 8 bits.
//=============================================================================
module tb;
    parameter MEM_WORDS = 8192;             // 64 KB: cabe una rafaga de 2 KB
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    integer li;
    reg [7:0] lens [0:6];
    reg [ADDR_W-1:0] base;

    initial begin
        $display("--- Etapa 4: rafagas INCR ---");
        lens[0]=8'd0; lens[1]=8'd1; lens[2]=8'd2; lens[3]=8'd3;
        lens[4]=8'd7; lens[5]=8'd15; lens[6]=8'd255;
        bfm_idle;
        do_reset;

        base = 32'h0000_1000;
        for (li = 0; li < 7; li = li + 1) begin
            $display("  AWLEN=%0d  (%0d beats)  base=0x%h", lens[li], lens[li]+1, base);
            axi_write_burst(base, lens[li], 32'h1000_0000 + li, 0, 0);
            check_all("tras la rafaga de escritura");
            axi_read_burst(base, lens[li]);       // relectura por el canal R
            base = base + (lens[li] + 1) * 8;
        end

        check_aw_b_pareados;
        finish_report("etapa 4");
    end
endmodule
