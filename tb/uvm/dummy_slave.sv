module dummy_slave (
    axi4_if.slave axi
);
    // Señales ready siempre listas para no trabar las peticiones
    assign axi.awready = 1'b1;
    assign axi.wready  = 1'b1;
    assign axi.arready = 1'b1;

    // Lógica bvalid (muy simplificada para el andamio)
    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            axi.bvalid <= 1'b0;
            axi.bresp  <= 2'b00; // OKAY
        end else begin
            if (axi.wvalid && axi.wready && axi.wlast) begin
                axi.bvalid <= 1'b1;
                axi.bid    <= axi.awid;
            end else if (axi.bvalid && axi.bready) begin
                axi.bvalid <= 1'b0;
            end
        end
    end

   // Lógica rvalid con soporte de rafagas (cuenta beats usando arlen)
    logic [7:0] beat_cnt;
    logic [7:0] beat_total;
    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            axi.rvalid <= 1'b0;
            axi.rresp  <= 2'b00; // OKAY
            axi.rlast  <= 1'b0;
            beat_cnt   <= 8'd0;
            beat_total <= 8'd0;
        end else begin
            if (axi.arvalid && axi.arready && !axi.rvalid) begin
                axi.rvalid <= 1'b1;
                axi.rid    <= axi.arid;
                axi.rdata  <= 64'hDEADBEEFCAFEBA00; // Basura amigable
                beat_total <= axi.arlen;
                beat_cnt   <= 8'd0;
                axi.rlast  <= (axi.arlen == 8'd0);
            end else if (axi.rvalid && axi.rready) begin
                if (axi.rlast) begin
                    axi.rvalid <= 1'b0;
                    axi.rlast  <= 1'b0;
                end else begin
                    beat_cnt  <= beat_cnt + 8'd1;
                    axi.rlast <= (beat_cnt + 8'd1 == beat_total);
                    axi.rdata <= 64'hDEADBEEFCAFEBA00;
                end
            end
        end
    end
endmodule
