`ifndef AXI4_ENV_SV
`define AXI4_ENV_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_env #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_env;
    `uvm_component_param_utils(axi4_env #(DATA_W, ADDR_W, ID_W))
    
    axi4_agent #(DATA_W, ADDR_W, ID_W) agent;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = axi4_agent#(DATA_W, ADDR_W, ID_W)::type_id::create("agent", this);
    endfunction
endclass
`endif
