#ifndef PERSISTENT_STORAGE_H
#define PERSISTENT_STORAGE_H

#include <systemc.h>
#include <fstream>
#include <vector>
#include <string>
#include <cstdint>

class PersistentStorage : public sc_module {
public:

    SC_HAS_PROCESS(PersistentStorage);

    PersistentStorage(sc_module_name name)
        : sc_module(name) {
        cout << "PersistentStorage: " << name << " creado" << endl;
    }

    bool read_file(const std::string& filename, std::vector<uint8_t>& data) {

        std::ifstream file(filename, std::ios::binary | std::ios::ate);

        if (!file.is_open()) {
            SC_REPORT_WARNING(
                "PersistentStorage",
                ("No se pudo abrir el archivo: " + filename).c_str()
            );
            return false;
        }

        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);

        data.resize(size);

        if (!file.read(reinterpret_cast<char*>(data.data()), size)) {
            SC_REPORT_WARNING(
                "PersistentStorage",
                ("No se pudo leer correctamente el archivo: " + filename).c_str()
            );
            return false;
        }

        cout << "PersistentStorage: leidos "
             << size
             << " bytes desde "
             << filename
             << endl;

        return true;
    }

    bool write_file(
        const std::string& filename,
        const std::vector<uint8_t>& data) {

        std::ofstream file(filename, std::ios::binary);

        if (!file.is_open()) {
            SC_REPORT_WARNING(
                "PersistentStorage",
                ("No se pudo crear el archivo: " + filename).c_str()
            );
            return false;
        }

        file.write(
            reinterpret_cast<const char*>(data.data()),
            data.size()
        );

        if (!file.good()) {
            SC_REPORT_WARNING(
                "PersistentStorage",
                ("No se pudo escribir correctamente el archivo: " + filename).c_str()
            );
            return false;
        }

        cout << "PersistentStorage: escritos "
             << data.size()
             << " bytes en "
             << filename
             << endl;

        return true;
    }
};

#endif
