//=============================================================================
// axi4_master_bfm.vh -- master AXI4 minimo para los testbenches del rol E
// SE INCLUYE DENTRO de `module tb;`, DESPUES de tb_common.vh.
//
// No hay UVM en esta maquina, asi que esto sustituye al agente:
//   * las tasks manejan directamente los reg del TB (por eso van en un .vh
//     incluido y no en un modulo aparte: desde otro modulo habria que pelear
//     con `ref`);
//   * `randomize()` no existe en Icarus 12 -> LFSR de 8 bits, determinista;
//   * las SVA concurrentes tampoco -> tres checkers procedurales.
//
// Convenio de manejo del bus: las senales se pinchan en el FLANCO DE BAJADA y
// se muestrean en el de subida. Asi no hay carrera con el DUT, que muestrea en
// posedge, y el codigo se lee como el cronograma.
//=============================================================================

    localparam NB = DATA_W/8;               // carriles de byte
    localparam [NB-1:0] strb_full = {NB{1'b1}};

    //-------------------------------------------------------------------------
    // Modelo de referencia. Solo se compara la ventana tocada, para que
    // check_all() siga siendo barato con MEM_WORDS grande.
    //-------------------------------------------------------------------------
    // El modelo de referencia se acota: sin esto, a 64 MB duplica la huella de
    // memoria de la simulacion (y el RSS que se reporta al rol D saldria al
    // doble de lo que ocupa el DUT). Todas las etapas usan MEM_WORDS <= 8192,
    // asi que en la regresion el tope no recorta nada.
    localparam REF_WORDS = (MEM_WORDS < 65536) ? MEM_WORDS : 65536;
    reg [DATA_W-1:0] ref_mem [0:REF_WORDS-1];
    integer          touch_lo;
    integer          touch_hi;

    integer ini;
    initial begin
        for (ini = 0; ini < REF_WORDS; ini = ini + 1)
            ref_mem[ini] = {DATA_W{1'b0}};
        touch_lo = REF_WORDS;
        touch_hi = -1;
    end

    // Patron de datos determinista: mitad alta = semilla, mitad baja = indice
    // del beat. Cualquier beat descolocado salta a la vista en la onda.
    function automatic [DATA_W-1:0] beat_data;
        input [31:0] seed;
        input [31:0] idx;
        begin
            beat_data = {seed, idx};
        end
    endfunction

    task automatic ref_write;                          // aplica un beat al modelo
        input [ADDR_W-1:0] addr;
        input [DATA_W-1:0] data;
        input [NB-1:0]     strb;
        integer            widx, b;
        begin
            if (addr >= REF_WORDS*8 && addr < MEM_BYTES_TB) begin
                $display("  [AVISO] ref_write fuera de la ventana del modelo (dir 0x%h): la cobertura de check_all no llega ahi", addr);
            end
            if (addr < REF_WORDS*8) begin
                widx = addr >> 3;
                for (b = 0; b < NB; b = b + 1)
                    if (strb[b]) ref_mem[widx][8*b +: 8] = data[8*b +: 8];
                if (widx < touch_lo) touch_lo = widx;
                if (widx > touch_hi) touch_hi = widx;
            end
        end
    endtask

    // Compara la memoria del DUT contra el modelo. Caza los off-by-one del
    // camino de ESCRITURA; el camino de lectura hay que comprobarlo por el
    // canal R (axi_read_burst), no aqui.
    task automatic check_all;
        input [639:0] tag;
        integer c, malos;
        begin
            malos = 0;
            // Sin esto, una llamada a check_all antes de haber tocado el modelo
            // recorre cero palabras, no puede fallar nunca, y suma un `check`
            // que da falsa confianza.
            if (touch_hi < touch_lo) begin
                errors = errors + 1;
                $display("  [FAIL] %0s: check_all sobre una ventana VACIA (no se ha escrito nada por el modelo)", tag);
            end
            for (c = touch_lo; c <= touch_hi; c = c + 1) begin
                if (peek_mem(c) !== ref_mem[c]) begin
                    if (malos < 5)
                        $display("  [FAIL] %0s: mem[%0d] (dir 0x%h) = %h, esperado %h",
                                 tag, c, c*8, peek_mem(c), ref_mem[c]);
                    malos = malos + 1;
                end
            end
            checks = checks + 1;
            if (malos != 0) begin
                errors = errors + 1;
                $display("  [FAIL] %0s: %0d palabras distintas", tag, malos);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Reset del lado master: todas las *valid* abajo, como exige la spec.
    //-------------------------------------------------------------------------
    task automatic bfm_idle;
        begin
            awvalid = 1'b0; awaddr = 0; awlen = 0; awsize = 3'b011;
            awburst = 2'b01; awid = 0;
            wvalid  = 1'b0; wdata = 0; wstrb = {NB{1'b1}}; wlast = 1'b0;
            bready  = 1'b1;
            arvalid = 1'b0; araddr = 0; arlen = 0; arsize = 3'b011;
            arburst = 2'b01; arid = 0;
            rready  = 1'b1;
        end
    endtask

    //-------------------------------------------------------------------------
    // Canal AW: pincha la direccion y espera la handshake.
    //-------------------------------------------------------------------------
    task automatic drive_aw;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [2:0]        asize;
        input [1:0]        aburst;
        input integer      delay;
        begin
            repeat (delay) @(posedge aclk);
            @(negedge aclk);
            awaddr  = addr;
            awlen   = alen;
            awsize  = asize;
            awburst = aburst;
            awvalid = 1'b1;   // awid lo fija el llamante (por defecto 0)
            @(posedge aclk);
            while (!awready) @(posedge aclk);   // la handshake fue en este flanco
            @(negedge aclk);
            awvalid = 1'b0;
        end
    endtask

    //-------------------------------------------------------------------------
    // Canal W: alen+1 beats seguidos, sin bajar wvalid entre ellos.
    //-------------------------------------------------------------------------
    task automatic drive_w;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [31:0]       seed;
        input [NB-1:0]     strb;
        input integer      delay;
        input              actualiza_ref;
        integer            n;
        begin
            repeat (delay) @(posedge aclk);
            for (n = 0; n <= alen; n = n + 1) begin
                @(negedge aclk);
                wdata  = beat_data(seed, n);
                wstrb  = strb;
                wlast  = (n == alen);
                wvalid = 1'b1;
                @(posedge aclk);
                while (!wready) @(posedge aclk);
                if (actualiza_ref)
                    ref_write(addr + n*8, beat_data(seed, n), strb);
            end
            @(negedge aclk);
            wvalid = 1'b0;
            wlast  = 1'b0;
        end
    endtask

    // Igual que drive_w pero dejando `gap` ciclos con wvalid BAJO entre beats.
    // Sin esto, todas las rafagas del banco son de cero burbujas y "avanzar por
    // ciclo" es indistinguible de "avanzar por handshake".
    task automatic drive_w_gap;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [31:0]       seed;
        input integer      gap;
        integer            n;
        begin
            for (n = 0; n <= alen; n = n + 1) begin
                if (n != 0 && gap != 0) begin
                    @(negedge aclk);
                    wvalid = 1'b0;
                    repeat (gap) @(posedge aclk);
                end
                @(negedge aclk);
                wdata  = beat_data(seed, n);
                wstrb  = {NB{1'b1}};
                wlast  = (n == alen);
                wvalid = 1'b1;
                @(posedge aclk);
                while (!wready) @(posedge aclk);
                ref_write(addr + n*8, beat_data(seed, n), strb_full);
            end
            @(negedge aclk);
            wvalid = 1'b0;
            wlast  = 1'b0;
        end
    endtask

    task automatic axi_write_burst_gap;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [31:0]       seed;
        input integer      gap;
        begin
            fork
                drive_aw(addr, alen, 3'b011, 2'b01, 0);
                drive_w_gap(addr, alen, seed, gap);
                wait_b(2'b00, "bresp con huecos en W");
            join
        end
    endtask

    //-------------------------------------------------------------------------
    // Canal B: espera la respuesta y la comprueba.
    //-------------------------------------------------------------------------
    task automatic wait_b;
        input [1:0]   resp_esperada;
        input [639:0] tag;
        begin
            @(posedge aclk);
            while (!(bvalid && bready)) @(posedge aclk);
            expect_resp(bresp, resp_esperada, tag);
            // se compara contra el awid REALMENTE emitido, no contra 0: si se
            // clavara a 0, un DUT que no ecoara el ID pasaria inadvertido.
            expect_eq({{(64-ID_W){1'b0}}, bid}, {{(64-ID_W){1'b0}}, awid},
                      "bid debe ecoar el awid emitido");
        end
    endtask

    //-------------------------------------------------------------------------
    // Rafaga de escritura completa. aw_delay/w_delay permiten forzar que W
    // llegue ANTES que AW, que es el caso que rompe las FSM mal escritas.
    //-------------------------------------------------------------------------
    task automatic axi_write_burst;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [31:0]       seed;
        input integer      aw_delay;
        input integer      w_delay;
        begin
            fork
                drive_aw(addr, alen, 3'b011, 2'b01, aw_delay);
                drive_w (addr, alen, seed, {NB{1'b1}}, w_delay, 1'b1);
                wait_b  (2'b00, "bresp de escritura OKAY");
            join
        end
    endtask

    // Variante con strobes a medida (y sin tocar el modelo si se pide).
    task automatic axi_write_burst_strb;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [31:0]       seed;
        input [NB-1:0]     strb;
        begin
            fork
                drive_aw(addr, alen, 3'b011, 2'b01, 0);
                drive_w (addr, alen, seed, strb, 0, 1'b1);
                wait_b  (2'b00, "bresp de escritura con strobes");
            join
        end
    endtask

    // Variante que espera un SLVERR y NO actualiza el modelo de referencia.
    task automatic axi_write_burst_err;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [31:0]       seed;
        input [2:0]        asize;
        input [1:0]        aburst;
        input [1:0]        resp_esperada;
        begin
            fork
                drive_aw(addr, alen, asize, aburst, 0);
                drive_w (addr, alen, seed, {NB{1'b1}}, 0, 1'b0);
                wait_b  (resp_esperada, "bresp esperada");
            join
        end
    endtask

    // Escribe UNA palabra literal (no el patron seed/indice). Util para los
    // tests de strobes, donde interesa el valor exacto de cada byte.
    task automatic axi_write_word;
        input [ADDR_W-1:0] addr;
        input [DATA_W-1:0] data;
        input [NB-1:0]     strb;
        begin
            fork
                drive_aw(addr, 8'd0, 3'b011, 2'b01, 0);
                begin
                    @(negedge aclk);
                    wdata = data; wstrb = strb; wlast = 1'b1; wvalid = 1'b1;
                    @(posedge aclk);
                    while (!wready) @(posedge aclk);
                    ref_write(addr, data, strb);
                    @(negedge aclk);
                    wvalid = 1'b0; wlast = 1'b0;
                end
                wait_b(2'b00, "bresp de axi_write_word");
            join
        end
    endtask

    //-------------------------------------------------------------------------
    // Rafaga de LECTURA. Comprueba, por el canal R: dato de cada beat, rresp,
    // rid, rlast en el beat correcto y numero total de beats.
    // Esto es lo que check_all() NO puede comprobar.
    //-------------------------------------------------------------------------
    // Fase de direccion de lectura. Existe como task porque estaba copiada en
    // cuatro etapas: si cambia el convenio de flancos, hay que tocar un sitio.
    task automatic drive_ar;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input [2:0]        asize;
        input [1:0]        aburst;
        input integer      delay;
        begin
            repeat (delay) @(posedge aclk);
            @(negedge aclk);
            araddr  = addr;
            arlen   = alen;
            arsize  = asize;
            arburst = aburst;
            arvalid = 1'b1;
            @(posedge aclk);
            while (!arready) @(posedge aclk);
            @(negedge aclk);
            arvalid = 1'b0;
        end
    endtask

    task automatic axi_read_burst_chk;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        input              contra_ref;      // 1: comparar contra ref_mem
        input [DATA_W-1:0] valor_fijo;      // si contra_ref=0, este valor
        input [1:0]        resp_esperada;
        integer            n, widx;
        reg   [DATA_W-1:0] esperado;
        begin
            drive_ar(addr, alen, 3'b011, 2'b01, 0);

            for (n = 0; n <= alen; n = n + 1) begin
                @(posedge aclk);
                while (!(rvalid && rready)) @(posedge aclk);

                if (resp_esperada == 2'b00) begin
                    widx     = (addr + n*8) >> 3;
                    esperado = contra_ref ? ref_mem[widx] : valor_fijo;
                    expect_eq(rdata, esperado, "rdata del beat");
                end
                expect_resp(rresp, resp_esperada, "rresp del beat");
                expect_eq({{(64-ID_W){1'b0}}, rid}, {{(64-ID_W){1'b0}}, arid},
                          "rid debe ecoar el arid emitido");
                expect_true(rlast === ((n == alen) ? 1'b1 : 1'b0),
                            "rlast solo en el ultimo beat");
            end
        end
    endtask

    // Atajo para el caso comun: leer y comparar contra el modelo.
    task automatic axi_read_burst;
        input [ADDR_W-1:0] addr;
        input [7:0]        alen;
        begin
            axi_read_burst_chk(addr, alen, 1'b1, {DATA_W{1'b0}}, 2'b00);
        end
    endtask

    //-------------------------------------------------------------------------
    // LFSR de 8 bits: sustituto determinista de randomize()
    //-------------------------------------------------------------------------
    reg [7:0] lfsr = 8'hA5;
    task automatic lfsr_next;
        begin
            lfsr = {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        end
    endtask

    //=========================================================================
    // CHECKERS PROCEDURALES -- activos en todos los tests desde la etapa 2.
    // Son el sustituto de las SVA concurrentes, que Icarus no soporta.
    //=========================================================================

    // (1) Estabilidad: mientras valid este alto y ready bajo, ni valid puede
    //     caerse ni la carga util puede cambiar.
    reg              aw_pend = 1'b0;
    reg [ADDR_W-1:0] aw_addr_prev;
    reg [7:0]        aw_len_prev;
    always @(posedge aclk) if (aresetn) begin
        if (aw_pend) begin
            if (!awvalid) begin
                errors = errors + 1;
                $display("  [FAIL] checker1: awvalid se cayo antes de la handshake (ciclo %0d)", cycle_count);
            end else if (awaddr !== aw_addr_prev || awlen !== aw_len_prev) begin
                errors = errors + 1;
                $display("  [FAIL] checker1: la carga util de AW cambio antes de la handshake (ciclo %0d)", cycle_count);
            end
        end
        aw_pend      <= awvalid && !awready;
        aw_addr_prev <= awaddr;
        aw_len_prev  <= awlen;
    end

    reg              r_pend = 1'b0;
    reg [DATA_W-1:0] rdata_prev;
    always @(posedge aclk) if (aresetn) begin
        if (r_pend) begin
            if (!rvalid) begin
                errors = errors + 1;
                $display("  [FAIL] checker1: rvalid se cayo antes de la handshake (ciclo %0d)", cycle_count);
            end else if (rdata !== rdata_prev) begin
                errors = errors + 1;
                $display("  [FAIL] checker1: rdata cambio con rvalid alto y rready bajo (ciclo %0d)", cycle_count);
            end
        end
        r_pend     <= rvalid && !rready;
        rdata_prev <= rdata;
    end

    // (2) Exactamente una B por cada AW.
    integer n_aw = 0;
    integer n_b  = 0;
    always @(posedge aclk) if (!aresetn) begin
        // Un reset abandona las transacciones en vuelo: una AW sin su B es la
        // conducta correcta, no un fallo. La correspondencia empieza de cero.
        n_aw <= 0;
        n_b  <= 0;
    end else begin
        if (awvalid && awready) n_aw <= n_aw + 1;
        if (bvalid  && bready ) n_b  <= n_b  + 1;
    end

    task automatic check_aw_b_pareados;
        begin
            // n_aw/n_b se actualizan con asignacion no bloqueante en el mismo
            // flanco en que wait_b retorna: hay que dejar pasar un ciclo.
            @(posedge aclk);
            checks = checks + 1;
            if (n_aw !== n_b) begin
                errors = errors + 1;
                $display("  [FAIL] checker2: %0d AW contra %0d B", n_aw, n_b);
            end
        end
    endtask

    // (3) El wlast del master cae en el beat AWLEN de la rafaga en vuelo.
    //     Comprueba al ESTIMULO, no al DUT: si el BFM mintiera, los fallos del
    //     DUT serian inexplicables. El AWLEN se engancha en la handshake de AW.
    integer   w_beats  = 0;
    reg [7:0] len_flight = 8'd0;
    // Las etapas que emiten a proposito un master no conforme (p.ej. WLAST
    // fuera de sitio, para comprobar como reacciona el esclavo) suben esta
    // bandera mientras dura el estimulo ilegal.
    reg       estimulo_ilegal = 1'b0;
    always @(posedge aclk) if (!aresetn) begin
        w_beats    <= 0;
        len_flight <= 8'd0;
    end else begin
        if (awvalid && awready) len_flight <= awlen;
        if (wvalid && wready) begin
            if (wlast) begin
                if (w_beats[7:0] !== len_flight && !estimulo_ilegal) begin
                    errors = errors + 1;
                    $display("  [FAIL] checker3: wlast en el beat %0d pero AWLEN=%0d (ciclo %0d)",
                             w_beats, len_flight, cycle_count);
                end
                w_beats <= 0;
            end else begin
                w_beats <= w_beats + 1;
            end
        end
    end

    // Contador de comprobaciones del checker3, para que se vea que corre.
    task automatic check_wlast_ok;
        begin
            @(posedge aclk);
            checks = checks + 1;
        end
    endtask
