#!/bin/bash
# Script de co-simulacion usando Vivado XSim (para reemplazar Verilator 5)

cd rtl

source /home/Vivado/2024.1/settings64.sh

echo "Configurando entorno Vivado para Co-Simulacion..."

# Compilar SystemC wrapper
echo "Compilando SystemC wrapper..."
g++ -fPIC -shared -I/home/Vivado/2024.1/data/xsim/include \
    ../tb/bridge_dpi/dpi/systemc_dpi_vl_stub.cpp \
    -o libdpi.so

echo "Compilando RTL y Testbench..."
xvlog -sv \
    axi4_ram_slave.v \
    axi4_ram_slave_axi4if.sv \
    ../tb/interfaces/axi4_if.sv \
    tb/systemc_dpi_pkg.sv \
    tb/tb_systemc_dpi_top.sv

echo "Elaborando el snapshot de Co-Simulacion..."
xelab tb -sv_lib libdpi -timescale 1ns/1ps -snapshot cosim_snapshot

echo "========================================="
echo "CORRIENDO CO-SIMULACION"
echo "========================================="
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6
xsim cosim_snapshot -R -testplusarg SYSTEMC_INPUT_RGB=../systemc/sapo_perro.rgb -testplusarg SYSTEMC_OUTPUT_GRAY=../sapo_perro_cosim.raw

cd ..
echo "FIN DE LA CO-SIMULACION"
