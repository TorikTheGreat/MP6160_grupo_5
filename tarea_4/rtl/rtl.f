# Filelist del DUT, para que B, C y D lo compilen desde SUS flujos.
#
# OJO con las rutas: los nombres de aqui son RELATIVOS a este fichero.
#   Verilator: usa -F (mayuscula), que resuelve relativo al .f
#       verilator --lint-only -F /ruta/a/rtl.f --top-module axi4_ram_slave
#   Icarus:    NO tiene equivalente a -F. O entras en el directorio,
#              o pasas el directorio con -y:
#       iverilog -g2012 -y /ruta/a/rtl -s axi4_ram_slave -o sim.vvp tu_tb.v
axi4_ram_slave.v
