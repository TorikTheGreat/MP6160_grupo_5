#ifndef CPU_H
#define CPU_H

#include <iomanip>
#include <systemc.h>
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <cstring>
#include <string>

class RAM;  // Forward declaration

class CPU : public sc_module {

public:
    // TLM initiator sockets
    tlm_utils::simple_initiator_socket<CPU> socket_ram;  // Para acceder a RAM
    tlm_utils::simple_initiator_socket<CPU> socket_acc;  // Para acceder a acelerador

    CPU(sc_module_name name, RAM* ram_ptr = nullptr)
        : sc_module(name), socket_ram("socket_ram"), socket_acc("socket_acc"), m_ram(ram_ptr) {
        
        cout << "CPU: " << name << " creada con sockets para RAM y Acelerador" << endl;
    }

    ~CPU() {
    }

    // Lee dato de 32 bits desde un registro del acelerador
    uint32_t read_accelerator_register(uint64_t address) {
        tlm::tlm_generic_payload trans;
        sc_time delay = sc_time(0, SC_NS);
        uint32_t data = 0;
        
        trans.set_command(tlm::TLM_READ_COMMAND);
        trans.set_address(address);
        trans.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
        trans.set_data_length(4);
        trans.set_streaming_width(4);
        trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        
        socket_acc->b_transport(trans, delay);
        
        return data;
    }

    // Escribe dato de 32 bits a un registro del acelerador
    void write_accelerator_register(uint64_t address, uint32_t data) {
        tlm::tlm_generic_payload trans;
        sc_time delay = sc_time(0, SC_NS);
        
        trans.set_command(tlm::TLM_WRITE_COMMAND);
        trans.set_address(address);
        trans.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
        trans.set_data_length(4);
        trans.set_streaming_width(4);
        trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        
        socket_acc->b_transport(trans, delay);
    }

    // Configura y lanza un job en el acelerador
    // Parámetros:
    //   - acc_base_address: dirección base de los registros del acelerador
    //   - input_addr: dirección base de la imagen de entrada (RGB)
    //   - output_addr: dirección base de la imagen de salida (Grayscale)
    //   - pixel_count: cantidad de píxeles a procesar
    bool run_accelerator_job(uint64_t acc_base_address, 
                             uint32_t input_addr, uint32_t output_addr, 
                             uint32_t pixel_count) {
        
        // Escribir configuración de registros
        write_accelerator_register(acc_base_address + 0x04, input_addr);
        write_accelerator_register(acc_base_address + 0x08, output_addr);
        write_accelerator_register(acc_base_address + 0x0C, pixel_count);
        
        // Iniciar procesamiento
        write_accelerator_register(acc_base_address + 0x00, 0x1);  // CONTROL: bit 0 = START
        
        return true;
    }

    // Espera a que el acelerador indique que ha terminado (polling)
    bool wait_for_accelerator_done(uint64_t acc_base_address, int timeout_cycles = 10000) {
        int timeout = 0;
        while ((read_accelerator_register(acc_base_address + 0x00) & 0x1) == 0 && timeout < timeout_cycles) {
            wait(10, SC_NS);
            timeout++;
        }
        if (timeout >= timeout_cycles) {
            cout << "CPU: Timeout esperando a que el acelerador termine\n";
        } else {
            cout << "CPU: Acelerador ha terminado en " << timeout << " ciclos\n";
        }
        return (timeout < timeout_cycles);
    }


    // Carga una imagen desde archivo a RAM
    bool load_image_to_ram(const std::string& filename, uint64_t address) {
        if (!m_ram) return false;
        return m_ram->load_from_file(filename, address);
    }

    // Guarda una imagen desde RAM a archivo
    bool save_image_from_ram(const std::string& filename, uint64_t address, uint64_t size) {
        if (!m_ram) return false;
        return m_ram->save_to_file(filename, address, size);
    }

private:
    RAM* m_ram;  // Puntero a módulo RAM para backdoor file I/O

};


#endif