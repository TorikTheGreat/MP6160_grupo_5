`ifndef AXI4_DRIVER_SV
`define AXI4_DRIVER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class axi4_driver #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4) extends uvm_driver #(axi4_item #(DATA_W, ADDR_W, ID_W));
    
    `uvm_component_param_utils(axi4_driver #(DATA_W, ADDR_W, ID_W))
    
    // Interfaz virtual para manejar los pines físicos
    virtual axi4_if #(DATA_W, ADDR_W, ID_W) vif;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_if #(DATA_W, ADDR_W, ID_W))::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV", "Could not get vif from config_db")
        end
    endfunction
    
    task run_phase(uvm_phase phase);
        reset_signals();
        forever begin
            seq_item_port.get_next_item(req);
            if (req.is_write) begin
                drive_write(req);
            end else begin
                drive_read(req);
            end
            seq_item_port.item_done();
        end
    endtask
    
    task reset_signals();
        wait(!vif.aresetn);
        vif.awvalid <= 0;
        vif.wvalid  <= 0;
        vif.bready  <= 0;
        vif.arvalid <= 0;
        vif.rready  <= 0;
        wait(vif.aresetn);
    endtask
    
    task drive_write(axi4_item #(DATA_W, ADDR_W, ID_W) req);
        // NOTA: Implementación secuencial de ejemplo. 
        // En un BFM complejo, AW y W pueden ir en paralelo usando fork/join.
        
        // 1. Canal AW (Dirección de escritura)
        @(posedge vif.aclk);
        vif.awvalid <= 1;
        vif.awid    <= req.id;
        vif.awaddr  <= req.addr;
        vif.awlen   <= req.len;
        vif.awsize  <= req.size;
        vif.awburst <= req.burst;
        
        wait(vif.awready);
        @(posedge vif.aclk);
        vif.awvalid <= 0;
        
        // 2. Canal W (Datos)
        for (int i = 0; i <= req.len; i++) begin
            vif.wvalid <= 1;
            vif.wdata  <= req.data[i];
            vif.wstrb  <= req.strb[i];
            vif.wlast  <= (i == req.len);
            
            wait(vif.wready);
            @(posedge vif.aclk);
        end
        vif.wvalid <= 0;
        vif.wlast  <= 0;
        
        // 3. Canal B (Respuesta)
        vif.bready <= 1;
        wait(vif.bvalid);
        req.resp = vif.bresp;
        @(posedge vif.aclk);
        vif.bready <= 0;
    endtask
    
    task drive_read(axi4_item #(DATA_W, ADDR_W, ID_W) req);
        // 1. Canal AR (Dirección de lectura)
        @(posedge vif.aclk);
        vif.arvalid <= 1;
        vif.arid    <= req.id;
        vif.araddr  <= req.addr;
        vif.arlen   <= req.len;
        vif.arsize  <= req.size;
        vif.arburst <= req.burst;
        
        wait(vif.arready);
        @(posedge vif.aclk);
        vif.arvalid <= 0;
        
        // 2. Canal R (Recepción de Datos)
        vif.rready <= 1;
        req.data = new[req.len + 1];
        for (int i = 0; i <= req.len; i++) begin
            wait(vif.rvalid);
            req.data[i] = vif.rdata;
            req.resp    = vif.rresp; // Se queda con la última respuesta
            @(posedge vif.aclk);
        end
        vif.rready <= 0;
    endtask
    
endclass
`endif
