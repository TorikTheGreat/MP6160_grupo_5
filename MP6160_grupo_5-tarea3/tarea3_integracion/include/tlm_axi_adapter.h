#ifndef TLM_AXI_ADAPTER_H
#define TLM_AXI_ADAPTER_H

#include <cstdint>
#include <string>

class TlmAxiAdapter
{
public:
    explicit TlmAxiAdapter(
        const std::string& dpi_scope =
            "tb_systemc_dpi_step_launcher.dut"
    );

    bool begin_write_word(std::uint32_t address, std::uint32_t data);
    bool begin_read_word(std::uint32_t address);

    // Consultar una vez por ciclo desde systemc_service().
    void service();

    bool busy() const;
    bool completed() const;
    bool succeeded() const;
    bool is_read_result() const;
    std::uint32_t read_data() const;

    // Libera el resultado consumido y deja el adaptador listo.
    void clear_completion();

private:
    enum class OperationType {
        None,
        Write,
        Read
    };

    std::string dpi_scope_;
    OperationType operation_type_;
    bool pending_;
    bool completed_;
    bool success_;
    std::uint32_t read_data_;

    bool select_dpi_scope() const;
};

#endif
