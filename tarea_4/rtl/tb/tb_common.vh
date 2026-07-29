//=============================================================================
// tb_common.vh -- arnes comun de todos los testbenches del rol E
// SE INCLUYE DENTRO de `module tb;`  (todos los TB se llaman `tb`, cada uno en
// su propio fichero y su propio binario).
//
// Reglas de este arnes, derivadas de lo que se verifico en esta maquina:
//   * PROHIBIDO $error: aborta Verilator (rc=134) y mata la corrida en el
//     primer fallo. Los mismatches usan $display + errors=errors+1.
//   * $fatal SOLO en el watchdog, y el watchdog vive en un initial
//     INDEPENDIENTE del flujo del test: si un cuelgue impide llegar a $finish,
//     el binario de Verilator no termina nunca.
//   * $dumpvars(1, tb) NO vuelca nada del DUT. Hay que anadir tb.dut.
//     Verificado: asi se ven aw_addr_q y el estado, y NO se vuelca mem.
//=============================================================================

    //-------------------------------------------------------------------------
    // Reloj de 100 MHz  (timescale 1ns/1ps => periodo 10 ns)
    //-------------------------------------------------------------------------
    // aclk y aresetn se declaran en el propio testbench, ANTES de instanciar
    // el DUT: si se declararan aqui (despues), Verilog crearia wires
    // implicitos en la instancia y el reloj no llegaria al DUT.
    always #5 aclk = ~aclk;

    //-------------------------------------------------------------------------
    // Contadores globales
    //-------------------------------------------------------------------------
    integer cycle_count = 0;
    integer errors      = 0;
    integer checks      = 0;

    always @(posedge aclk)
        cycle_count <= cycle_count + 1;

    //-------------------------------------------------------------------------
    // Watchdog -- initial INDEPENDIENTE. No lo toques.
    //-------------------------------------------------------------------------
`ifndef WATCHDOG_NS
  `define WATCHDOG_NS 2000000      // 2 ms simulados
`endif
    initial begin
        #(`WATCHDOG_NS);
        $display("");
        $display("################################################################");
        $display("# FATAL: TIMEOUT a los %0d ns (ciclo %0d). El DUT se colgo.", `WATCHDOG_NS, cycle_count);
        $display("# Abre la onda y busca el ultimo handshake que SI ocurrio.");
        $display("################################################################");
        $fatal(1);
    end

    //-------------------------------------------------------------------------
    // Volcado de ondas
    //-------------------------------------------------------------------------
`ifndef VCD_FILE
  `define VCD_FILE "sim/wave.vcd"
`endif
`ifndef NO_VCD
    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(1, tb);        // senales del testbench
        $dumpvars(1, tb.dut);    // senales internas del DUT (NO incluye mem)
    end
`endif

    //-------------------------------------------------------------------------
    // Comprobadores
    //-------------------------------------------------------------------------
    task automatic expect_eq;
        input [63:0] got;
        input [63:0] exp;
        input [639:0] tag;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  [FAIL] %0s : obtenido %h, esperado %h  (ciclo %0d)",
                         tag, got, exp, cycle_count);
            end
        end
    endtask

    task automatic expect_resp;
        input [1:0]   got;
        input [1:0]   exp;
        input [639:0] tag;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  [FAIL] %0s : resp %b, esperada %b  (ciclo %0d)",
                         tag, got, exp, cycle_count);
            end
        end
    endtask

    task automatic expect_true;
        input         cond;
        input [639:0] tag;
        begin
            checks = checks + 1;
            if (cond !== 1'b1) begin
                errors = errors + 1;
                $display("  [FAIL] %0s  (ciclo %0d)", tag, cycle_count);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Reset: 20 ciclos con aresetn bajo (el contrato pide un minimo de 16)
    //-------------------------------------------------------------------------
    task automatic do_reset;
        begin
            aresetn = 1'b0;
            repeat (20) @(posedge aclk);
            @(negedge aclk);
            aresetn = 1'b1;
            @(posedge aclk);
        end
    endtask

    //-------------------------------------------------------------------------
    // CHECKER 4 (activo desde la etapa 0):
    //   la spec exige que un esclavo mantenga BVALID y RVALID en LOW durante
    //   reset. Con reset sincrono valen X hasta el primer flanco si no se
    //   inicializan en la declaracion.
    //-------------------------------------------------------------------------
    integer reset_viol = 0;
    integer ciclos_en_reset = 0;
    always @(posedge aclk) begin
        if (!aresetn) begin
            ciclos_en_reset = ciclos_en_reset + 1;
            // Se empieza a exigir a partir del SEGUNDO flanco: el reset es
            // sincrono, asi que en el flanco en que aresetn baja las salidas
            // todavia llevan el valor anterior. Exigirlo antes es un falso
            // positivo (y le costaria un rato a quien lo viera).
            if (ciclos_en_reset > 1 && (bvalid !== 1'b0 || rvalid !== 1'b0)) begin
                if (reset_viol == 0) begin
                    errors = errors + 1;
                    $display("  [FAIL] reset: bvalid=%b rvalid=%b, deben ser 0 durante aresetn bajo (ciclo %0d)",
                             bvalid, rvalid, cycle_count);
                end
                reset_viol = reset_viol + 1;
            end
        end else begin
            ciclos_en_reset = 0;
        end
    end

    //-------------------------------------------------------------------------
    // CHECKER 5: con capacidad de 1 transaccion pendiente por direccion, el
    // *ready* de esa direccion tiene que estar BAJO mientras la transaccion
    // esta en vuelo. Si se quedara alto se aceptaria una segunda direccion que
    // luego se pierde en silencio (y en el sistema completo, la segunda rafaga
    // escribiria sobre la primera).
    //
    // Vive aqui y no en una etapa concreta a proposito: es un invariante del
    // contrato del DUT, asi que TODAS las etapas -- incluidas las que escriba
    // el rol C -- se benefician sin tener que acordarse de copiarlo.
    //-------------------------------------------------------------------------
    reg w_inflight = 1'b0;
    reg r_inflight = 1'b0;

    always @(posedge aclk) if (!aresetn) begin
        w_inflight <= 1'b0;
        r_inflight <= 1'b0;
    end else begin
        if (awvalid && awready)              w_inflight <= 1'b1;
        else if (bvalid && bready)            w_inflight <= 1'b0;
        if (arvalid && arready)              r_inflight <= 1'b1;
        else if (rvalid && rready && rlast)   r_inflight <= 1'b0;

        if (w_inflight && !(bvalid && bready) && awready) begin
            errors = errors + 1;
            $display("  [FAIL] checker5: awready alto con una escritura en vuelo (ciclo %0d)", cycle_count);
        end
        if (r_inflight && !(rvalid && rready && rlast) && arready) begin
            errors = errors + 1;
            $display("  [FAIL] checker5: arready alto con una lectura en vuelo (ciclo %0d)", cycle_count);
        end
    end

    //-------------------------------------------------------------------------
    // Informe final
    //-------------------------------------------------------------------------
    task automatic finish_report;
        input [639:0] nombre;
        begin
            $display("");
            if (errors == 0) begin
                $display("=== PASS : %0s  (%0d comprobaciones, %0d ciclos) ===",
                         nombre, checks, cycle_count);
                $finish;
            end else begin
                $display("=== FAIL : %0s  (%0d errores de %0d comprobaciones) ===",
                         nombre, errors, checks);
                $fatal(1);
            end
        end
    endtask
