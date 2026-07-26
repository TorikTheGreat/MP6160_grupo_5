`timescale 1ns/1ps

module tb_hola;

initial begin
    $display("");
    $display("====================================");
    $display("   PRUEBA DE XSIM");
    $display("====================================");
    $display("Hola desde SystemVerilog.");
    $display("");

    #10;

    $display("Fin de la simulación.");

    $finish;
end

endmodule