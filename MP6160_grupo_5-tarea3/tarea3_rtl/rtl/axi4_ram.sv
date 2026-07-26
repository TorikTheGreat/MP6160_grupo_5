`timescale 1ns/1ps

module axi4_ram #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int MEM_BYTES  = 64 * 1024 * 1024
) (
    input  logic                  aclk,
    input  logic                  aresetn,

    input  logic [ID_WIDTH-1:0]   s_axi_awid,
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [7:0]            s_axi_awlen,
    input  logic [2:0]            s_axi_awsize,
    input  logic [1:0]            s_axi_awburst,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                  s_axi_wlast,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,

    output logic [ID_WIDTH-1:0]   s_axi_bid,
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,

    input  logic [ID_WIDTH-1:0]   s_axi_arid,
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [7:0]            s_axi_arlen,
    input  logic [2:0]            s_axi_arsize,
    input  logic [1:0]            s_axi_arburst,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    output logic [ID_WIDTH-1:0]   s_axi_rid,
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rlast,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    logic [7:0] mem [0:MEM_BYTES-1];

    logic                  wr_active;
    logic [ID_WIDTH-1:0]   wr_id;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [7:0]            wr_len;
    logic [7:0]            wr_beat;
    logic [2:0]            wr_size;
    logic [1:0]            wr_burst;
    logic                  wr_error;

    logic                  rd_active;
    logic [ID_WIDTH-1:0]   rd_id;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [7:0]            rd_len;
    logic [7:0]            rd_beat;
    logic [2:0]            rd_size;
    logic [1:0]            rd_burst;
    logic                  rd_error;

    function automatic logic [ADDR_WIDTH-1:0] next_addr(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        if (burst == 2'b01)
            next_addr = addr + (1 << size); // INCR
        else
            next_addr = addr;               // FIXED; WRAP no soportado
    endfunction

    function automatic logic access_error(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [2:0] size,
        input logic [1:0] burst
    );
        longint unsigned bytes;
        begin
            bytes = 1 << size;
            access_error = (bytes > STRB_WIDTH) ||
                           (addr + bytes > MEM_BYTES) ||
                           (burst == 2'b10);
        end
    endfunction

    assign s_axi_awready = aresetn && !wr_active && !s_axi_bvalid;
    assign s_axi_wready  = aresetn && wr_active && !s_axi_bvalid;
    assign s_axi_arready = aresetn && !rd_active && !s_axi_rvalid;

    integer i;
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            wr_active   <= 1'b0;
            wr_id       <= '0;
            wr_addr     <= '0;
            wr_len      <= '0;
            wr_beat     <= '0;
            wr_size     <= '0;
            wr_burst    <= '0;
            wr_error    <= 1'b0;
            s_axi_bid   <= '0;
            s_axi_bresp <= RESP_OKAY;
            s_axi_bvalid<= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                wr_active <= 1'b1;
                wr_id     <= s_axi_awid;
                wr_addr   <= s_axi_awaddr;
                wr_len    <= s_axi_awlen;
                wr_beat   <= 0;
                wr_size   <= s_axi_awsize;
                wr_burst  <= s_axi_awburst;
                wr_error  <= access_error(s_axi_awaddr, s_axi_awsize, s_axi_awburst);
            end

            if (s_axi_wvalid && s_axi_wready) begin
                for (i = 0; i < STRB_WIDTH; i++) begin
                    if (s_axi_wstrb[i] && (wr_addr + i < MEM_BYTES))
                        mem[wr_addr + i] <= s_axi_wdata[8*i +: 8];
                end

                wr_error <= wr_error || access_error(wr_addr, wr_size, wr_burst) ||
                            (s_axi_wlast != (wr_beat == wr_len));

                if (s_axi_wlast || (wr_beat == wr_len)) begin
                    wr_active    <= 1'b0;
                    s_axi_bid    <= wr_id;
                    s_axi_bresp  <= (wr_error || access_error(wr_addr, wr_size, wr_burst) ||
                                     (s_axi_wlast != (wr_beat == wr_len))) ? RESP_SLVERR : RESP_OKAY;
                    s_axi_bvalid <= 1'b1;
                end else begin
                    wr_beat <= wr_beat + 1'b1;
                    wr_addr <= next_addr(wr_addr, wr_size, wr_burst);
                end
            end

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            rd_active   <= 1'b0;
            rd_id       <= '0;
            rd_addr     <= '0;
            rd_len      <= '0;
            rd_beat     <= '0;
            rd_size     <= '0;
            rd_burst    <= '0;
            rd_error    <= 1'b0;
            s_axi_rid   <= '0;
            s_axi_rdata <= '0;
            s_axi_rresp <= RESP_OKAY;
            s_axi_rlast <= 1'b0;
            s_axi_rvalid<= 1'b0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                rd_active <= 1'b1;
                rd_id     <= s_axi_arid;
                rd_addr   <= s_axi_araddr;
                rd_len    <= s_axi_arlen;
                rd_beat   <= 0;
                rd_size   <= s_axi_arsize;
                rd_burst  <= s_axi_arburst;
                rd_error  <= access_error(s_axi_araddr, s_axi_arsize, s_axi_arburst);
            end

            if (rd_active && !s_axi_rvalid) begin
                s_axi_rid   <= rd_id;
                s_axi_rdata <= '0;
                for (i = 0; i < STRB_WIDTH; i++) begin
                    if (rd_addr + i < MEM_BYTES)
                        s_axi_rdata[8*i +: 8] <= mem[rd_addr + i];
                end
                s_axi_rresp  <= (rd_error || access_error(rd_addr, rd_size, rd_burst)) ? RESP_SLVERR : RESP_OKAY;
                s_axi_rlast  <= (rd_beat == rd_len);
                s_axi_rvalid <= 1'b1;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                if (s_axi_rlast) begin
                    rd_active <= 1'b0;
                end else begin
                    rd_beat <= rd_beat + 1'b1;
                    rd_addr <= next_addr(rd_addr, rd_size, rd_burst);
                end
            end
        end
    end
endmodule
