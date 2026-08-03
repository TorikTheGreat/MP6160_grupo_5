#ifndef AP_INT_H_W3_SHIM
#define AP_INT_H_W3_SHIM
// =====================================================================
//  Shim mínimo de ap_int<W> SOLO para verificación fuera de Vitis
// ---------------------------------------------------------------------
//  He tenido algo de problemas para instalar vitis. Resulta que Vitis HLS 
//  trae <ap_int.h> y lo necesito. Este header reemplaza ap_int<W> con un 
//  entero nativo que hace wrap de complemento a 2 a W bits, replicando la 
//  semántica de ap_int<W> para las unicas operaciones que usa el núcleo 
//  del hardware: + , - , >> (aritmético) y salida a std::ostream.
//
//  Para esas operaciones con W<=16 (valores dentro de int) el resultado
//  es BIT-IDENTICO a ap_int<W> de Vitis, así que no deberían haber problemas
//  de compatibilidad con los demás. El wrap ocurre al asignar/construir
//  (igual que ap_int, que trunca al ancho del destino). No es una
//  reimplementación completa de ap_int (sin bit-slicing, rangos, etc.);
//  si el núcleo llegara a usar esas features, cambiaría a los headers
//  open-source de AMD (HLS_arbitrary_Precision_Types, MIT) mientras logro
//  instalar vitis.
//
//  Este archivo no se sintetiza: es andamiaje de test. El código de HLS
//  queda intacto; se selecciona este header con -I .../Golden/compat.
// =====================================================================

template <int W>
class ap_int {
    static_assert(W >= 1 && W <= 63, "shim ap_int: soporta 1..63 bits");
    long long v;

    // Trunca x a W bits y lo re-signa (complemento a 2).
    static long long wrap(long long x) {
        const unsigned long long mask = (1ULL << W) - 1ULL;
        unsigned long long u = static_cast<unsigned long long>(x) & mask;
        if (u & (1ULL << (W - 1))) u |= ~mask;   // extiende el bit de signo
        return static_cast<long long>(u);
    }

public:
    ap_int() : v(0) {}
    // Implícito a propósito: permite  pixel_t x = 100;  y  d >> 1  -> ap_int.
    ap_int(long long x) : v(wrap(x)) {}

    ap_int &operator=(long long x) { v = wrap(x); return *this; }

    // Conversión implícita a entero: deja que +,-,>> y std::cout operen en
    // aritmética nativa; el resultado se re-wrappea al asignarse a un ap_int.
    operator long long() const { return v; }
};

#endif  // AP_INT_H_W3_SHIM
