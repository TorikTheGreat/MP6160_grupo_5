# Filelist del DUT + wrapper sobre la interfaz de SystemVerilog.
#
# ESTE FILELIST NO COMPILA SOLO: falta el fichero de la `axi4_if`, que es del
# rol B y no vive aqui. Anadelo tu:
#     verilator --lint-only -F /ruta/a/rtl_if.f tu_axi4_if.sv --top-module ...
#
# Requisitos que tu axi4_if debe cumplir para que el wrapper enganche (ver
# README.md seccion 9): interfaz llamada `axi4_if`, modport llamado
# `slave`, y `aclk`/`aresetn` como miembros de la interfaz.
# Icarus 12 NO soporta puertos de interfaz: este filelist solo sirve con
# Verilator (o con un simulador comercial).
#
# Lo de las rutas relativas del rtl.f aplica igual aqui.
axi4_ram_slave.v
axi4_ram_slave_axi4if.sv
