#include <systemc.h>
#include <vector>
#include <iostream>
#include "../../include/persistent_storage.h"

int sc_main(int argc, char* argv[])
{
    PersistentStorage storage("storage");

    std::vector<uint8_t> data;

    bool ok_read = storage.read_file("input.raw", data);

    if (!ok_read) {
        std::cout << "ERROR: no se pudo leer input.raw" << std::endl;
        return 1;
    }

    bool ok_write = storage.write_file("output.raw", data);

    if (!ok_write) {
        std::cout << "ERROR: no se pudo escribir output.raw" << std::endl;
        return 1;
    }

    std::cout << "TEST OK: PersistentStorage leyo y escribio correctamente" << std::endl;

    return 0;
}
