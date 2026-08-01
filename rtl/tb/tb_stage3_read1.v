`timescale 1ns/1ps
//=============================================================================
// Etapa 3 -- lectura de un beat. Aqui el esclavo es la FUENTE, asi que las
// reglas de estabilidad le aplican a el: rvalid no puede depender de rready y
// rdata debe quedar quieto mientras rvalid && !rready.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    reg [DATA_W-1:0] m0, m1, m2;
    integer j;

    initial begin
        $display("--- Etapa 3: lectura de un beat ---");
        bfm_idle;
        do_reset;

        // (a) ida y vuelta por la puerta principal
        axi_write_burst(32'h0000_0200, 8'd0, 32'hFEED_0001, 0, 0);
        axi_read_burst (32'h0000_0200, 8'd0);

        // (b) direccion nunca escrita: debe leerse cero, no X.
        //     Lo exige el contrato porque el testbench UVM del rol C lee
        //     memoria que nunca escribio.
        axi_read_burst_chk(32'h0000_0400, 8'd0, 1'b0, {DATA_W{1'b0}}, 2'b00);

        // (c) estabilidad: se suelta rready tres ciclos y rdata no puede moverse
        axi_write_burst(32'h0000_0500, 8'd3, 32'h5555_0000, 0, 0);
        @(negedge aclk);
        rready  = 1'b0;
        drive_ar(32'h0000_0500, 8'd3, 3'b011, 2'b01, 0);

        @(posedge aclk);
        while (!rvalid) @(posedge aclk);
        m0 = rdata;
        @(posedge aclk); m1 = rdata;
        @(posedge aclk); m2 = rdata;
        expect_eq(m1, m0, "rdata estable con rready bajo (ciclo 2)");
        expect_eq(m2, m0, "rdata estable con rready bajo (ciclo 3)");
        expect_eq(m0, ref_mem[32'h0000_0500 >> 3], "rdata es el beat 0 correcto");

        // ...y al soltar rready, el SIGUIENTE beat debe ser A+8, no otro:
        // un DUT que avanza su contador con rready bajo pasaria la prueba de
        // estabilidad y aqui se le ve el beat perdido.
        @(negedge aclk);
        rready = 1'b1;
        @(posedge aclk);                      // se consume el beat 0
        for (j = 1; j <= 3; j = j + 1) begin
            @(posedge aclk);
            while (!(rvalid && rready)) @(posedge aclk);
            expect_eq(rdata, ref_mem[(32'h0000_0500 + j*8) >> 3],
                      "beat correcto tras soltar rready");
            expect_true(rlast === ((j == 3) ? 1'b1 : 1'b0), "rlast en el beat 3");
        end

        check_aw_b_pareados;
        finish_report("etapa 3");
    end
endmodule
