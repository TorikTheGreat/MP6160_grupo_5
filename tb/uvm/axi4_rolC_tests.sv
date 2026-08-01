`ifndef AXI4_ROLC_TESTS_SV
`define AXI4_ROLC_TESTS_SV
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi4_item.sv"
`include "axi4_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_monitor_fixed.sv"
`include "axi4_sequencer.sv"
`include "axi4_agent.sv"
`include "axi4_env.sv"
`include "axi4_scoreboard.sv"
`include "axi4_coverage.sv"
`include "axi4_rolC_sequences.sv"

// Rol C - Test dirigido: corre axi4_directed_seq con scoreboard + cobertura
// conectados al monitor corregido (via factory override, sin tocar a B).
class axi4_directed_test extends uvm_test;
    `uvm_component_utils(axi4_directed_test)

    axi4_env #() env;
    axi4_scoreboard #() sb;
    axi4_coverage #() cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Reemplaza el monitor stub de B por el corregido, sin editar su archivo.
        set_type_override_by_type(axi4_monitor#()::get_type(), axi4_monitor_fixed#()::get_type());

        env = axi4_env#()::type_id::create("env", this);
        sb  = axi4_scoreboard#()::type_id::create("sb", this);
        cov = axi4_coverage#()::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.agent.mon.ap.connect(sb.item_export);
        env.agent.mon.ap.connect(cov.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_directed_seq#() seq;
        phase.raise_objection(this);
        seq = axi4_directed_seq#()::type_id::create("seq");
        seq.start(env.agent.sqr);
        #500ns;
        phase.drop_objection(this);
    endtask
endclass

// Rol C - Test aleatorio: corre axi4_random_seq con scoreboard + cobertura.
class axi4_random_test extends uvm_test;
    `uvm_component_utils(axi4_random_test)

    axi4_env #() env;
    axi4_scoreboard #() sb;
    axi4_coverage #() cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        set_type_override_by_type(axi4_monitor#()::get_type(), axi4_monitor_fixed#()::get_type());

        env = axi4_env#()::type_id::create("env", this);
        sb  = axi4_scoreboard#()::type_id::create("sb", this);
        cov = axi4_coverage#()::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.agent.mon.ap.connect(sb.item_export);
        env.agent.mon.ap.connect(cov.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_random_seq#() seq;
        phase.raise_objection(this);
        seq = axi4_random_seq#()::type_id::create("seq");
        seq.num_trans = 40;
        seq.start(env.agent.sqr);
        #4000ns;
        phase.drop_objection(this);
    endtask
endclass
`endif