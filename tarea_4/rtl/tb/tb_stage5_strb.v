`timescale 1ns/1ps
//=============================================================================
// Etapa 5 -- strobes por carril. La logica ya se escribio en la etapa 2; aqui
// solo se verifica.
//   wstrb[k] habilita wdata[8k+7:8k]; el carril 0 es el byte de direccion mas
//   baja (vale porque todo esta alineado a 8 B).
//   Un beat con wstrb=0 no escribe nada pero SI cuenta como beat.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    `include "tb_setup.vh"

    integer b;
    reg [DATA_W-1:0] esperado;
    reg [ADDR_W-1:0] a;

    initial begin
        $display("--- Etapa 5: strobes ---");
        bfm_idle;
        do_reset;

        // (a) orden de carriles: FF..FF y luego ceros solo en la mitad baja.
        //     Si sale 00000000FFFFFFFF, los carriles estan invertidos.
        a = 32'h0000_0080;
        axi_write_word(a, 64'hFFFFFFFF_FFFFFFFF, 8'hFF);
        expect_eq(peek_mem(a>>3), 64'hFFFFFFFF_FFFFFFFF, "escritura completa");
        axi_write_word(a, 64'h00000000_00000000, 8'h0F);
        expect_eq(peek_mem(a>>3), 64'hFFFFFFFF_00000000,
                  "strb=0x0F solo toca los 4 bytes bajos");

        // (b) barrido de un solo carril: cada strobe cambia exactamente un byte
        for (b = 0; b < 8; b = b + 1) begin
            a = 32'h0000_0100 + b*8;
            axi_write_word(a, 64'hFFFFFFFF_FFFFFFFF, 8'hFF);
            esperado = 64'hFFFFFFFF_FFFFFFFF;
            esperado[8*b +: 8] = 8'h00;
            axi_write_word(a, 64'h00000000_00000000, (8'h01 << b));
            expect_eq(peek_mem(a>>3), esperado, "un solo carril modificado");
        end

        // (c) wstrb=0: no escribe nada, pero el beat cuenta y responde OKAY
        a = 32'h0000_0200;
        axi_write_word(a, 64'hAAAAAAAA_55555555, 8'hFF);
        esperado = peek_mem(a>>3);
        axi_write_word(a, 64'h12345678_9ABCDEF0, 8'h00);
        expect_eq(peek_mem(a>>3), esperado, "wstrb=0 deja la memoria intacta");

        check_all("etapa 5");
        check_aw_b_pareados;
        finish_report("etapa 5");
    end
endmodule
