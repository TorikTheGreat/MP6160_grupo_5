## Declaración de uso de Inteligencia Artificial — Rol C (Marcelo)

El diseño de la verificación (secuencias dirigidas/aleatorias, scoreboard,
cobertura funcional, tests UVM, golden 1080p y comparador bit-exact) es
trabajo propio. Se usó Claude (Anthropic, vía Cowork) como apoyo puntual,
principalmente para **depuración**:

- Depuración de la toolchain de simulación (Vivado XSim: errores de
  compilación/elaboración y un bug de parseo de argumentos en `xsim` desde
  `cmd.exe`).
- Depuración de un cuelgue de simulación en ráfagas AXI4 largas (causado por
  el andamio `dummy_slave.sv`) y de un bug en el monitor stub (no llamaba
  `ap.write()`) — ambos corregidos sin modificar archivos que no son míos.
- Depuración y automatización de la corrida de simulación (scripts
  `run_uvm_sim.bat` y `.tcl` asociados).
- Mejora de redacción del reporte de verificación y de esta declaración.