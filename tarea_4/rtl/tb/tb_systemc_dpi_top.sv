`timescale 1ns/1ps
//=============================================================================
// Top real de co-simulacion para el rol D.
//
// Integra:
//   * el DUT AXI4 plano,
//   * el BFM minimo reutilizado desde tb/,
//   * el contrato DPI de SystemC,
//   * el loop de servicio por ciclo que llama systemc_service() una vez por
//     flanco y lanza una solicitud AXI cuando el proxy publica una nueva.
//=============================================================================
module tb;
    parameter MEM_WORDS = 1024;
    localparam DATA_W = 64;
    localparam ADDR_W = 32;
    localparam ID_W   = 4;

    import systemc_dpi_pkg::*;

    `include "tb_setup_axi4if.vh"
    `include "axi4_bfm_master.sv"

    task automatic systemc_finish_report;
        begin
            if (!systemc_passed()) begin
                errors = errors + 1;
                $display("[FAIL] SystemC reporto FAIL");
            end

            systemc_destroy();
            finish_report("top real de co-simulacion DPI/SystemC");
        end
    endtask

    initial begin
        bfm_idle;
        do_reset;

        if (!systemc_create()) begin
            errors = errors + 1;
            $display("[FAIL] systemc_create() no pudo crear el sistema");
            $fatal(1);
        end

        while (!systemc_is_finished()) begin
            @(posedge aclk);

            if (!systemc_service()) begin
                errors = errors + 1;
                $display("[FAIL] systemc_service() fallo en el ciclo %0d", cycle_count);
                $fatal(1);
            end

            dpi_try_launch_request();
        end

        while (dpi_request_busy) begin
            @(posedge aclk);
        end

        systemc_finish_report();
    end
endmodule