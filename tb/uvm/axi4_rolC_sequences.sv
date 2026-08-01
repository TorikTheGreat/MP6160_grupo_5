`ifndef AXI4_ROLC_SEQUENCES_SV
`define AXI4_ROLC_SEQUENCES_SV
import uvm_pkg::*;
`include "uvm_macros.svh"

// Rol C - Secuencia dirigida: casos puntuales que cubren
// single-beat, rafaga maxima, borde cerca del limite de RAM y SLVERR.
class axi4_directed_seq #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4)
        extends uvm_sequence #(axi4_item #(DATA_W, ADDR_W, ID_W));
    `uvm_object_param_utils(axi4_directed_seq #(DATA_W, ADDR_W, ID_W))

    function new(string name = "axi4_directed_seq");
        super.new(name);
    endfunction

    task body();
        // 1. Single-beat write+read
        do_write(32'h0000_1000, 8'd0, 32'hA5A5_1234);
        do_read (32'h0000_1000, 8'd0);

        // 2. Rafaga maxima (256 beats)
        do_write(32'h0001_0000, 8'd255, 32'h1111_0000);
        do_read (32'h0001_0000, 8'd255);

        // 3. Cerca del limite superior de RAM, sin cruzar 4KB
        do_write(32'h03FF_F000, 8'd15, 32'h2222_0000);
        do_read (32'h03FF_F000, 8'd15);

        // 4. SLVERR esperado: direccion fuera de 0x03FFFFFF
        do_write(32'h0400_0000, 8'd0, 32'hDEAD_BEEF);

        `uvm_info("SEQ", "=== Directed sequence completada ===", UVM_LOW)
    endtask

    task do_write(bit [ADDR_W-1:0] a, bit [7:0] l, bit [31:0] pattern_seed);
        axi4_item #(DATA_W, ADDR_W, ID_W) it;
        it = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create("it");
        start_item(it);
        if (!it.randomize() with { addr == a; len == l; is_write == 1; })
            `uvm_error("SEQ", "randomize fallo (write)")
        for (int i = 0; i <= l; i++) begin
            it.data[i] = {32'h0, pattern_seed + i};
            it.strb[i] = '1;
        end
        finish_item(it);
    endtask

    task do_read(bit [ADDR_W-1:0] a, bit [7:0] l);
        axi4_item #(DATA_W, ADDR_W, ID_W) it;
        it = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create("it");
        start_item(it);
        if (!it.randomize() with { addr == a; len == l; is_write == 0; })
            `uvm_error("SEQ", "randomize fallo (read)")
        finish_item(it);
    endtask
endclass

// Rol C - Secuencia aleatoria: transacciones random respetando
// alineacion a 8B y sin cruzar el limite de 4KB por rafaga.
class axi4_random_seq #(parameter int DATA_W = 64, parameter int ADDR_W = 32, parameter int ID_W = 4)
        extends uvm_sequence #(axi4_item #(DATA_W, ADDR_W, ID_W));
    `uvm_object_param_utils(axi4_random_seq #(DATA_W, ADDR_W, ID_W))

    int unsigned num_trans = 20;

    function new(string name = "axi4_random_seq");
        super.new(name);
    endfunction

    task body();
        axi4_item #(DATA_W, ADDR_W, ID_W) it;
        for (int i = 0; i < num_trans; i++) begin
            it = axi4_item#(DATA_W, ADDR_W, ID_W)::type_id::create($sformatf("it_%0d", i));
            start_item(it);
            if (!it.randomize() with {
                addr inside {[32'h0000_0000 : 32'h03FF_F000]};
                addr[2:0] == 3'b000;
                len inside {[0:63]};
                (addr[11:0] + ((len + 1) * 8)) <= 4096;
            }) begin
                `uvm_error("SEQ", "randomize fallo (random)")
            end
            finish_item(it);
        end
        `uvm_info("SEQ", $sformatf("=== Random sequence completada (%0d transacciones) ===", num_trans), UVM_LOW)
    endtask
endclass
`endif