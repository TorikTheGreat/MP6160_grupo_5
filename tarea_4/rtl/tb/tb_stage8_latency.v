`timescale 1ns/1ps
//=============================================================================
// Etapa 8 -- latencia y throughput.
//
// El contrato pide "<= 6 ciclos por transaccion sin rafaga" pero no dice desde
// donde. DEFINICION que adopta el rol E y que va al README:
//   latencia de escritura = ciclos desde el primer flanco en que el esclavo ve
//     awvalid (con AWLEN=0 y wvalid en el mismo ciclo) hasta el flanco de
//     bvalid && bready, sin contrapresion.
//   latencia de lectura   = idem desde arvalid hasta rvalid && rready && rlast.
//
// Con una FSM determinista y sin contrapresion esto da UN SOLO numero: una
// tabla min/tipico/max tendria las tres columnas iguales y no diria nada.
//
// Por eso se mide ademas lo que de verdad necesitan los roles A y D: el
// THROUGHPUT SOSTENIDO en ciclos/beat con AWLEN=255 espalda con espalda, que
// es el perfil de trafico real del sistema (la imagen de 1080p se mueve en
// rafagas largas encadenadas, no en transacciones sueltas).
//=============================================================================
module tb;
    parameter MEM_WORDS = 8192;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    integer t0, t1, lat_w, lat_r;
    integer c_ini, c_fin, beats_tot, i8;

    initial begin
        $display("--- Etapa 8: latencia y throughput ---");
        bfm_idle;
        do_reset;

        //---------------------------------------------------------------------
        // Latencia de escritura, AWLEN=0, sin contrapresion
        //---------------------------------------------------------------------
        @(negedge aclk);
        awaddr = 32'h0000_0300; awlen = 8'd0; awsize = 3'b011;
        awburst = 2'b01; awid = 0; awvalid = 1'b1;
        wdata = 64'hA5A5_A5A5_5A5A_5A5A; wstrb = 8'hFF; wlast = 1'b1; wvalid = 1'b1;
        @(posedge aclk);
        t0 = cycle_count;
        while (!(awvalid && awready)) @(posedge aclk);
        @(negedge aclk); awvalid = 1'b0;
        @(posedge aclk);
        while (!(wvalid && wready)) @(posedge aclk);
        @(negedge aclk); wvalid = 1'b0; wlast = 1'b0;
        @(posedge aclk);
        while (!(bvalid && bready)) @(posedge aclk);
        t1 = cycle_count;
        lat_w = t1 - t0;

        //---------------------------------------------------------------------
        // Latencia de lectura, ARLEN=0, sin contrapresion
        //---------------------------------------------------------------------
        @(negedge aclk);
        araddr = 32'h0000_0300; arlen = 8'd0; arsize = 3'b011;
        arburst = 2'b01; arid = 0; arvalid = 1'b1;
        @(posedge aclk);
        t0 = cycle_count;
        while (!(arvalid && arready)) @(posedge aclk);
        @(negedge aclk); arvalid = 1'b0;
        @(posedge aclk);
        while (!(rvalid && rready && rlast)) @(posedge aclk);
        t1 = cycle_count;
        lat_r = t1 - t0;

        //---------------------------------------------------------------------
        // Throughput sostenido: 4 rafagas de 256 beats encadenadas
        //---------------------------------------------------------------------
        beats_tot = 0;
        @(posedge aclk);
        c_ini = cycle_count;
        for (i8 = 0; i8 < 4; i8 = i8 + 1) begin
            axi_write_burst(32'h0000_1000 + i8*2048, 8'd255, 32'hE000_0000 + i8, 0, 0);
            beats_tot = beats_tot + 256;
        end
        @(posedge aclk);
        c_fin = cycle_count;

        $display("");
        $display("  latencia de escritura (AWLEN=0) : %0d ciclos", lat_w);
        $display("  latencia de lectura   (ARLEN=0) : %0d ciclos", lat_r);
        $display("  throughput sostenido            : %0d ciclos / %0d beats = %0d.%02d ciclos/beat",
                 c_fin - c_ini, beats_tot,
                 (c_fin - c_ini) / beats_tot,
                 (((c_fin - c_ini) * 100) / beats_tot) % 100);
        $display("");

        expect_true(lat_w <= 6, "latencia de escritura <= 6 ciclos");
        expect_true(lat_r <= 6, "latencia de lectura <= 6 ciclos");
        check_all("etapa 8");
        check_aw_b_pareados;
        finish_report("etapa 8");
    end
endmodule
