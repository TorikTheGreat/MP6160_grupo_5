#include "svdpi.h"
#include "Vtb__Dpi.h"

extern "C" int dpi_roundtrip(int token, int wait_cycles) {
    (void)wait_cycles;

    // Leemos un valor de SV para cerrar la vuelta C++ -> SV -> C++ -> SV.
    const int cycle = dpi_get_cycle_count();
    return token + cycle;
}
