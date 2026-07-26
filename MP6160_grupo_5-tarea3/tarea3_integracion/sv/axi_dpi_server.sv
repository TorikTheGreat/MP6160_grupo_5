`timescale 1ns/1ps

module axi_dpi_server #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4
) (
    input logic aclk,
    input logic aresetn
);

    /*
     * ---------------------------------------------------------
     * Señales AXI4 entre el maestro y la RAM.
     * ---------------------------------------------------------
     */

    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awvalid;
    logic                  awready;

    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                    wlast;
    logic                    wvalid;
    logic                    wready;

    logic [ID_WIDTH-1:0] bid;
    logic [1:0]          bresp;
    logic                bvalid;
    logic                bready;

    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arvalid;
    logic                  arready;

    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic                  rvalid;
    logic                  rready;


    /*
     * ---------------------------------------------------------
     * Maestro AXI.
     * ---------------------------------------------------------
     */

    dpi_axi_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) master (
        .aclk(aclk),
        .aresetn(aresetn),

        .m_axi_awid(awid),
        .m_axi_awaddr(awaddr),
        .m_axi_awlen(awlen),
        .m_axi_awsize(awsize),
        .m_axi_awburst(awburst),
        .m_axi_awvalid(awvalid),
        .m_axi_awready(awready),

        .m_axi_wdata(wdata),
        .m_axi_wstrb(wstrb),
        .m_axi_wlast(wlast),
        .m_axi_wvalid(wvalid),
        .m_axi_wready(wready),

        .m_axi_bid(bid),
        .m_axi_bresp(bresp),
        .m_axi_bvalid(bvalid),
        .m_axi_bready(bready),

        .m_axi_arid(arid),
        .m_axi_araddr(araddr),
        .m_axi_arlen(arlen),
        .m_axi_arsize(arsize),
        .m_axi_arburst(arburst),
        .m_axi_arvalid(arvalid),
        .m_axi_arready(arready),

        .m_axi_rid(rid),
        .m_axi_rdata(rdata),
        .m_axi_rresp(rresp),
        .m_axi_rlast(rlast),
        .m_axi_rvalid(rvalid),
        .m_axi_rready(rready)
    );


    /*
     * ---------------------------------------------------------
     * Memoria AXI4.
     * ---------------------------------------------------------
     */

    axi4_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_BYTES(16 * 1024 * 1024)
    ) ram (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axi_awid(awid),
        .s_axi_awaddr(awaddr),
        .s_axi_awlen(awlen),
        .s_axi_awsize(awsize),
        .s_axi_awburst(awburst),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),

        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),

        .s_axi_bid(bid),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),

        .s_axi_arid(arid),
        .s_axi_araddr(araddr),
        .s_axi_arlen(arlen),
        .s_axi_arsize(arsize),
        .s_axi_arburst(arburst),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),

        .s_axi_rid(rid),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rlast(rlast),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready)
    );


    /*
     * ---------------------------------------------------------
     * Interfaz asíncrona entre DPI y AXI.
     *
     * Estado:
     *   0 = libre
     *   1 = operación en curso
     *   2 = operación terminada
     * ---------------------------------------------------------
     */

    localparam int AXI_IDLE = 0;
    localparam int AXI_BUSY = 1;
    localparam int AXI_DONE = 2;

    localparam int CMD_NONE  = 0;
    localparam int CMD_WRITE = 1;
    localparam int CMD_READ  = 2;

    integer operation_state;
    integer operation_command;
    integer operation_status;

    int unsigned operation_address;
    int unsigned operation_write_data;
    int unsigned operation_read_data;

    event operation_requested;


    /*
     * ---------------------------------------------------------
     * Funciones exportadas por DPI.
     *
     * Todas son de tiempo cero.
     * No contienen @, wait, # ni tareas temporizadas.
     * ---------------------------------------------------------
     */

    export "DPI-C" function sv_axi_request_write;
    export "DPI-C" function sv_axi_request_read;
    export "DPI-C" function sv_axi_get_state;
    export "DPI-C" function sv_axi_get_status;
    export "DPI-C" function sv_axi_get_read_data;
    export "DPI-C" function sv_axi_acknowledge;


    /*
     * Solicita una escritura AXI.
     *
     * Retorno:
     *   0 = solicitud aceptada
     *   1 = servidor ocupado
     */

    function int sv_axi_request_write(
        input int unsigned addr,
        input int unsigned data
    );
        if (operation_state != AXI_IDLE) begin
            sv_axi_request_write = 1;
        end
        else begin
            operation_address    = addr;
            operation_write_data = data;
            operation_read_data  = 0;
            operation_status     = 0;
            operation_command    = CMD_WRITE;
            operation_state      = AXI_BUSY;

            -> operation_requested;

            sv_axi_request_write = 0;
        end
    endfunction


    /*
     * Solicita una lectura AXI.
     *
     * Retorno:
     *   0 = solicitud aceptada
     *   1 = servidor ocupado
     */

    function int sv_axi_request_read(
        input int unsigned addr
    );
        if (operation_state != AXI_IDLE) begin
            sv_axi_request_read = 1;
        end
        else begin
            operation_address    = addr;
            operation_write_data = 0;
            operation_read_data  = 0;
            operation_status     = 0;
            operation_command    = CMD_READ;
            operation_state      = AXI_BUSY;

            -> operation_requested;

            sv_axi_request_read = 0;
        end
    endfunction


    /*
     * Devuelve el estado actual:
     *
     *   0 = libre
     *   1 = ocupada
     *   2 = terminada
     */

    function int sv_axi_get_state();
        sv_axi_get_state = operation_state;
    endfunction


    /*
     * Devuelve el código de resultado de la última operación:
     *
     *   0 = operación AXI correcta
     *   1 = error AXI
     */

    function int sv_axi_get_status();
        sv_axi_get_status = operation_status;
    endfunction


    /*
     * Devuelve el dato obtenido por la última lectura.
     */

    function int unsigned sv_axi_get_read_data();
        sv_axi_get_read_data = operation_read_data;
    endfunction


    /*
     * Libera el servidor después de que C++ haya leído
     * el resultado de una operación terminada.
     *
     * Retorno:
     *   0 = resultado reconocido
     *   1 = todavía no existe una operación terminada
     */

    function int sv_axi_acknowledge();
        if (operation_state == AXI_DONE) begin
            operation_state   = AXI_IDLE;
            operation_command = CMD_NONE;
            operation_status  = 0;

            sv_axi_acknowledge = 0;
        end
        else begin
            sv_axi_acknowledge = 1;
        end
    endfunction


    /*
     * ---------------------------------------------------------
     * Inicialización.
     * ---------------------------------------------------------
     */

    initial begin
        operation_state      = AXI_IDLE;
        operation_command    = CMD_NONE;
        operation_status     = 0;
        operation_address    = 0;
        operation_write_data = 0;
        operation_read_data  = 0;
    end


    /*
     * ---------------------------------------------------------
     * Proceso que ejecuta las operaciones AXI.
     *
     * Este proceso pertenece completamente a SystemVerilog.
     * Por eso puede esperar flancos de reloj mediante las
     * tareas del módulo dpi_axi_master.
     * ---------------------------------------------------------
     */

    initial begin : axi_operation_worker
        integer local_status;
        int unsigned local_read_data;

        forever begin
            @operation_requested;

            local_status    = 0;
            local_read_data = 0;

            /*
             * Esperar por seguridad a que el reset termine.
             */
            if (!aresetn) begin
                @(posedge aresetn);
            end

            case (operation_command)

                CMD_WRITE: begin
                    master.axi_write_word(
                        operation_address,
                        operation_write_data,
                        local_status
                    );
                end

                CMD_READ: begin
                    master.axi_read_word(
                        operation_address,
                        local_read_data,
                        local_status
                    );

                    operation_read_data = local_read_data;
                end

                default: begin
                    local_status = 1;
                end

            endcase

            operation_status = local_status;
            operation_state  = AXI_DONE;
        end
    end

endmodule