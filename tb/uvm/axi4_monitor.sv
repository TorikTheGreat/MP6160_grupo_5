`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_monitor #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_monitor;
    `uvm_component_param_utils(axi4_monitor #(DATA_W, ADDR_W, ID_W))
    virtual axi4_if #(DATA_W, ADDR_W, ID_W) vif;
    uvm_analysis_port #(axi4_item #(DATA_W, ADDR_W, ID_W)) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual axi4_if #(DATA_W, ADDR_W, ID_W))::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Could not get vif")
        end
    endfunction

    task run_phase(uvm_phase phase);
        axi4_item #(DATA_W, ADDR_W, ID_W) item;
        forever begin
            @(posedge vif.aclk);
            
            // 1. Detectar Petición de Escritura (AW)
            if (vif.awvalid && vif.awready) begin
                item = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create("item");
                item.is_write = 1;
                item.addr = vif.awaddr;
                `uvm_info("MON", $sformatf("=> Visto en Bus: Peticion ESCRITURA hacia la dir 0x%0h", item.addr), UVM_LOW)
            end
            
            // 2. Detectar Datos de Escritura viajando (W)
            if (vif.wvalid && vif.wready) begin
                `uvm_info("MON", $sformatf("=> Visto en Bus: Dato inyectado al esclavo = 0x%0h", vif.wdata), UVM_LOW)
            end

            // 3. Detectar Petición de Lectura (AR)
            if (vif.arvalid && vif.arready) begin
                item = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create("item");
                item.is_write = 0;
                item.addr = vif.araddr;
                `uvm_info("MON", $sformatf("=> Visto en Bus: Peticion LECTURA hacia la dir 0x%0h", item.addr), UVM_LOW)
            end
            
            // 4. Detectar Datos de Lectura devolviéndose (R)
            if (vif.rvalid && vif.rready) begin
                `uvm_info("MON", $sformatf("=> Visto en Bus: El esclavo respondio con el dato = 0x%0h", vif.rdata), UVM_LOW)
            end
        end
    endtask
endclass
`endif
