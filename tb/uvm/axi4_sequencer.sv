`ifndef AXI4_SEQUENCER_SV
`define AXI4_SEQUENCER_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_sequencer #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_sequencer #(axi4_item #(DATA_W, ADDR_W, ID_W));
    `uvm_component_param_utils(axi4_sequencer #(DATA_W, ADDR_W, ID_W))
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
`endif
