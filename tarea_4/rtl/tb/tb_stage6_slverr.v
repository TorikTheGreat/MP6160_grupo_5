`timescale 1ns/1ps
//=============================================================================
// Etapa 6 -- SLVERR: rango y transacciones no soportadas.
//   En lectura CADA beat lleva su rresp; en escritura hay UNA sola bresp para
//   toda la rafaga, asi que el error tiene que acumularse ("pegajoso").
//   Un esclavo que responde error DEBE completar el protocolo igual: consumir
//   todos los beats, emitir una B, y en lectura emitir ARLEN+1 beats con rlast.
//   Colgarse aqui congelaria la regresion de todo el grupo, asi que lo que de
//   verdad vigila esta etapa es que el watchdog NO se dispare.
// MEM_WORDS=1024 => MEM_BYTES=0x2000: la frontera queda a mano.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    reg [DATA_W-1:0] antes;
    integer j;

    initial begin
        $display("--- Etapa 6: SLVERR ---");
        bfm_idle;
        do_reset;

        // (a) lectura de un beat fuera de rango: SLVERR, con rlast, sin colgarse
        axi_read_burst_chk(32'h0000_2000, 8'd0, 1'b0, {DATA_W{1'b0}}, 2'b10);

        // (b) rafaga de escritura a caballo de la frontera: el beat de dentro
        //     SI se escribe, los de fuera se descartan, y la B es SLVERR.
        //     (Decision documentada en el README: es lo que hacen los esclavos
        //     reales; la alternativa "no escribir nada" tambien seria legal.)
        antes = peek_mem((32'h0000_1FF8) >> 3);
        axi_write_burst_err(32'h0000_1FF8, 8'd3, 32'hBAD0_0000, 3'b011, 2'b01, 2'b10);
        expect_true(peek_mem((32'h0000_1FF8) >> 3) !== antes,
                    "el beat dentro de rango si se escribio");

        // (c) rafaga entera fuera de rango: 8 beats consumidos, una B, SLVERR,
        //     y la memoria intacta
        // Ojo: aqui NO vale check_all. El modelo de referencia no se ha tocado
        // (la task de error no lo actualiza), asi que su ventana esta vacia y la
        // comprobacion no podria fallar nunca. Hay que mirar la memoria directa.
        // 0x0001_0000 aliasa a mem[0] si el indice se truncara: por eso se
        // comprueba mem[0] explicitamente.
        antes = peek_mem(0);
        axi_write_burst_err(32'h0001_0000, 8'd7, 32'hDEAD_0000, 3'b011, 2'b01, 2'b10);
        expect_eq(peek_mem(0), antes,
                  "una escritura fuera de rango no debe aliasar sobre mem[0]");

        // (d) la rafaga SIGUIENTE, buena, debe volver a responder OKAY: si el
        //     bit pegajoso no se limpia, el error se filtra
        axi_write_burst(32'h0000_0040, 8'd1, 32'h600D_0000, 0, 0);
        axi_read_burst (32'h0000_0040, 8'd1);

        // (e) transacciones no soportadas: WRAP y size != 8 B.
        //     Se responde SLVERR en vez de tratarlas como INCR en silencio.
        axi_write_burst_err(32'h0000_0080, 8'd1, 32'hAAAA_0000, 3'b011, 2'b10, 2'b10);
        axi_write_burst_err(32'h0000_00C0, 8'd1, 32'hBBBB_0000, 3'b010, 2'b01, 2'b10);
        expect_eq(peek_mem(32'h0000_0080 >> 3), 64'h0, "WRAP no debe escribir memoria");
        expect_eq(peek_mem(32'h0000_00C0 >> 3), 64'h0, "size != 8B no debe escribir memoria");

        // (f) lectura a caballo de la frontera: rresp mixto, OKAY dentro y
        //     SLVERR fuera, en la misma rafaga
        drive_ar(32'h0000_1FF8, 8'd3, 3'b011, 2'b01, 0);
        for (j = 0; j <= 3; j = j + 1) begin
            @(posedge aclk);
            while (!(rvalid && rready)) @(posedge aclk);
            expect_resp(rresp, (j == 0) ? 2'b00 : 2'b10,
                        "rresp por beat a caballo de la frontera");
            expect_true(rlast === ((j == 3) ? 1'b1 : 1'b0), "rlast en el ultimo beat");
        end

        check_aw_b_pareados;
        finish_report("etapa 6");
    end
endmodule
