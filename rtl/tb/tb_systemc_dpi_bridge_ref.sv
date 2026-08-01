`timescale 1ns/1ps

module tb_systemc_dpi_bridge_ref;
    import systemc_dpi_pkg::*;

    byte dpi_data [0:DPI_MAX_BYTES-1];

    task automatic service_one_request;
        longint address;
        int length;
        int is_write;
        int request_found;

        begin
            request_found = dpi_poll_request(
                address,
                length,
                is_write
            );

            if (request_found == 0) begin
                return;
            end

            if (is_write != 0) begin
                dpi_fetch(address, length, dpi_data);
            end else begin
                dpi_store(address, length, dpi_data);
            end

            dpi_complete(DPI_AXI_OKAY);
        end
    endtask

    initial begin
        service_one_request();
        $finish;
    end
endmodule