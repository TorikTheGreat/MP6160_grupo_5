#!/bin/bash
# Script de compilacion y ejecucion UVM para Linux

cd tb/uvm

source /home/Vivado/2024.1/settings64.sh

echo "Configurando entorno Vivado para UVM..."

# Compilar el paquete UVM (interno de Vivado)
xvlog -sv -L uvm \
  ../interfaces/axi4_if.sv \
  axi4_item.sv \
  axi4_rolC_sequences.sv \
  axi4_monitor.sv \
  axi4_monitor_fixed.sv \
  axi4_driver.sv \
  axi4_sequencer.sv \
  axi4_agent.sv \
  axi4_coverage.sv \
  axi4_scoreboard.sv \
  axi4_env.sv \
  basic_test.sv \
  axi4_rolC_tests.sv \
  dummy_slave.sv \
  ../tb_top_rolC.sv

echo "Elaborando el snapshot UVM..."
xelab tb_top_rolC -L uvm -timescale 1ns/1ps -snapshot rolC_snapshot

echo "========================================="
xsim rolC_snapshot -R -testplusarg {UVM_TESTNAME=axi4_directed_test} -log directed_test.log

echo "========================================="
xsim rolC_snapshot -R -testplusarg {UVM_TESTNAME=axi4_random_test} -log random_test.log

cd ../..
echo "FIN DE LA PRUEBA"
