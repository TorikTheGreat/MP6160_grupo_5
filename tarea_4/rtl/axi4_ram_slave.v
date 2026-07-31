`timescale 1ns/1ps
//=============================================================================
// axi4_ram_slave.v -- RAM con puerto ESCLAVO AXI4 Full
// Rol E -- Tarea 4 (EC4), MP-6160 Diseno de Alto Nivel, Grupo 5
//
// CONTRATO DEL GRUPO (plan_de_trabajo.pdf, "Propuesta de las decisiones de diseno"):
//   DATA_W=64  ADDR_W=32  ID_W=4  un solo ID (0)  reloj 100 MHz
//   aresetn activo bajo, sincrono, minimo 16 ciclos
//   SOPORTADO : INCR, AWLEN 0..255 (= 1..256 beats), AWSIZE=3'b011 (8 B),
//               WSTRB completo, respuestas EN ORDEN, OKAY / SLVERR
//   NO SOPORTADO: WRAP, FIXED, out-of-order, narrow transfers
//   Rango valido : 0 .. MEM_BYTES-1   (fuera de rango => SLVERR)
//   Latencia objetivo: <= 6 ciclos por transaccion sin rafaga
//
// REGLAS DE DISENO QUE ESTE MODULO RESPETA -- las cuatro son sustantivas:
//   R1. Verilog-2001. Nada de logic / always_ff / enum / interface.
//       El entregable tiene que ser "en Verilog"; el wrapper de SystemVerilog
//       que conecta la axi4_if del rol B vive en otro fichero.
//   R2. NINGUNA salida depende combinacionalmente de una entrada. Toda salida
//       sale de un flip-flop. La spec AXI lo exige: "there must be no
//       combinatorial paths between input and output signals" (AMBA AXI,
//       A3-36/A3-37). Ni el lint ni los tests funcionales detectan una
//       violacion: es disciplina de escritura, no algo que se compruebe.
//   R3. valid nunca depende de ready (ni bvalid de bready, ni rvalid de
//       rready). "assign rvalid = arvalid & rready" seria un deadlock.
//   R4. UN SOLO bloque always escribe mem. Verilator no avisa si se incumple;
//       el Makefile lleva un chequeo manual.
//
// CAPACIDAD: 1 escritura + 1 lectura pendientes, independientes entre si.
//   Las dos FSM no se bloquean mutuamente: si lo hicieran, las secuencias
//   paralelas del testbench UVM del rol C se colgarian.
//=============================================================================

module axi4_ram_slave #(
    parameter DATA_W    = 64,
    parameter ADDR_W    = 32,
    parameter ID_W      = 4,
    parameter MEM_WORDS = 8388608          // 8 M x 64 b = 64 MB
) (
    input  wire                    aclk,
    input  wire                    aresetn,

    // ---- canal AW (direccion de escritura) ----
    input  wire [ID_W-1:0]         awid,
    input  wire [ADDR_W-1:0]       awaddr,
    input  wire [7:0]              awlen,      // beats - 1
    input  wire [2:0]              awsize,     // 3'b011 = 8 bytes
    input  wire [1:0]              awburst,    // 2'b01 = INCR
    input  wire                    awvalid,
    output reg                     awready,

    // ---- canal W (datos de escritura) ----
    input  wire [DATA_W-1:0]       wdata,
    input  wire [(DATA_W/8)-1:0]   wstrb,
    input  wire                    wlast,
    input  wire                    wvalid,
    output reg                     wready,

    // ---- canal B (respuesta de escritura) ----
    output reg  [ID_W-1:0]         bid,
    output reg  [1:0]              bresp,
    output reg                     bvalid = 1'b0,
    input  wire                    bready,

    // ---- canal AR (direccion de lectura) ----
    input  wire [ID_W-1:0]         arid,
    input  wire [ADDR_W-1:0]       araddr,
    input  wire [7:0]              arlen,
    input  wire [2:0]              arsize,
    input  wire [1:0]              arburst,
    input  wire                    arvalid,
    output reg                     arready,

    // ---- canal R (datos de lectura) ----
    output reg  [ID_W-1:0]         rid,
    output reg  [DATA_W-1:0]       rdata,
    output reg  [1:0]              rresp,
    output reg                     rlast  = 1'b0,
    output reg                     rvalid = 1'b0,
    input  wire                    rready
);

    //-------------------------------------------------------------------------
    // Constantes
    //-------------------------------------------------------------------------
    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    localparam [1:0] BURST_INCR  = 2'b01;
    localparam [2:0] SIZE_8B     = 3'b011;

    localparam [1:0] W_IDLE = 2'd0;
    localparam [1:0] W_DATA = 2'd1;
    localparam [1:0] W_RESP = 2'd2;

    localparam [0:0] R_IDLE = 1'd0;
    localparam [0:0] R_DATA = 1'd1;

    localparam NBYTES = DATA_W/8;          // 8 carriles de byte
    localparam IDX_W  = $clog2(MEM_WORDS); // indice de palabra, ancho exacto

    // Limite del espacio direccionable, DERIVADO de MEM_WORDS.
    // Se deriva a proposito: si aqui hubiera un 0x03FFFFFF fijo mientras
    // MEM_WORDS se encoge para los tests, una lectura "dentro de rango" pero
    // fuera del arreglo devolveria X y el test de SLVERR pasaria por la razon
    // equivocada.
    localparam [31:0] MEM_BYTES = MEM_WORDS * 8;

    //-------------------------------------------------------------------------
    // Memoria. La escribe UN SOLO always (regla R4).
    //-------------------------------------------------------------------------
    reg [DATA_W-1:0] mem [0:MEM_WORDS-1];

    integer i;
    initial begin
        // El testbench UVM del rol C lee direcciones que nunca escribio; sin
        // esto leeria X. El contrato del grupo lo exige explicitamente.
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = {DATA_W{1'b0}};
    end

    //-------------------------------------------------------------------------
    // Estado de la ruta de ESCRITURA
    //-------------------------------------------------------------------------
    reg [1:0]        w_state;
    reg [ADDR_W-1:0] aw_addr_q;   // direccion del beat en curso (avanza +8)
    reg [7:0]        aw_len_q;    // beats restantes: cuenta HACIA ABAJO
    reg              w_err_q;     // SLVERR "pegajoso" de la rafaga en curso

    //-------------------------------------------------------------------------
    // Estado de la ruta de LECTURA
    //-------------------------------------------------------------------------
    reg [0:0]        r_state;
    reg [ADDR_W-1:0] ar_addr_q;   // direccion del PROXIMO beat a servir
    reg [7:0]        ar_len_q;    // beats restantes despues del actual
    reg              r_bad_q;     // la rafaga pidio algo no soportado
    reg              r_oor_q;     // "pegajoso" de fuera de rango en lectura

    //-------------------------------------------------------------------------
    // Senales internas: se derivan de REGISTROS internos, no de entradas hacia
    // una salida, asi que no violan R2.
    //-------------------------------------------------------------------------
    wire [IDX_W-1:0] w_idx      = aw_addr_q[IDX_W+2:3];
    wire             w_in_range = (aw_addr_q < MEM_BYTES);

    wire [IDX_W-1:0] r_idx      = ar_addr_q[IDX_W+2:3];
    wire             r_in_range = (ar_addr_q < MEM_BYTES);

    // Primer beat de una lectura: se evalua con araddr, todavia en el bus.
    wire [IDX_W-1:0] ar_idx0      = araddr[IDX_W+2:3];
    wire             ar_in_range0 = (araddr < MEM_BYTES);

    // UN SOLO puerto de lectura sobre mem: si hubiera dos sentencias de lectura
    // con direcciones distintas, las herramientas no infieren una RAM y duplican
    // el arreglo o lo construyen en registros.
    wire [IDX_W-1:0] rd_idx  = (r_state == R_IDLE) ? ar_idx0 : r_idx;
    wire [DATA_W-1:0] rd_word = mem[rd_idx];

    integer k;

    //=========================================================================
    // Unico bloque secuencial (regla R4)
    //=========================================================================
    always @(posedge aclk) begin
        if (!aresetn) begin
            // La spec exige que durante reset un esclavo mantenga BVALID y
            // RVALID en LOW. Los *ready* no estan obligados a nada: arrancarlos
            // en 1 es legal y ahorra un ciclo de latencia por transaccion.
            awready   <= 1'b1;
            wready    <= 1'b0;
            bvalid    <= 1'b0;
            bid       <= {ID_W{1'b0}};
            bresp     <= RESP_OKAY;
            arready   <= 1'b1;
            rvalid    <= 1'b0;
            rlast     <= 1'b0;
            rid       <= {ID_W{1'b0}};
            rdata     <= {DATA_W{1'b0}};
            rresp     <= RESP_OKAY;

            w_state   <= W_IDLE;
            aw_addr_q <= {ADDR_W{1'b0}};
            aw_len_q  <= 8'd0;
            w_err_q   <= 1'b0;

            r_state   <= R_IDLE;
            ar_addr_q <= {ADDR_W{1'b0}};
            ar_len_q  <= 8'd0;
            r_bad_q   <= 1'b0;
            r_oor_q   <= 1'b0;
        end else begin

            //=================================================================
            // RUTA DE ESCRITURA
            //=================================================================
            case (w_state)

            W_IDLE: begin
                // La transferencia ocurre en el flanco donde awvalid && awready
                // son AMBOS altos, y solo ahi. En W_IDLE awready es siempre 1,
                // asi que aqui la condicion completa es documentacion; en un
                // esclavo con mas capacidad seria imprescindible.
                if (awvalid && awready) begin
                    aw_addr_q <= awaddr;
                    // Se guarda AWLEN tal cual y el contador va HACIA ABAJO:
                    // "ultimo beat" es (aw_len_q == 0). Asi no existe el
                    // off-by-one de AWLEN = beats-1.
                    aw_len_q  <= awlen;
                    // bid se carga aqui: solo importa cuando bvalid esta alto, y
                    // con capacidad 1 no puede cambiar entre medias.
                    bid       <= awid;
                    // Transaccion no soportada => SLVERR, nunca interpretarla
                    // como INCR en silencio: una secuencia aleatoria del rol C
                    // corromperia memoria sin hacer ruido.
                    w_err_q   <= (awsize != SIZE_8B) || (awburst != BURST_INCR);

                    // Capacidad 1: se deja de aceptar direcciones hasta cerrar
                    // esta rafaga. Es consecuencia de ESTA implementacion, no
                    // una obligacion de AXI.
                    awready   <= 1'b0;
                    // AW y W son canales independientes: W puede haber llegado
                    // antes y estar esperando con wvalid alto. Al subir wready
                    // aqui, ese caso se drena solo.
                    wready    <= 1'b1;
                    w_state   <= W_DATA;
                end
            end

            W_DATA: begin
                if (wvalid && wready) begin
                    // Escritura POR CARRILES: wstrb[k] habilita el byte k.
                    // wstrb[0] es el byte de direccion mas baja (vale porque
                    // todo esta alineado a 8 B). Un beat con wstrb=0 no escribe
                    // nada pero SI cuenta como beat: el conteo lo fija AWLEN.
                    // No se escribe si el beat sobra (el master mando de mas).
                    if (w_in_range && !w_err_q) begin
                        for (k = 0; k < NBYTES; k = k + 1)
                            if (wstrb[k])
                                mem[w_idx][8*k +: 8] <= wdata[8*k +: 8];
                    end

                    // SLVERR pegajoso: basta un beat fuera de rango para que la
                    // respuesta de TODA la rafaga sea SLVERR. Se compara la
                    // direccion completa de 32 bits; truncarla haria que
                    // 0x04000008 aliase a 0x00000008 y respondiera OKAY.
                    if (!w_in_range)
                        w_err_q <= 1'b1;

                    // El avance ocurre en la HANDSHAKE, no en cada ciclo. Si
                    // avanzara por ciclo, los datos saldrian esparcidos: en el
                    // sistema completo se ve como "la imagen salio corrida".
                    if (aw_len_q != 8'd0) begin
                        aw_addr_q <= aw_addr_q + 8;
                        aw_len_q  <= aw_len_q - 8'd1;
                    end else if (!wlast) begin
                        // Beats de mas: el master prometio AWLEN+1 y sigue
                        // mandando. Se consumen (no colgarse) pero no se
                        // escriben, y la respuesta sera SLVERR.
                        // El `!wlast` importa: en el ultimo beat legitimo
                        // aw_len_q ya vale 0, y sin el se marcaria error en
                        // TODA rafaga correcta.
                        w_err_q   <= 1'b1;
                    end

                    // La rafaga termina con WLAST, no con el contador propio.
                    // La spec impone la DEPENDENCIA -- "The slave must also
                    // wait for WLAST to be asserted before asserting BVALID"
                    // (A3.3.1) -- pero permite calcular el ultimo beat desde
                    // AWLEN. Que el fin se DERIVE de WLAST es decision de este
                    // diseno, y la razon es practica: terminar por el contador
                    // deja beats huerfanos en el bus cuando el master manda de
                    // mas (y se escriben al principio de la rafaga siguiente).
                    // Precio asumido: un master que olvide WLAST cuelga el
                    // canal. AXI no define timeout de esclavo; documentado en
                    // el README como limitacion.
                    if (wlast) begin
                        wready  <= 1'b0;
                        bvalid  <= 1'b1;
                        // SLVERR si hubo cualquier error previo, si este beat
                        // esta fuera de rango, o si el WLAST del master no
                        // cuadra con AWLEN (llego antes de tiempo).
                        bresp   <= (w_err_q || !w_in_range || (aw_len_q != 8'd0))
                                   ? RESP_SLVERR : RESP_OKAY;
                        w_state <= W_RESP;
                    end
                end
            end

            W_RESP: begin
                if (bvalid && bready) begin
                    bvalid  <= 1'b0;
                    awready <= 1'b1;
                    // Limpiar el error aqui, no al empezar la siguiente rafaga:
                    // si no, el SLVERR se filtra a la rafaga siguiente.
                    w_err_q <= 1'b0;
                    w_state <= W_IDLE;
                end
            end

            // Si w_state llegara a un valor imposible (propagacion de X en un
            // simulador de 4 estados), hay que recuperar TAMBIEN las salidas:
            // volver a W_IDLE con awready en 0 seria un deadlock permanente.
            default: begin
                w_state <= W_IDLE;
                awready <= 1'b1;
                wready  <= 1'b0;
                bvalid  <= 1'b0;
            end
            endcase

            //=================================================================
            // RUTA DE LECTURA -- avanza en paralelo con la de escritura
            //=================================================================
            case (r_state)

            R_IDLE: begin
                if (arvalid && arready) begin
                    // ar_addr_q apunta ya al SIGUIENTE beat; el actual se sirve
                    // en este mismo flanco desde araddr.
                    ar_addr_q <= araddr + 8;
                    ar_len_q  <= arlen;
                    r_bad_q   <= (arsize != SIZE_8B) || (arburst != BURST_INCR);
                    r_oor_q   <= !ar_in_range0;

                    arready   <= 1'b0;
                    // rdata sale de un FLIP-FLOP alimentado por mem. Nunca
                    // "assign rdata = mem[...]" combinacional.
                    rvalid    <= 1'b1;
                    rid       <= arid;
                    // Se cerotea tambien con transaccion no soportada, no solo
                    // fuera de rango: si no, un ARBURST/ARSIZE ilegal filtraria el
                    // contenido real de la memoria junto con el SLVERR.
                    rdata     <= (ar_in_range0 && (arsize == SIZE_8B)
                                                && (arburst == BURST_INCR))
                                 ? rd_word : {DATA_W{1'b0}};
                    // En lectura CADA beat lleva su propia rresp.
                    rresp     <= (ar_in_range0 && (arsize == SIZE_8B)
                                               && (arburst == BURST_INCR))
                                 ? RESP_OKAY : RESP_SLVERR;
                    rlast     <= (arlen == 8'd0);
                    r_state   <= R_DATA;
                end
            end

            R_DATA: begin
                // Se avanza SOLO en la handshake. Mientras rvalid && !rready,
                // rdata/rresp/rlast quedan estables y el contador no se mueve:
                // hacer prefetch aqui pisaria rdata y se perderia un beat.
                if (rvalid && rready) begin
                    if (ar_len_q == 8'd0) begin
                        rvalid  <= 1'b0;
                        rlast   <= 1'b0;
                        arready <= 1'b1;
                        r_bad_q <= 1'b0;
                        r_oor_q <= 1'b0;
                        r_state <= R_IDLE;
                    end else begin
                        ar_addr_q <= ar_addr_q + 8;
                        ar_len_q  <= ar_len_q - 8'd1;
                        // r_oor_q es pegajoso: una vez que un beat cae fuera
                        // de rango, los siguientes tambien responden SLVERR
                        // aunque la suma de 32 bits envuelva y "vuelva" a caer
                        // dentro. Sin esto, una rafaga que cruza los 4 GB
                        // devolveria datos reales de la memoria baja con OKAY.
                        rdata     <= (r_in_range && !r_oor_q && !r_bad_q)
                                     ? rd_word : {DATA_W{1'b0}};
                        rresp     <= (r_in_range && !r_bad_q && !r_oor_q)
                                     ? RESP_OKAY : RESP_SLVERR;
                        if (!r_in_range) r_oor_q <= 1'b1;
                        rlast     <= (ar_len_q == 8'd1);
                    end
                end
            end

            // Simetrico al default de escritura: recuperar el estado sin
            // recuperar las salidas dejaria arready en 0 para siempre (R_IDLE
            // nunca lo vuelve a subir) y rvalid huerfano.
            default: begin
                r_state <= R_IDLE;
                arready <= 1'b1;
                rvalid  <= 1'b0;
                rlast   <= 1'b0;
            end
            endcase

        end
    end

    // Nota: la rafaga termina con WLAST (lo exige A3.3.1), y el contador propio
    // se usa para DETECTAR que el master miente: si WLAST no cae en el beat
    // AWLEN, la respuesta es SLVERR. Asi no hay ni deadlock ni beats huerfanos.

endmodule
