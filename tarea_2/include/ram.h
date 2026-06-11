#ifndef RAM_H
#define RAM_H

#include <systemc.h>
#include <tlm.h>
#include <tlm_utils/simple_target_socket.h>
#include <fstream>
#include <string>

class RAM : public sc_module {
public:
    // ... (anteriormente definido)
    tlm_utils::simple_target_socket<RAM> socket;

    SC_HAS_PROCESS(RAM);

    RAM(sc_module_name name, uint64_t size = 64 * 1024 * 1024)
        : sc_module(name), socket("socket"), m_size(size) {
        
        m_data = new uint8_t[m_size];
        memset(m_data, 0, m_size);

        socket.register_b_transport(this, &RAM::b_transport);
        
        cout << "RAM: " << name << " creada con " << m_size / (1024*1024) << " MB" << endl;
    }

    ~RAM() {
        delete[] m_data;
    }

    // Método para cargar un archivo directamente a una dirección de memoria
    bool load_from_file(const std::string& filename, uint64_t address) {
        std::ifstream file(filename, std::ios::binary | std::ios::ate);
        if (!file.is_open()) {
            SC_REPORT_WARNING("RAM", ("No se pudo abrir el archivo: " + filename).c_str());
            return false;
        }

        std::streamsize size = file.tellg();
        if (address + size > m_size) {
            SC_REPORT_WARNING("RAM", "Archivo demasiado grande para la dirección especificada");
            return false;
        }

        file.seekg(0, std::ios::beg);
        if (file.read(reinterpret_cast<char*>(&m_data[address]), size)) {
            cout << "RAM: Cargados " << size << " bytes desde " << filename << " en 0x" << hex << address << dec << endl;
            return true;
        }
        return false;
    }

    // Método para guardar una región de memoria a un archivo
    bool save_to_file(const std::string& filename, uint64_t address, uint64_t size) {
        if (address + size > m_size) {
            SC_REPORT_WARNING("RAM", "Intento de guardar fuera de los límites de la memoria");
            return false;
        }

        std::ofstream file(filename, std::ios::binary);
        if (!file.is_open()) {
            SC_REPORT_WARNING("RAM", ("No se pudo crear el archivo: " + filename).c_str());
            return false;
        }

        file.write(reinterpret_cast<const char*>(&m_data[address]), size);
        cout << "RAM: Guardados " << size << " bytes en " << filename << " desde 0x" << hex << address << dec << endl;
        return true;
    }

    // Implementación del transporte bloqueante
    virtual void b_transport(tlm::tlm_generic_payload& trans, sc_time& delay) {
        tlm::tlm_command cmd = trans.get_command();
        uint64_t adr = trans.get_address();
        unsigned char* ptr = trans.get_data_ptr();
        unsigned int len = trans.get_data_length();
        unsigned char* byt = trans.get_byte_enable_ptr();
        unsigned int wid = trans.get_streaming_width();

        // Verificación de límites
        if (adr + len > m_size || byt != 0 || wid < len) {
            trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
            return;
        }

        // Ejecución de la operación
        if (cmd == tlm::TLM_READ_COMMAND) {
            memcpy(ptr, &m_data[adr], len);
        } else if (cmd == tlm::TLM_WRITE_COMMAND) {
            memcpy(&m_data[adr], ptr, len);
        }

        // Simulación de retardo (ej. 10ns por acceso)
        delay += sc_time(10, SC_NS);
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
    }

private:
    uint8_t* m_data;
    uint64_t m_size;
};

#endif
