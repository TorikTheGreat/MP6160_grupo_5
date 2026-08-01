`ifndef AXI4_MONITOR_FIXED_SV
`define AXI4_MONITOR_FIXED_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

// Rol C - version corregida del monitor de Rol B.
// NO reemplaza axi4_monitor.sv de B; se activa via factory override
// (ver axi4_rolC_tests.sv) para no tocar ningun archivo de B.
// El original detectaba actividad en el bus pero nunca llamaba ap.write(),
// asi que scoreboard/cobertura nunca recibian transacciones.
class axi4_monitor_fixed #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4)
        extends axi4_monitor #(DATA_W, ADDR_W, ID_W);
    `uvm_component_param_utils(axi4_monitor_fixed #(DATA_W, ADDR_W, ID_W))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi4_item #(DATA_W, ADDR_W, ID_W) wr_item;
        bit [DATA_W-1:0]     wdata_q[$];
        bit [(DATA_W/8)-1:0] wstrb_q[$];
        bit collecting_write = 0;

        axi4_item #(DATA_W, ADDR_W, ID_W) rd_item;
        bit [DATA_W-1:0] rdata_q[$];
        bit collecting_read = 0;

        forever begin
            @(posedge vif.aclk);

            if (vif.awvalid && vif.awready) begin
                wr_item = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create("wr_item");
                wr_item.is_write = 1;
                wr_item.id    = vif.awid;
                wr_item.addr  = vif.awaddr;
                wr_item.len   = vif.awlen;
                wr_item.size  = vif.awsize;
                wr_item.burst = vif.awburst;
                wdata_q.delete();
                wstrb_q.delete();
                collecting_write = 1;
            end

            if (collecting_write && vif.wvalid && vif.wready) begin
                wdata_q.push_back(vif.wdata);
                wstrb_q.push_back(vif.wstrb);
                if (vif.wlast) collecting_write = 0;
            end

            if (vif.bvalid && vif.bready) begin
                wr_item.data = new[wdata_q.size()];
                wr_item.strb = new[wstrb_q.size()];
                foreach (wdata_q[i]) begin
                    wr_item.data[i] = wdata_q[i];
                    wr_item.strb[i] = wstrb_q[i];
                end
                wr_item.resp = vif.bresp;
                ap.write(wr_item);
                `uvm_info("MONFIX", $sformatf("WRITE addr=0x%0h len=%0d resp=%0d",
                            wr_item.addr, wr_item.len, wr_item.resp), UVM_HIGH)
            end

            if (vif.arvalid && vif.arready) begin
                rd_item = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create("rd_item");
                rd_item.is_write = 0;
                rd_item.id    = vif.arid;
                rd_item.addr  = vif.araddr;
                rd_item.len   = vif.arlen;
                rd_item.size  = vif.arsize;
                rd_item.burst = vif.arburst;
                rdata_q.delete();
                collecting_read = 1;
            end

            if (collecting_read && vif.rvalid && vif.rready) begin
                rdata_q.push_back(vif.rdata);
                if (vif.rlast) begin
                    rd_item.data = new[rdata_q.size()];
                    rd_item.strb = new[rdata_q.size()];
                    foreach (rdata_q[i]) rd_item.data[i] = rdata_q[i];
                    rd_item.resp = vif.rresp;
                    ap.write(rd_item);
                    `uvm_info("MONFIX", $sformatf("READ addr=0x%0h len=%0d resp=%0d",
                                rd_item.addr, rd_item.len, rd_item.resp), UVM_HIGH)
                    collecting_read = 0;
                end
            end
        end
    endtask
endclass
`endif