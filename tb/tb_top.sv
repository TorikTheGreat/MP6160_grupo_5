import uvm_pkg::*;
`include "uvm_macros.svh"
`include "basic_test.sv"

module tb_top;
    logic aclk;
    logic aresetn;

    // Generador de Reloj (100MHz)
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk; 
    end

    // Generador de Reset
    initial begin
        aresetn = 0;
        #20;
        aresetn = 1;
    end

    // Interfaz
    axi4_if axi_if(aclk, aresetn);

    // Andamio de Esclavo (DUT falso)
    dummy_slave dummy_dut(.axi(axi_if.slave));

    // Despliegue de UVM
    initial begin
        // Pasa la interfaz virtual a las clases UVM
        uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_if);
        // Lanza el test
        run_test("basic_test");
    end
endmodule
