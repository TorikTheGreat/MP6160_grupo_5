`timescale 1ns/1ps
//=============================================================================
// Etapa 9 -- el wrapper sobre la axi4_if.
//
// OJO: Icarus 12 NO soporta puertos de interfaz (ni con modport ni sin el),
// asi que esta etapa corre bajo VERILATOR, no bajo vvp como las demas.
//
// Y su resultado es PROVISIONAL: se prueba contra el stub de axi4_if que
// escribio el propio rol E. Un verde aqui no dice nada sobre la interfaz real
// del rol B; solo demuestra que el wrapper conecta bien los puertos planos.
//=============================================================================
module tb;
    localparam DATA_W    = 64;
    localparam MEM_WORDS = 1024;

    logic aclk = 0;
    logic aresetn = 0;
    always #5 aclk = ~aclk;

    axi4_if #(.DATA_W(DATA_W), .ADDR_W(32), .ID_W(4)) axi (.aclk(aclk), .aresetn(aresetn));

    axi4_ram_slave_axi4if #(
        .DATA_W(DATA_W), .ADDR_W(32), .ID_W(4), .MEM_WORDS(MEM_WORDS)
    ) dut (.axi(axi));

    int errors = 0;

    task automatic esperar(input int n);
        repeat (n) @(posedge aclk);
    endtask

    initial begin
        axi.awvalid = 0; axi.wvalid = 0; axi.arvalid = 0;
        axi.bready  = 1; axi.rready = 1;
        axi.awsize  = 3'b011; axi.awburst = 2'b01; axi.awid = 0;
        axi.arsize  = 3'b011; axi.arburst = 2'b01; axi.arid = 0;
        axi.wstrb   = '1;

        esperar(20);
        @(negedge aclk) aresetn = 1;
        esperar(2);

        // --- escritura de una rafaga de 4 beats a traves de la interfaz ---
        @(negedge aclk);
        axi.awaddr = 32'h0000_0100; axi.awlen = 8'd3; axi.awvalid = 1;
        @(posedge aclk);
        while (!axi.awready) @(posedge aclk);
        @(negedge aclk) axi.awvalid = 0;

        for (int n = 0; n <= 3; n++) begin
            @(negedge aclk);
            axi.wdata = 64'hCAFE_0000_0000_0000 + n;
            axi.wlast = (n == 3);
            axi.wvalid = 1;
            @(posedge aclk);
            while (!axi.wready) @(posedge aclk);
        end
        @(negedge aclk) begin axi.wvalid = 0; axi.wlast = 0; end

        @(posedge aclk);
        while (!(axi.bvalid && axi.bready)) @(posedge aclk);
        if (axi.bresp !== 2'b00) begin
            $display("  [FAIL] bresp = %b", axi.bresp); errors++;
        end

        // --- relectura por la interfaz ---
        @(negedge aclk);
        axi.araddr = 32'h0000_0100; axi.arlen = 8'd3; axi.arvalid = 1;
        @(posedge aclk);
        while (!axi.arready) @(posedge aclk);
        @(negedge aclk) axi.arvalid = 0;

        for (int n = 0; n <= 3; n++) begin
            @(posedge aclk);
            while (!(axi.rvalid && axi.rready)) @(posedge aclk);
            if (axi.rdata !== (64'hCAFE_0000_0000_0000 + n)) begin
                $display("  [FAIL] beat %0d: rdata=%h", n, axi.rdata); errors++;
            end
            if (axi.rlast !== (n == 3)) begin
                $display("  [FAIL] beat %0d: rlast=%b", n, axi.rlast); errors++;
            end
        end

        if (errors == 0) begin
            $display("=== PASS : etapa 9 (wrapper, PROVISIONAL contra el stub) ===");
            $finish;
        end else begin
            // $fatal y no $finish: bajo Verilator, $finish devuelve 0 y
            // `make regress` daria verde con el wrapper roto.
            $display("=== FAIL : etapa 9 (%0d errores) ===", errors);
            $fatal(1);
        end
    end

    initial begin
        #100000;
        $display("=== FAIL : etapa 9 TIMEOUT ===");
        $fatal(1);
    end
endmodule
