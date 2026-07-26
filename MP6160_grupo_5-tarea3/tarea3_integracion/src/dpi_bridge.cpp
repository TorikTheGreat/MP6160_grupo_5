#include <iostream>

extern "C" int dpi_sumar(int a, int b)
{
    int resultado = a + b;

    std::cout
        << "[C++ DPI] a = " << a
        << ", b = " << b
        << ", resultado = " << resultado
        << std::endl;

    return resultado;
}