`ifndef AXI4_SCOREBOARD_SV
`define AXI4_SCOREBOARD_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

// Rol C - Scoreboard: modelo de memoria de referencia por bytes,
// aplica escrituras y verifica lecturas contra lo escrito.
// No inicializado -> se asume 0 si no existe (igual que el DUT: reg init en 0).
class axi4_scoreboard #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_component;
    `uvm_component_param_utils(axi4_scoreboard #(DATA_W, ADDR_W, ID_W))

    uvm_analysis_imp #(axi4_item #(DATA_W, ADDR_W, ID_W), axi4_scoreboard #(DATA_W, ADDR_W, ID_W)) item_export;

    bit [7:0] shadow_mem[bit [ADDR_W-1:0]];

    localparam bit [ADDR_W-1:0] RAM_LAST = 32'h03FF_FFFF; // 64 MB: 0x0..0x03FFFFFF

    int unsigned num_writes = 0;
    int unsigned num_reads  = 0;
    int unsigned num_pass   = 0;
    int unsigned num_fail   = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    function void write(axi4_item #(DATA_W, ADDR_W, ID_W) item);
        int beats = item.len + 1;
        int bytes_per_beat = (1 << item.size);

        if (item.is_write) begin
            num_writes++;
            for (int b = 0; b < beats; b++) begin
                bit [ADDR_W-1:0] beat_addr = item.addr + b*bytes_per_beat;
                for (int byte_i = 0; byte_i < bytes_per_beat; byte_i++) begin
                    if (item.strb[b][byte_i]) begin
                        shadow_mem[beat_addr + byte_i] = item.data[b][byte_i*8 +: 8];
                    end
                end
            end
        end else begin
            num_reads++;
            for (int b = 0; b < beats; b++) begin
                bit [ADDR_W-1:0] beat_addr = item.addr + b*bytes_per_beat;
                bit [DATA_W-1:0] expected = '0;
                for (int byte_i = 0; byte_i < bytes_per_beat; byte_i++) begin
                    bit [7:0] eb = shadow_mem.exists(beat_addr+byte_i) ? shadow_mem[beat_addr+byte_i] : 8'h00;
                    expected[byte_i*8 +: 8] = eb;
                end
                if (item.data[b] !== expected) begin
                    num_fail++;
                    `uvm_error("SB", $sformatf("MISMATCH lectura addr=0x%0h beat=%0d esperado=0x%0h obtenido=0x%0h",
                                beat_addr, b, expected, item.data[b]))
                end else begin
                    num_pass++;
                end
            end
        end

        check_response(item, beats, bytes_per_beat);
    endfunction

    function void check_response(axi4_item #(DATA_W, ADDR_W, ID_W) item, int beats, int bytes_per_beat);
        bit [ADDR_W-1:0] last_addr = item.addr + (beats-1)*bytes_per_beat + (bytes_per_beat-1);
        bit expect_slverr = (item.addr > RAM_LAST) || (last_addr > RAM_LAST);
        if (expect_slverr) begin
            if (item.resp != 2'b10)
                `uvm_error("SB", $sformatf("Se esperaba SLVERR para addr=0x%0h y se obtuvo resp=%0d", item.addr, item.resp))
        end else begin
            if (item.resp != 2'b00)
                `uvm_error("SB", $sformatf("Se esperaba OKAY para addr=0x%0h y se obtuvo resp=%0d", item.addr, item.resp))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("Resumen: writes=%0d reads=%0d beats_pass=%0d beats_fail=%0d",
                    num_writes, num_reads, num_pass, num_fail), UVM_LOW)
        if (num_fail == 0)
            `uvm_info("SB", "SCOREBOARD_PASS", UVM_LOW)
        else
            `uvm_error("SB", "SCOREBOARD_FAIL")
    endfunction
endclass
`endif