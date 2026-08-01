package systemc_dpi_pkg;
    timeunit 1ns;
    timeprecision 1ps;

    localparam int DPI_MAX_BYTES = 4096;
    localparam int DPI_AXI_OKAY   = 0;
    localparam int DPI_AXI_SLVERR = 2;

    import "DPI-C" function int dpi_poll_request(
        output longint address,
        output int     length,
        output int     is_write
    );

    import "DPI-C" function void dpi_fetch(
        input  longint address,
        input  int     length,
        output byte    data[]
    );

    import "DPI-C" function void dpi_store(
        input longint address,
        input int     length,
        input byte    data[]
    );

    import "DPI-C" function void dpi_complete(
        input int axi_response
    );

    import "DPI-C" function int  systemc_create();
    import "DPI-C" function int  systemc_service();
    import "DPI-C" function int  systemc_is_finished();
    import "DPI-C" function int  systemc_passed();
    import "DPI-C" function void systemc_destroy();
endpackage