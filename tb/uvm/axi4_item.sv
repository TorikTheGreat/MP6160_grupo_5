`ifndef AXI4_ITEM_SV
`define AXI4_ITEM_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_item #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_sequence_item;
    
    // Control
    rand bit             is_write;
    
    // Address channel
    rand bit [ID_W-1:0]   id;
    rand bit [ADDR_W-1:0] addr;
    rand bit [7:0]        len;
    rand bit [2:0]        size;
    rand bit [1:0]        burst;
    
    // Data channel (for writes)
    // Usamos arreglos dinámicos para soportar ráfagas
    rand bit [DATA_W-1:0]      data[];
    rand bit [(DATA_W/8)-1:0]  strb[];
    
    // Response channel
    bit [1:0] resp;
    
    // UVM Factory Registration
    `uvm_object_param_utils_begin(axi4_item #(DATA_W, ADDR_W, ID_W))
        `uvm_field_int(is_write, UVM_DEFAULT)
        `uvm_field_int(id, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT)
        `uvm_field_int(len, UVM_DEFAULT)
        `uvm_field_int(size, UVM_DEFAULT)
        `uvm_field_int(burst, UVM_DEFAULT)
        `uvm_field_array_int(data, UVM_DEFAULT)
        `uvm_field_array_int(strb, UVM_DEFAULT)
        `uvm_field_int(resp, UVM_DEFAULT)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "axi4_item");
        super.new(name);
    endfunction
    
    // Restricciones basadas en el Alcance del §4 del PDF
    constraint c_data_size {
        data.size() == len + 1;
        strb.size() == len + 1;
    }
    
    constraint c_supported_bursts {
        burst == 2'b01; // Solo INCR
    }
    
    constraint c_supported_size {
        size == 3'b011; // 8 Bytes por beat = 64 bits (size=3)
    }
    
endclass
`endif
