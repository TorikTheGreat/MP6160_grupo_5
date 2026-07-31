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

    // Lógica rvalid (muy simplificada, asume que solo mandan single-beats el andamio)
    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            axi.rvalid <= 1'b0;
            axi.rresp  <= 2'b00; // OKAY
            axi.rlast  <= 1'b0;
        end else begin
            if (axi.arvalid && axi.arready) begin
                axi.rvalid <= 1'b1;
                axi.rid    <= axi.arid;
                axi.rdata  <= 64'hDEADBEEFCAFEBA00; // Basura amigable
                axi.rlast  <= 1'b1; // Dummy no soporta ráfagas largas
            end else if (axi.rvalid && axi.rready) begin
                axi.rvalid <= 1'b0;
                axi.rlast  <= 1'b0;
            end
        end
    end
endmodule
