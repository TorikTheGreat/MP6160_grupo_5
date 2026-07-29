# `tb/` — banco de pruebas de *bring-up*

**Esto NO es el testbench UVM que pide el enunciado.**

Es el banco con el que se desarrolló y verificó el módulo `axi4_ram_slave.v`: doce etapas en Verilog
procedimental, una por concepto del protocolo, más un BFM y cinco *checkers* de invariantes. Está
escrito así porque en la máquina de trabajo no hay ninguna librería UVM disponible (Vivado, que es la
que la trae, no está instalada).

**El testbench UVM/SystemVerilog vive en su propio directorio.**

Los dos atacan el mismo DUT y cumplen funciones distintas:

| | Este banco (`tb/`) | El testbench UVM |
|---|---|---|
| Para qué | demostrar que este módulo funciona | entregable de verificación |
| Cómo se corre | `make regress` desde `tarea_4/rtl/` | ver su propio README |
| Qué necesita | Icarus Verilog 12 + Verilator 5.020 | un simulador con UVM |

Detalle completo en [`../README.md`](../README.md), secciones 7 y 8.
