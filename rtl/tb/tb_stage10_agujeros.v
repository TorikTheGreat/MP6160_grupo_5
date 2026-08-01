`timescale 1ns/1ps
//=============================================================================
// Etapa 10 -- los agujeros que la revisión destapó.
//
// Cada bloque de aquí existe porque una mutación del DUT sobrevivía a las nueve
// etapas anteriores: el banco decía comprobar cosas que no comprobaba. Son, por
// orden de gravedad:
//   (a) `awready`/`arready` pegados altos durante el drenaje de una ráfaga: se
//       aceptaría una segunda dirección y se perdería en silencio. Lo vigila el
//       checker5 de `tb_common.vh` (invariante de TODAS las etapas); lo que
//       aporta esta etapa es el estímulo que lo pone a prueba: una segunda
//       dirección presentada mientras la primera todavía drena.
//   (b) el avance de dirección por ciclo en vez de por handshake: indistinguible
//       mientras todas las ráfagas del banco sean de cero burbujas.
//   (c) `bid`/`rid` sin ecoar: invisible mientras el único ID emitido sea 0.
//   (d) reset en medio de una ráfaga: nunca se probaba.
//   (e) `wstrb` parcial dentro de una ráfaga larga: la etapa 5 sólo usa AWLEN=0.
//=============================================================================
module tb;
    parameter MEM_WORDS = 8192;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    integer i, nb;

    initial begin
        $display("--- Etapa 10: agujeros de cobertura ---");
        bfm_idle;
        do_reset;

        //---------------------------------------------------------------------
        // (a) Dos ráfagas encadenadas: la segunda AW se presenta mientras la
        //     primera todavía drena. Los monitores de arriba vigilan los ready.
        //---------------------------------------------------------------------
        fork
            axi_write_burst(32'h0000_0100, 8'd7, 32'hA1A1_0000, 0, 0);
            begin
                // la segunda AW espera pegada: se presenta a los 2 ciclos
                repeat (2) @(posedge aclk);
                drive_aw(32'h0000_0200, 8'd7, 3'b011, 2'b01, 0);
                drive_w (32'h0000_0200, 8'd7, 32'hB2B2_0000, {NB{1'b1}}, 0, 1'b1);
                wait_b  (2'b00, "bresp de la segunda rafaga encadenada");
            end
        join
        check_all("dos rafagas encadenadas, ninguna direccion perdida");
        axi_read_burst(32'h0000_0100, 8'd7);
        axi_read_burst(32'h0000_0200, 8'd7);

        // lo mismo en lectura: dos AR seguidas
        fork
            axi_read_burst(32'h0000_0100, 8'd3);
            begin
                repeat (2) @(posedge aclk);
                axi_read_burst(32'h0000_0200, 8'd3);
            end
        join

        //---------------------------------------------------------------------
        // (b) Ráfaga con huecos en W. Si el DUT avanzara la dirección por ciclo
        //     en vez de por handshake, los datos saldrían esparcidos.
        //---------------------------------------------------------------------
        axi_write_burst_gap(32'h0000_0400, 8'd7, 32'hC3C3_0000, 3);
        check_all("rafaga con 3 ciclos de hueco entre beats");
        axi_read_burst(32'h0000_0400, 8'd7);

        //---------------------------------------------------------------------
        // (c) ID distinto de cero: comprueba que bid/rid ECOAN, y no que
        //     devuelven la constante 0 (que es lo único que el resto del banco
        //     puede distinguir, porque nunca emite otro ID).
        //---------------------------------------------------------------------
        // wait_b y axi_read_burst_chk comparan contra el ID REALMENTE emitido,
        // asi que basta con cambiarlo aqui: si el DUT dejara de ecoarlo, saltan.
        @(negedge aclk); awid = 4'h5;
        axi_write_burst(32'h0000_0600, 8'd1, 32'hD4D4_0000, 0, 0);
        @(negedge aclk); awid = 4'h0;

        @(negedge aclk); arid = 4'hA;
        axi_read_burst(32'h0000_0600, 8'd1);
        @(negedge aclk); arid = 4'h0;

        //---------------------------------------------------------------------
        // (d) Reset en medio de una ráfaga: el DUT tiene que quedar limpio y la
        //     transacción siguiente tiene que funcionar.
        //---------------------------------------------------------------------
        drive_aw(32'h0000_0800, 8'd15, 3'b011, 2'b01, 0);
        for (nb = 0; nb < 4; nb = nb + 1) begin       // sólo 4 de 16 beats
            @(negedge aclk);
            wdata = 64'hDEAD_0000_0000_0000 + nb; wstrb = {NB{1'b1}};
            wlast = 1'b0; wvalid = 1'b1;
            @(posedge aclk);
            while (!wready) @(posedge aclk);
            // el DUT SI acepto y escribio estos beats antes del reset
            ref_write(32'h0000_0800 + nb*8, 64'hDEAD_0000_0000_0000 + nb, {NB{1'b1}});
        end
        @(negedge aclk); wvalid = 1'b0;
        bfm_idle;
        do_reset;                                      // reset a mitad de rafaga
        @(posedge aclk);
        expect_true(awready === 1'b1, "tras el reset a mitad de rafaga, awready vuelve a 1");
        expect_true(bvalid  === 1'b0, "tras el reset no queda ninguna B pendiente");

        axi_write_burst(32'h0000_0A00, 8'd3, 32'hE5E5_0000, 0, 0);
        axi_read_burst (32'h0000_0A00, 8'd3);

        //---------------------------------------------------------------------
        // (e) wstrb parcial DENTRO de una ráfaga larga (la etapa 5 sólo cubre
        //     AWLEN=0), y relectura por el canal R para no fiarse de la memoria por dentro.
        //---------------------------------------------------------------------
        for (i = 0; i < 8; i = i + 1)
            axi_write_word(32'h0000_0C00 + i*8, {64{1'b1}}, {NB{1'b1}});
        axi_write_burst_strb(32'h0000_0C00, 8'd7, 32'h0000_0000, 8'h3C);
        check_all("wstrb parcial en una rafaga de 8 beats");
        axi_read_burst(32'h0000_0C00, 8'd7);

        check_aw_b_pareados;
        finish_report("etapa 10");
    end
endmodule
