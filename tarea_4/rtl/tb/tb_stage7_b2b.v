`timescale 1ns/1ps
//=============================================================================
// Etapa 7 -- espalda con espalda, independencia lectura/escritura y burbujas.
//   Con capacidad de 1 pendiente, awready DEBE bajar mientras se drena una
//   rafaga: si se quedara alto, una segunda AW se aceptaria y se perderia en
//   silencio, y los datos de la segunda rafaga acabarian en la direccion de la
//   primera. (Eso es consecuencia de ESTA implementacion, no una ley de AXI.)
//
//   La prueba de "sin burbujas" se enuncia sin ambiguedad:
//     ciclo(ultima handshake W) - ciclo(primera) == AWLEN
//   Para AWLEN=15 son 15 ciclos, no 16: hay 16 beats, y entre el primero y el
//   ultimo transcurren 15 ciclos si no hay ningun hueco.
//=============================================================================
module tb;
    parameter MEM_WORDS = 8192;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    // Medidor de burbujas
    integer w_first_cyc, w_last_cyc, w_hs_n;
    reg     medir;
    always @(posedge aclk) if (aresetn && medir && wvalid && wready) begin
        if (w_hs_n == 0) w_first_cyc <= cycle_count;
        w_last_cyc <= cycle_count;
        w_hs_n     <= w_hs_n + 1;
    end

    // Contrapresion pseudoaleatoria (sustituto de randomize())
    reg bp;
    always @(posedge aclk) if (aresetn && bp) begin
        lfsr_next;
        bready <= lfsr[0];
        rready <= lfsr[3];
    end

    integer i7;

    initial begin
        $display("--- Etapa 7: espalda con espalda ---");
        bfm_idle;
        medir = 1'b0; bp = 1'b0;
        w_first_cyc = 0; w_last_cyc = 0; w_hs_n = 0;
        do_reset;

        // (a) tres rafagas consecutivas sin ciclos muertos entre ellas
        axi_write_burst(32'h0000_0800, 8'd3, 32'h7000_0001, 0, 0);
        axi_write_burst(32'h0000_0820, 8'd3, 32'h7000_0002, 0, 0);
        axi_write_burst(32'h0000_0840, 8'd3, 32'h7000_0003, 0, 0);
        check_all("tres rafagas consecutivas");
        axi_read_burst(32'h0000_0800, 8'd3);
        axi_read_burst(32'h0000_0820, 8'd3);
        axi_read_burst(32'h0000_0840, 8'd3);

        // (b) sin burbujas dentro de una rafaga de 16 beats
        w_hs_n = 0; medir = 1'b1;
        axi_write_burst(32'h0000_0900, 8'd15, 32'h7777_0000, 0, 0);
        medir = 1'b0;
        expect_eq(w_hs_n, 16, "16 handshakes de W en una rafaga de AWLEN=15");
        expect_eq(w_last_cyc - w_first_cyc, 15,
                  "sin burbujas: ultimo - primero == AWLEN");

        // (c) lectura y escritura en vuelo a la vez: las dos rutas son
        //     independientes y ninguna bloquea a la otra
        fork
            axi_write_burst(32'h0000_0A00, 8'd7, 32'h8888_0000, 0, 0);
            axi_read_burst (32'h0000_0900, 8'd15);
        join
        check_all("escritura en paralelo con lectura");
        axi_read_burst(32'h0000_0A00, 8'd7);

        // (d) contrapresion pseudoaleatoria sobre bready y rready
        bp = 1'b1;
        for (i7 = 0; i7 < 20; i7 = i7 + 1) begin
            axi_write_burst(32'h0000_0C00 + i7*64, 8'd7, 32'h9000_0000 + i7, 0, 0);
            axi_read_burst (32'h0000_0C00 + i7*64, 8'd7);
        end
        bp = 1'b0;
        @(negedge aclk); bready = 1'b1; rready = 1'b1;
        check_all("tras 20 rafagas con contrapresion");

        check_aw_b_pareados;
        finish_report("etapa 7");
    end
endmodule
