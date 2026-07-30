`ifndef AXI4_AGENT_SV
`define AXI4_AGENT_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_agent #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_agent;
    `uvm_component_param_utils(axi4_agent #(DATA_W, ADDR_W, ID_W))

    axi4_driver #(DATA_W, ADDR_W, ID_W) drv;
    axi4_monitor #(DATA_W, ADDR_W, ID_W) mon;
    axi4_sequencer #(DATA_W, ADDR_W, ID_W) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = axi4_driver#(DATA_W, ADDR_W, ID_W)::type_id::create("drv", this);
        mon = axi4_monitor#(DATA_W, ADDR_W, ID_W)::type_id::create("mon", this);
        sqr = axi4_sequencer#(DATA_W, ADDR_W, ID_W)::type_id::create("sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
`endif
