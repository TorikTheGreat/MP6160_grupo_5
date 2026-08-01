//=============================================================================
// axi4_bfm_master.sv -- helpers del puente DPI/SystemC para el top de cosim.
//
// Este fichero se incluye dentro de `module tb;` y reutiliza las senales y los
// checkers que ya aporta tb_setup.vh + axi4_master_bfm.vh.
//
// Su responsabilidad es solo una: tomar una solicitud DPI, trocearla en
// rafagas AXI4 de 64 bits y conducir el bus sin bloquear el loop que llama a
// systemc_service() cada ciclo.
//=============================================================================

    localparam int DPI_BEAT_BYTES = DATA_W / 8;
    localparam int DPI_MAX_BURST_BYTES = 2048;

    byte dpi_data [0:DPI_MAX_BYTES-1];

    longint dpi_req_address;
    int dpi_req_length;
    int dpi_req_is_write;
    bit dpi_request_busy = 1'b0;

    function automatic [DATA_W-1:0] dpi_pack_word(
        input int base_index
    );
        int lane;
        begin
            dpi_pack_word = '0;
            for (lane = 0; lane < DPI_BEAT_BYTES; lane = lane + 1) begin
                dpi_pack_word[8*lane +: 8] =
                    $unsigned(dpi_data[base_index + lane]);
            end
        end
    endfunction

    task automatic dpi_unpack_word(
        input int base_index,
        input [DATA_W-1:0] word
    );
        int lane;
        begin
            for (lane = 0; lane < DPI_BEAT_BYTES; lane = lane + 1) begin
                dpi_data[base_index + lane] = word[8*lane +: 8];
            end
        end
    endtask

    function automatic int dpi_choose_burst_bytes(
        input longint address,
        input int remaining
    );
        int burst_bytes;
        int bytes_to_4k;
        begin
            burst_bytes = remaining;

            if (burst_bytes > DPI_MAX_BURST_BYTES) begin
                burst_bytes = DPI_MAX_BURST_BYTES;
            end

            bytes_to_4k = 4096 - int'(address & 64'hFFF);

            if (burst_bytes > bytes_to_4k) begin
                burst_bytes = bytes_to_4k;
            end

            dpi_choose_burst_bytes = burst_bytes;
        end
    endfunction

    function automatic int dpi_worse_response(
        input int current_resp,
        input int new_resp
    );
        begin
            if (current_resp == DPI_AXI_SLVERR ||
                new_resp == DPI_AXI_SLVERR) begin
                dpi_worse_response = DPI_AXI_SLVERR;
            end else begin
                dpi_worse_response = DPI_AXI_OKAY;
            end
        end
    endfunction

    task automatic dpi_wait_b_response(
        output int axi_response
    );
        begin
            @(posedge aclk);
            while (!(bvalid && bready)) begin
                @(posedge aclk);
            end

            axi_response = (bresp == 2'b00)
                ? DPI_AXI_OKAY
                : DPI_AXI_SLVERR;

            expect_eq(
                {{(64-ID_W){1'b0}}, bid},
                {{(64-ID_W){1'b0}}, awid},
                "bid debe ecoar el awid emitido"
            );
        end
    endtask

    task automatic dpi_write_burst(
        input longint address,
        input int burst_bytes,
        input int offset_bytes,
        output int axi_response
    );
        int beat;
        int beats;
        begin
            beats = burst_bytes / DPI_BEAT_BYTES;
            axi_response = DPI_AXI_OKAY;

            drive_aw(
                address[ADDR_W-1:0],
                8'(beats - 1),
                3'b011,
                2'b01,
                0
            );

            for (beat = 0; beat < beats; beat = beat + 1) begin
                @(negedge aclk);
                wdata  = dpi_pack_word(offset_bytes + beat*DPI_BEAT_BYTES);
                wstrb  = strb_full;
                wlast  = (beat == beats - 1);
                wvalid = 1'b1;
                @(posedge aclk);
                while (!wready) begin
                    @(posedge aclk);
                end
            end

            @(negedge aclk);
            wvalid = 1'b0;
            wlast  = 1'b0;

            dpi_wait_b_response(axi_response);
        end
    endtask

    task automatic dpi_read_burst(
        input longint address,
        input int burst_bytes,
        input int offset_bytes,
        output int axi_response
    );
        int beat;
        int beats;
        begin
            beats = burst_bytes / DPI_BEAT_BYTES;
            axi_response = DPI_AXI_OKAY;

            drive_ar(
                address[ADDR_W-1:0],
                8'(beats - 1),
                3'b011,
                2'b01,
                0
            );

            for (beat = 0; beat < beats; beat = beat + 1) begin
                @(posedge aclk);
                while (!(rvalid && rready)) begin
                    @(posedge aclk);
                end

                dpi_unpack_word(offset_bytes + beat*DPI_BEAT_BYTES, rdata);

                if (rresp != 2'b00) begin
                    axi_response = DPI_AXI_SLVERR;
                end

                if (rlast !== (beat == beats - 1)) begin
                    errors = errors + 1;
                    $display(
                        "  [FAIL] dpi_read_burst: rlast incorrecto (ciclo %0d)",
                        cycle_count
                    );
                end
            end
        end
    endtask

    task automatic dpi_service_request(
        input longint address,
        input int length,
        input int is_write
    );
        int response;
        int burst_bytes;
        int burst_resp;
        int offset;
        begin
            response = DPI_AXI_OKAY;

            if (address[2:0] != 0 || (length & 7) != 0) begin
                dpi_complete(DPI_AXI_SLVERR);
                dpi_request_busy = 1'b0;
                return;
            end

            if (is_write != 0) begin
                dpi_fetch(address, length, dpi_data);

                offset = 0;
                while (offset < length) begin
                    burst_bytes = dpi_choose_burst_bytes(
                        address + offset,
                        length - offset
                    );

                    dpi_write_burst(
                        address + offset,
                        burst_bytes,
                        offset,
                        burst_resp
                    );

                    response = dpi_worse_response(response, burst_resp);
                    offset += burst_bytes;
                end
            end else begin
                offset = 0;
                while (offset < length) begin
                    burst_bytes = dpi_choose_burst_bytes(
                        address + offset,
                        length - offset
                    );

                    dpi_read_burst(
                        address + offset,
                        burst_bytes,
                        offset,
                        burst_resp
                    );

                    response = dpi_worse_response(response, burst_resp);
                    offset += burst_bytes;
                end

                dpi_store(address, length, dpi_data);
            end

            dpi_complete(response);
            dpi_request_busy = 1'b0;
        end
    endtask

    task automatic dpi_try_launch_request;
        int request_found;
        begin
            if (dpi_request_busy) begin
                return;
            end

            request_found = dpi_poll_request(
                dpi_req_address,
                dpi_req_length,
                dpi_req_is_write
            );

            if (request_found != 0) begin
                dpi_request_busy = 1'b1;

                fork
                    dpi_service_request(
                        dpi_req_address,
                        dpi_req_length,
                        dpi_req_is_write
                    );
                join_none
            end
        end
    endtask