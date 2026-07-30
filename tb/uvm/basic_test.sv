`ifndef BASIC_TEST_SV
`define BASIC_TEST_SV
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi4_item.sv"
`include "axi4_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_sequencer.sv"
`include "axi4_agent.sv"
`include "axi4_env.sv"

class basic_seq extends uvm_sequence #(axi4_item);
    `uvm_object_utils(basic_seq)
    function new(string name = "basic_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Iniciando Prueba de Lectura y Escritura ===", UVM_LOW)
        
        // --- Transacción 1: Escritura ---
        req = axi4_item#()::type_id::create("req");
        start_item(req);
        // Single beat (len=0) a la dir 0x1000
        if (!req.randomize() with { len == 0; is_write == 1; addr == 'h1000; }) begin
            `uvm_error("SEQ", "Randomize falló")
        end
        req.data = new[1]; req.data[0] = 64'hAAAA_BBBB_CCCC_DDDD; // Dato custom
        req.strb = new[1]; req.strb[0] = 8'hFF;
        finish_item(req);
        `uvm_info("SEQ", "Transaccion de ESCRITURA completada por el Driver", UVM_LOW)
        
        #50ns; // Pequeña pausa

        // --- Transacción 2: Lectura ---
        req = axi4_item#()::type_id::create("req");
        start_item(req);
        // Single beat (len=0) a la dir 0x2000
        if (!req.randomize() with { len == 0; is_write == 0; addr == 'h2000; }) begin
            `uvm_error("SEQ", "Randomize falló")
        end
        finish_item(req);
        `uvm_info("SEQ", "Transaccion de LECTURA completada por el Driver", UVM_LOW)
        
        `uvm_info("SEQ", "=== Prueba Finalizada Exitosamente ===", UVM_LOW)
    endtask
endclass

class basic_test extends uvm_test;
    `uvm_component_utils(basic_test)
    axi4_env #() env;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi4_env#()::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        basic_seq seq;
        phase.raise_objection(this);
        seq = basic_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        #100ns;
        phase.drop_objection(this);
    endtask
endclass
`endif
