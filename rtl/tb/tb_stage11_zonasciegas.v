`timescale 1ns/1ps
//=============================================================================
// Etapa 11 -- zonas ciegas que destapó una segunda ronda de mutación.
//
// Cada bloque cubre una mutación del DUT que sobrevivía a las once etapas
// anteriores. No son casos rebuscados: son las cinco cosas que el banco nunca
// llegaba a pedirle al esclavo.
//
//   (a) el borde EXACTO de la memoria. La etapa 6 prueba la última dirección
//       válida y una muy fuera, nunca `MEM_BYTES` justo. Un `<=` en vez de `<`
//       en la comparación de rango pasaba inadvertido.
//   (b) LECTURAS no soportadas (WRAP, ARSIZE≠8B). El banco solo probaba
//       escrituras no soportadas: la ruta de lectura no se ejercitaba nunca.
//   (c) el DATO de un beat con SLVERR. `axi_read_burst_chk` se salta la
//       comprobación de `rdata` cuando la respuesta esperada no es OKAY, así
//       que un esclavo que filtrara memoria en los beats con error pasaba.
//   (d) WLAST prematuro. El checker3 vigila el ESTÍMULO, así que el propio BFM
//       nunca lo genera; hay que emitirlo a mano.
//   (e) escritura que envuelve los 32 bits, y reset con una B pendiente.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;             // MEM_BYTES = 0x2000
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    localparam [ADDR_W-1:0] LIMITE = MEM_WORDS * 8;   // primera dirección fuera

    integer n;
    reg [DATA_W-1:0] antes0, antes1;

    initial begin
        $display("--- Etapa 11: zonas ciegas ---");
        bfm_idle;
        do_reset;

        //---------------------------------------------------------------------
        // (a) El borde exacto. LIMITE-8 es la última palabra válida; LIMITE es
        //     la primera inválida. Un off-by-one en la comparación de rango
        //     haría que LIMITE aliasara sobre mem[0] y respondiera OKAY.
        //---------------------------------------------------------------------
        axi_write_burst(LIMITE - 8, 8'd0, 32'h11AA_0000, 0, 0);
        axi_read_burst (LIMITE - 8, 8'd0);

        antes0 = peek_mem(0);
        axi_write_burst_err(LIMITE, 8'd0, 32'h11BB_0000, 3'b011, 2'b01, 2'b10);
        expect_eq(peek_mem(0), antes0,
                  "escribir justo en MEM_BYTES no debe aliasar sobre mem[0]");
        axi_read_burst_chk(LIMITE, 8'd0, 1'b0, {DATA_W{1'b0}}, 2'b10);

        //---------------------------------------------------------------------
        // (b) y (c) Lecturas no soportadas, comprobando ADEMÁS el dato: un beat
        //     con SLVERR no debe filtrar el contenido real de la memoria.
        //---------------------------------------------------------------------
        axi_write_burst(32'h0000_0080, 8'd3, 32'h11CC_0000, 0, 0);

        // ARBURST = WRAP, dirección perfectamente válida
        @(negedge aclk);
        araddr = 32'h0000_0080; arlen = 8'd3; arsize = 3'b011;
        arburst = 2'b10; arvalid = 1'b1;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        @(negedge aclk); arvalid = 1'b0;
        for (n = 0; n <= 3; n = n + 1) begin
            @(posedge aclk);
            while (!(rvalid && rready)) @(posedge aclk);
            expect_resp(rresp, 2'b10, "WRAP en lectura debe dar SLVERR");
            expect_eq(rdata, {DATA_W{1'b0}},
                      "un beat con SLVERR no debe filtrar memoria");
            expect_true(rlast === ((n == 3) ? 1'b1 : 1'b0), "rlast del beat");
        end
        @(negedge aclk); arburst = 2'b01;

        // ARSIZE distinto de 8 B (narrow transfer, fuera de alcance)
        @(negedge aclk);
        araddr = 32'h0000_0080; arlen = 8'd1; arsize = 3'b010;
        arburst = 2'b01; arvalid = 1'b1;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        @(negedge aclk); arvalid = 1'b0;
        for (n = 0; n <= 1; n = n + 1) begin
            @(posedge aclk);
            while (!(rvalid && rready)) @(posedge aclk);
            expect_resp(rresp, 2'b10, "ARSIZE != 8B debe dar SLVERR");
            expect_eq(rdata, {DATA_W{1'b0}}, "ni filtrar memoria");
        end
        @(negedge aclk); arsize = 3'b011;

        // y el dato de una lectura FUERA DE RANGO tampoco
        axi_read_burst_chk(32'h0001_0000, 8'd1, 1'b0, {DATA_W{1'b0}}, 2'b10);

        //---------------------------------------------------------------------
        // (d) WLAST prematuro: se promete AWLEN=3 y se cierra en el beat 1.
        //     El esclavo debe responder SLVERR (no OKAY) y no colgarse.
        //---------------------------------------------------------------------
        estimulo_ilegal = 1'b1;   // el checker3 vigila el estimulo: aqui miente a proposito
        drive_aw(32'h0000_0300, 8'd3, 3'b011, 2'b01, 0);
        for (n = 0; n <= 1; n = n + 1) begin
            @(negedge aclk);
            wdata = 64'h1111_2222_3333_0000 + n;
            wstrb = {NB{1'b1}};
            wlast = (n == 1);                 // WLAST en el beat 1, no en el 3
            wvalid = 1'b1;
            @(posedge aclk);
            while (!wready) @(posedge aclk);
        end
        @(negedge aclk); wvalid = 1'b0; wlast = 1'b0;
        @(posedge aclk);
        while (!(bvalid && bready)) @(posedge aclk);
        expect_resp(bresp, 2'b10, "WLAST prematuro debe dar SLVERR");
        estimulo_ilegal = 1'b0;

        // y el esclavo tiene que seguir vivo
        axi_write_burst(32'h0000_0400, 8'd1, 32'h11DD_0000, 0, 0);
        axi_read_burst (32'h0000_0400, 8'd1);

        //---------------------------------------------------------------------
        // (e1) Escritura que envuelve los 32 bits: los beats que "vuelven" a
        //      caer dentro del mapa NO deben escribirse.
        //---------------------------------------------------------------------
        antes0 = peek_mem(0);
        antes1 = peek_mem(1);
        axi_write_burst_err(32'hFFFF_FFF8, 8'd3, 32'h11EE_0000, 3'b011, 2'b01, 2'b10);
        expect_eq(peek_mem(0), antes0, "el wrap de 32 bits no debe escribir mem[0]");
        expect_eq(peek_mem(1), antes1, "ni mem[1]");

        //---------------------------------------------------------------------
        // (e2) Reset con una B pendiente: bvalid tiene que caer. Es el
        //      requisito de la spec que el propio módulo cita, y nada lo
        //      comprobaba con una respuesta realmente en vuelo.
        //---------------------------------------------------------------------
        @(negedge aclk); bready = 1'b0;        // el master no acepta la B
        drive_aw(32'h0000_0500, 8'd0, 3'b011, 2'b01, 0);
        @(negedge aclk);
        wdata = 64'hFACE_FACE_FACE_FACE; wstrb = {NB{1'b1}};
        wlast = 1'b1; wvalid = 1'b1;
        @(posedge aclk);
        while (!wready) @(posedge aclk);
        @(negedge aclk); wvalid = 1'b0; wlast = 1'b0;
        @(posedge aclk);
        while (!bvalid) @(posedge aclk);       // B en vuelo, sin aceptar
        expect_true(bvalid === 1'b1, "hay una B pendiente antes del reset");

        @(negedge aclk); aresetn = 1'b0;
        @(posedge aclk);
        @(posedge aclk);
        expect_true(bvalid === 1'b0, "el reset debe bajar bvalid aunque haya B pendiente");
        expect_true(rvalid === 1'b0, "y rvalid");
        bfm_idle;
        do_reset;

        axi_write_burst(32'h0000_0600, 8'd0, 32'h11FF_0000, 0, 0);
        axi_read_burst (32'h0000_0600, 8'd0);

        check_aw_b_pareados;
        finish_report("etapa 11");
    end
endmodule
