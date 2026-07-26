#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>

#include "../include/tlm_axi_adapter.h"

#include <cstdint>
#include <cstring>
#include <iostream>

class TestInitiator : public sc_core::sc_module
{
public:
    tlm_utils::simple_initiator_socket<TestInitiator> initiator_socket;

    SC_HAS_PROCESS(TestInitiator);

    explicit TestInitiator(sc_core::sc_module_name name)
        : sc_core::sc_module(name),
          initiator_socket("initiator_socket")
    {
        SC_THREAD(run_test);
    }

private:
    void run_test()
    {
        sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

        uint32_t write_data = 0x12345678;

        tlm::tlm_generic_payload write_trans;
        write_trans.set_command(tlm::TLM_WRITE_COMMAND);
        write_trans.set_address(0x1000);
        write_trans.set_data_ptr(
            reinterpret_cast<unsigned char*>(&write_data)
        );
        write_trans.set_data_length(sizeof(write_data));
        write_trans.set_streaming_width(sizeof(write_data));
        write_trans.set_byte_enable_ptr(nullptr);
        write_trans.set_dmi_allowed(false);
        write_trans.set_response_status(
            tlm::TLM_INCOMPLETE_RESPONSE
        );

        initiator_socket->b_transport(write_trans, delay);

        if (write_trans.is_response_error()) {
            std::cerr << "[TEST] Error en escritura TLM" << std::endl;
            sc_core::sc_stop();
            return;
        }

        uint32_t read_data = 0xFFFFFFFF;

        tlm::tlm_generic_payload read_trans;
        read_trans.set_command(tlm::TLM_READ_COMMAND);
        read_trans.set_address(0x1000);
        read_trans.set_data_ptr(
            reinterpret_cast<unsigned char*>(&read_data)
        );
        read_trans.set_data_length(sizeof(read_data));
        read_trans.set_streaming_width(sizeof(read_data));
        read_trans.set_byte_enable_ptr(nullptr);
        read_trans.set_dmi_allowed(false);
        read_trans.set_response_status(
            tlm::TLM_INCOMPLETE_RESPONSE
        );

        initiator_socket->b_transport(read_trans, delay);

        if (read_trans.is_response_error()) {
            std::cerr << "[TEST] Error en lectura TLM" << std::endl;
            sc_core::sc_stop();
            return;
        }

        std::cout
            << "[TEST] dato leido = 0x"
            << std::hex << read_data
            << std::dec
            << std::endl;

        sc_core::sc_stop();
    }
};

int sc_main(int argc, char* argv[])
{
    TestInitiator initiator("initiator");
    TlmAxiAdapter adapter("adapter");

    initiator.initiator_socket.bind(adapter.target_socket);

    sc_core::sc_start();

    return 0;
}