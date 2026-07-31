# Puerta DPI minima (rol D)

Esta carpeta implementa la validacion del punto 1: una prueba minima de ida y vuelta entre SystemVerilog y C++ usando DPI, con consumo real de tiempo de simulacion.

## Que valida

- SV llama una funcion importada en C++: `dpi_roundtrip`.
- El testbench avanza tiempo con un task local (`wait_cycles`) alrededor de la llamada DPI.
- C++ consulta un valor de SV (`dpi_get_cycle_count`) y retorna un resultado verificable.

Si esto pasa, no solo se valido el enlace de symbols: se valido tambien la ejecucion bidireccional y el avance de tiempo de simulacion durante la corrida.

## Como correr

Desde `tarea_4/rtl`:

```sh
make dpi-gate
```

## Criterio de exito

La corrida debe terminar con:

```text
=== PASS : etapa 12 / puerta DPI ...
```

y sin timeout del watchdog.

---

## Co-simulacion Verilator (puntos 2/3/4/6/7)

La integracion del puente DPI + BFM + DUT real en Verilator se ejecuta desde
`tarea_4/rtl` con:

```sh
make cosim-vl
```

El top de cosim es `tb/tb_systemc_dpi_top.sv` y usa:

- `tb/systemc_dpi_pkg.sv`: contrato DPI del lado SV.
- `tb/axi4_bfm_master.sv`: consumo de solicitudes DPI y trafico AXI.
- `tb/tb_setup_axi4if.vh`: wrapper `axi4_ram_slave_axi4if` + `axi4_if`.

La implementacion C++ para esta ruta (sin XSim) es `../bridge_dpi/dpi/systemc_dpi_vl_stub.cpp`.

### Secuencia del puente

Para cada solicitud:

```text
systemc_service() por ciclo
	↓
dpi_poll_request()
	↓
si is_write=1: dpi_fetch() -> rafagas AW/W/B -> dpi_complete()
si is_write=0: rafagas AR/R -> dpi_store() -> dpi_complete()
```

### Troceo de 4096 B

Con `DATA_W=64`, el BFM divide cada bloque de 4096 bytes en 2 rafagas de
2048 bytes (256 beats, `AWLEN=255`), respetando alineacion de 8 bytes y borde
de 4 KB.

### Metricas

Para medir tiempo y memoria sobre DUT real:

```sh
make cosim-vl-metric
```
