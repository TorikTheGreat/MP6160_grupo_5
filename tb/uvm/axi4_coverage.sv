`ifndef AXI4_COVERAGE_SV
`define AXI4_COVERAGE_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

// Rol C - Cobertura funcional: tipo de operacion, longitud de rafaga,
// region de direccion (incluye la regla de 4KB) y codigo de respuesta.
class axi4_coverage #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4)
        extends uvm_subscriber #(axi4_item #(DATA_W, ADDR_W, ID_W));
    `uvm_component_param_utils(axi4_coverage #(DATA_W, ADDR_W, ID_W))

    axi4_item #(DATA_W, ADDR_W, ID_W) item_cg;

    covergroup cg;
        option.per_instance = 1;

        cp_is_write: coverpoint item_cg.is_write {
            bins write = {1};
            bins read  = {0};
        }

        cp_len: coverpoint item_cg.len {
            bins single   = {0};
            bins short_b  = {[1:15]};
            bins medium_b = {[16:63]};
            bins long_b   = {[64:254]};
            bins max_b    = {255};
        }

        cp_addr_region: coverpoint item_cg.addr {
            bins low_ram      = {[32'h0000_0000 : 32'h0000_FFFF]};
            bins mid_ram      = {[32'h0001_0000 : 32'h03FE_FFFF]};
            bins high_ram     = {[32'h03FF_0000 : 32'h03FF_FFFF]};
            bins out_of_range = {[32'h0400_0000 : 32'hFFFF_FFFF]};
        }

        cp_resp: coverpoint item_cg.resp {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        cp_4kb_edge: coverpoint (item_cg.addr[11:0] + ((item_cg.len + 1) * 8)) {
            bins near_edge      = {[4032:4096]};
            bins away_from_edge = default;
        }

        cx_write_x_len: cross cp_is_write, cp_len;
        cx_addr_x_resp: cross cp_addr_region, cp_resp;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();
    endfunction

    function void write(axi4_item #(DATA_W, ADDR_W, ID_W) t);
        item_cg = t;
        cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("Cobertura funcional: %0.2f%%", cg.get_coverage()), UVM_LOW)
    endfunction
endclass
`endif