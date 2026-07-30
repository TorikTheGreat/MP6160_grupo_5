import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi4_rolC_tests.sv"

module tb_top_rolC;
    logic aclk;
    logic aresetn;

    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end

    initial begin
        aresetn = 0;
        #20;
        aresetn = 1;
    end

    axi4_if axi_if(aclk, aresetn);

    dummy_slave dummy_dut(.axi(axi_if.slave));

    initial begin
        uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_if);
        run_test();
    end
endmodule