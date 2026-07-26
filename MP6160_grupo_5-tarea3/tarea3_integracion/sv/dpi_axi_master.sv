`timescale 1ns/1ps

module dpi_axi_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4
) (
    input logic aclk,
    input logic aresetn,

    output logic [ID_WIDTH-1:0]   m_axi_awid,
    output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]            m_axi_awlen,
    output logic [2:0]            m_axi_awsize,
    output logic [1:0]            m_axi_awburst,
    output logic                  m_axi_awvalid,
    input  logic                  m_axi_awready,

    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,

    input  logic [ID_WIDTH-1:0] m_axi_bid,
    input  logic [1:0]          m_axi_bresp,
    input  logic                m_axi_bvalid,
    output logic                m_axi_bready,

    output logic [ID_WIDTH-1:0]   m_axi_arid,
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]            m_axi_arlen,
    output logic [2:0]            m_axi_arsize,
    output logic [1:0]            m_axi_arburst,
    output logic                  m_axi_arvalid,
    input  logic                  m_axi_arready,

    input  logic [ID_WIDTH-1:0]   m_axi_rid,
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                  m_axi_rlast,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready
);

    initial begin
        m_axi_awid    = '0;
        m_axi_awaddr  = '0;
        m_axi_awlen   = 8'd0;
        m_axi_awsize  = 3'b010;
        m_axi_awburst = 2'b01;
        m_axi_awvalid = 1'b0;

        m_axi_wdata   = '0;
        m_axi_wstrb   = '0;
        m_axi_wlast   = 1'b0;
        m_axi_wvalid  = 1'b0;

        m_axi_bready  = 1'b0;

        m_axi_arid    = '0;
        m_axi_araddr  = '0;
        m_axi_arlen   = 8'd0;
        m_axi_arsize  = 3'b010;
        m_axi_arburst = 2'b01;
        m_axi_arvalid = 1'b0;

        m_axi_rready  = 1'b0;
    end

    task automatic axi_write_word(
        input  int unsigned addr,
        input  int unsigned data,
        output int status
    );
        begin
            status = 0;

            @(posedge aclk);

            m_axi_awid    <= '0;
            m_axi_awaddr  <= addr;
            m_axi_awlen   <= 8'd0;
            m_axi_awsize  <= 3'b010;
            m_axi_awburst <= 2'b01;
            m_axi_awvalid <= 1'b1;

            do begin
                @(posedge aclk);
            end while (!m_axi_awready);

            m_axi_awvalid <= 1'b0;

            m_axi_wdata  <= data;
            m_axi_wstrb  <= {DATA_WIDTH/8{1'b1}};
            m_axi_wlast  <= 1'b1;
            m_axi_wvalid <= 1'b1;

            do begin
                @(posedge aclk);
            end while (!m_axi_wready);

            m_axi_wvalid <= 1'b0;
            m_axi_wlast  <= 1'b0;
            m_axi_wstrb  <= '0;

            m_axi_bready <= 1'b1;

            do begin
                @(posedge aclk);
            end while (!m_axi_bvalid);

            if (m_axi_bresp != 2'b00)
                status = 1;

            @(posedge aclk);
            m_axi_bready <= 1'b0;
        end
    endtask

    task automatic axi_read_word(
        input  int unsigned addr,
        output int unsigned data,
        output int status
    );
        begin
            data   = 0;
            status = 0;

            @(posedge aclk);

            m_axi_arid    <= '0;
            m_axi_araddr  <= addr;
            m_axi_arlen   <= 8'd0;
            m_axi_arsize  <= 3'b010;
            m_axi_arburst <= 2'b01;
            m_axi_arvalid <= 1'b1;

            do begin
                @(posedge aclk);
            end while (!m_axi_arready);

            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b1;

            do begin
                @(posedge aclk);
            end while (!m_axi_rvalid);

            data = m_axi_rdata;

            if ((m_axi_rresp != 2'b00) || !m_axi_rlast)
                status = 1;

            @(posedge aclk);
            m_axi_rready <= 1'b0;
        end
    endtask

endmodule