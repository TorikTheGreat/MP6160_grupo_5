\# Reporte de verificación — Rol C (MP6160, EC4/Tarea 4)



\## 1. Golden 1080p + comparador bit-exact



Programa independiente (`verification\_rolC/`), sin tocar el testbench de Rol A:



\- `golden\_generate.cpp`: genera el golden 1080p con la fórmula BT.709, de forma

&#x20; independiente al `rgb\_to\_gray()` usado por el sistema.

\- `compare\_bitexact.cpp`: comparador bit-exact contra la salida del sistema.

\- `run\_verification.sh`: encadena ambos pasos y emite PASS/FAIL.



\*\*Resultado:\*\* PASS localmente contra `sapo\_perro\_gray.raw` (salida de la EC2,

rama `tarea\_3\_final`). PR abierto: `tarea4\_rolC\_final` → `tarea-4-rol-b`.



\## 2. Entorno de tests UVM (secuencias, scoreboard, cobertura, tests)



Archivos (`tb/uvm/`): `axi4\_rolC\_sequences.sv` (directed + random),

`axi4\_scoreboard.sv` (memoria shadow, chequeo OKAY/SLVERR),

`axi4\_coverage.sv` (is\_write, len, región de dirección, resp, borde 4KB),

`axi4\_rolC\_tests.sv` (`axi4\_directed\_test`, `axi4\_random\_test`).



Flujo de simulación: Vivado XSim 2024.1, `-L uvm` (UVM 1.2). Ver

`run\_uvm\_sim.bat` / `run\_directed.tcl` / `run\_random.tcl`.



\### Hallazgos y correcciones durante la verificación (no en el alcance de C, documentados por norma del plan de trabajo — "objeción cuanto antes")



\- \*\*Monitor de Rol B nunca llamaba `ap.write()`\*\*: el scoreboard no recibía

&#x20; transacciones. Corregido sin tocar el archivo de B, vía

&#x20; `axi4\_monitor\_fixed.sv` + `set\_type\_override\_by\_type` en los tests de C.

\- \*\*`dummy\_slave.sv` (andamio de esclavo, dueño B) no soportaba ráfagas

&#x20; largas\*\*: levantaba `rlast` en el primer beat sin importar `arlen`, lo que

&#x20; colgaba la simulación indefinidamente en la ráfaga de 256 beats (caso

&#x20; "borde 4KB"). Corregido agregando un contador de beats que respeta

&#x20; `arlen` antes de levantar `rlast`.



\### Resultados de las corridas (contra `dummy\_slave`, sin RTL real de Rol E)



| Test | Transacciones | Tiempo simulado | Cobertura funcional | UVM\_ERROR | UVM\_FATAL |

|---|---|---|---|---|---|

| `axi4\_directed\_test` | secuencia dirigida (incl. ráfaga máx. 256 beats, borde 4KB, caso SLVERR fuera de rango) | 6165 ns | 60.00% | 275 | 0 |

| `axi4\_random\_test` | 40 transacciones aleatorias | 17755 ns | 42.50% | 600 | 0 |



\*\*Ambos tests terminan limpio (`$finish`), sin cuelgues ni crashes.\*\*



Los `UVM\_ERROR` son \*\*mismatches de datos esperados\*\*: `dummy\_slave` es un

andamio sin memoria real (devuelve siempre `0xDEADBEEFCAFEBA00`), no el DUT

final. Que el scoreboard detecte y reporte estos mismatches correctamente

\*\*es la prueba de que el monitor y el scoreboard funcionan\*\* — no un fallo

del entorno de verificación.



\### Pendiente (fuera del alcance de C)



Cuando el RTL real de Rol E (`axi4\_ram\_slave\_axi4if.sv`) esté integrado en

`tb\_top\_rolC.sv` en lugar de `dummy\_slave`, se debe re-correr esta misma

suite. Ahí sí se espera `beats\_pass` > 0 y, en el caso ideal, cero

`UVM\_ERROR` en lecturas que corresponden a datos previamente escritos por la

secuencia dirigida.



\## 3. Cómo reproducir



tb\\uvm\\run\_uvm\_sim.bat



Genera `directed\_test.log` y `random\_test.log` en la raíz del repo con la

salida completa de cada corrida (incluye reporte UVM y resumen de cobertura).

