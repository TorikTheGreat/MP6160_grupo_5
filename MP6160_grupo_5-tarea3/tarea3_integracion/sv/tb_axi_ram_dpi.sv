`timescale 1ns/1ps

module tb_axi_ram_dpi;

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int ID_WIDTH   = 4;
    localparam int MEM_BYTES  = 1024 * 1024;

    logic aclk;
    logic aresetn;

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

    int unsigned dato_leido;
    int estado;

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;
    end

    initial begin
        aresetn = 1'b0;
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
    end

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

    axi4_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_BYTES(MEM_BYTES)
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

    initial begin
        wait(aresetn == 1'b1);
        repeat (2) @(posedge aclk);

        $display("");
        $display("======================================");
        $display(" PRUEBA MAESTRO AXI + RAM AXI4");
        $display("======================================");

        master.axi_write_word(
            32'h00001000,
            32'h12345678,
            estado
        );

        if (estado != 0) begin
            $display("[SV] AXI_WRITE_FAIL");
            $finish;
        end

        master.axi_read_word(
            32'h00001000,
            dato_leido,
            estado
        );

        if (estado != 0) begin
            $display("[SV] AXI_READ_FAIL");
        end
        else if (dato_leido == 32'h12345678) begin
            $display("[SV] AXI_RAM_PASS: dato=0x%08h", dato_leido);
        end
        else begin
            $display(
                "[SV] AXI_RAM_FAIL: esperado=0x12345678 recibido=0x%08h",
                dato_leido
            );
        end

        $finish;
    end

endmodule