# Tarea 4 — Rol A: lado SystemC e integración end-to-end

La base utilizada fue el sistema SystemC de la Tarea 2, formado por CPU, acelerador RGB a escala de grises, almacenamiento persistente y RAM. A partir de esa base se sustituyó la RAM SystemC por un proxy que publica las transferencias para que una RAM RTL pueda atenderlas mediante DPI y AXI4.

El lado C++ ya fue probado de forma independiente. La integración final con XSim queda pendiente de los archivos que debe añadir el rol D.

## Qué se desarrolló

- Se creó un `Makefile` para reconstruir y ejecutar el sistema desde las fuentes.
- Se conservó una corrida baseline con la RAM SystemC original.
- El sondeo del CPU cambió de 10 ns a 1 µs, manteniendo el límite de 500 000 consultas.
- El acelerador dejó de usar `sc_assert` para los accesos a RAM y ahora reporta errores TLM de forma controlada.
- Se implementó `RamRtlProxy` con los mismos dos sockets de la RAM original: uno para el CPU y otro para el acelerador.
- Las transferencias grandes se dividen en bloques de hasta 4096 bytes sin cruzar límites de 4 KB.
- Se implementaron las cuatro funciones DPI de memoria: `dpi_poll_request`, `dpi_fetch`, `dpi_store` y `dpi_complete`.
- Se creó un wrapper para construir el sistema completo, avanzar el kernel de SystemC y devolver el resultado a SystemVerilog.
- Se ejecutaron pruebas sintéticas, pruebas del proxy, pruebas del puente DPI y el procesamiento completo de la imagen 1080p.

## Organización

```text
Tarea4_Rol_A/
├── include/
│   ├── accelerator.h
│   ├── cpu.h
│   ├── mock_axi_memory.h
│   ├── persistent_storage.h
│   ├── ram.h
│   ├── ram_rtl_proxy.h
│   ├── rgb_to_gray.h
│   └── systemc_dpi_bridge.h
├── src/
│   ├── ram_rtl_proxy.cpp
│   ├── systemc_dpi_bridge.cpp
│   └── systemc_dpi_wrapper.cpp
├── tests/
│   ├── tb_cpu_ram_accel.cpp
│   ├── tb_cpu_ram_accel_proxy_mock.cpp
│   ├── tb_ram_rtl_proxy_mock.cpp
│   ├── tb_systemc_dpi_bridge.cpp
│   ├── tb_systemc_dpi_wrapper_portable.cpp
│   └── persistent_storage/
├── examples/sanity/
├── logs/
├── reference/
├── docs/
├── images/
├── sapo_perro.rgb
├── sapo_perro_gray.raw
├── Makefile
├── setup.sh
└── activate.sh
```

`ram.h` se conserva para reproducir la baseline. La integración nueva utiliza `ram_rtl_proxy.h` y `ram_rtl_proxy.cpp`.

## Preparación del entorno

El proyecto instala SystemC 2.3.4 de manera local, dentro de `tools/`.

```bash
chmod +x setup.sh
./setup.sh
source activate.sh
```

En cada terminal nueva debe ejecutarse:

```bash
source activate.sh
```

Para confirmar que SystemC y TLM funcionan:

```bash
cd examples/sanity
make clean
make run
cd ../..
```

La prueba debe indicar que el dato escrito y leído coincide.

## Pruebas disponibles

### Baseline con la RAM SystemC

```bash
make baseline
```

Ejecuta primero la imagen sintética 8×8 y después la imagen RAW RGB de 1920×1080.

### Prueba local de `RamRtlProxy`

```bash
make proxy-test
```

Comprueba lecturas, escrituras, división de 4104 bytes, límite de 4 KB y propagación de un error equivalente a `SLVERR`.

### Flujo completo con proxy y memoria simulada

```bash
make proxy-e2e
```

Ejecuta CPU, acelerador, almacenamiento y proxy. La RAM RTL se reemplaza temporalmente por `MockAxiMemory` para validar el lado SystemC sin depender de SystemVerilog.

### Prueba portable del puente DPI

```bash
make dpi-test
```

Prueba directamente:

```text
dpi_poll_request()
dpi_fetch()
dpi_store()
dpi_complete()
```

### Comprobación del wrapper

```bash
make wrapper-check
```

### Flujo completo mediante el wrapper

```bash
make wrapper-test
```

Esta es la prueba más cercana a la cosimulación final. Un programa C++ simula el ciclo que después realizará el top SystemVerilog.

Para ejecutar todo:

```bash
make test-all
```

## Resultados obtenidos

Las pruebas guardadas en `logs/` dieron los siguientes resultados:

- Baseline SystemC: imagen sintética correcta y salida 1080p generada.
- Proxy local: 13 solicitudes atendidas de 13 esperadas.
- Puente DPI portable: 13 solicitudes atendidas y propagación de `SLVERR` correcta.
- Flujo end-to-end con memoria mock: 4056 solicitudes atendidas.
- Wrapper portable: 4251 iteraciones de servicio, 4056 solicitudes DPI y resultado final `PASS`.
- La salida generada es bit-exact respecto a la referencia de la Tarea 2.

Tamaños esperados:

```text
sapo_perro.rgb       6 220 800 bytes
sapo_perro_gray.raw  2 073 600 bytes
```

Hashes SHA-256 comprobados:

```text
a050fe93559639518d338529e02ffed0ed243492dd38ba0ce7e50acfcd70213a  sapo_perro.rgb
fa58ebf02d235f9a4ad68d791b7d525c43c0966d5a99eaaea8f6292072416011  sapo_perro_gray.raw
```

La comparación puede repetirse con:

```bash
cmp -s sapo_perro_gray.raw reference/sapo_perro_gray_tarea2.raw \
&& echo "BIT-EXACT: PASS" \
|| echo "BIT-EXACT: FAIL"
```

## Flujo implementado

```text
PersistentStorage
      ↓
     CPU ─────────────→ registros del acelerador
      ↓
RamRtlProxy ←──────── Accelerator
      ↓
 funciones DPI
      ↓
BFM AXI4 y RAM RTL
```

En las pruebas portables, el último bloque se reemplaza por una memoria C++ para comprobar el comportamiento del rol A antes de la integración real.

## Mapa de memoria

```text
RAM válida: 0x00000000–0x03FFFFFF
Acelerador: 0x40000000
```

Regiones utilizadas:

```text
Prueba 8×8
  SRC_TEST = 0x00000000
  DST_TEST = 0x02000000

Imagen 1080p
  SRC_REAL = 0x00010000
  DST_REAL = 0x01000000
```

Registros del acelerador:

```text
0x00 CONTROL
0x04 SRC
0x08 DST
0x0C NUM_PIXELS
```

## Contrato DPI para la integración

Funciones de control del sistema:

```text
systemc_create()
systemc_service()
systemc_is_finished()
systemc_passed()
systemc_destroy()
```

Funciones para las transferencias de memoria:

```text
dpi_poll_request()
dpi_fetch()
dpi_store()
dpi_complete()
```

Convenciones:

- `is_write = 1`: SystemC desea escribir en la RAM RTL. El BFM obtiene los datos con `dpi_fetch`.
- `is_write = 0`: SystemC desea leer desde la RAM RTL. El BFM devuelve los datos con `dpi_store`.
- `axi_response = 0`: `OKAY`.
- `axi_response = 2`: `SLVERR`.
- Solo existe una solicitud activa a la vez.
- Cada solicitud DPI mide como máximo 4096 bytes.
- Una solicitud de 4096 bytes debe convertirse en dos ráfagas AXI4 de hasta 2048 bytes, porque el bus es de 64 bits y AXI4 admite un máximo de 256 beats por ráfaga.
- Ninguna ráfaga debe cruzar un límite de 4 KB.

## Archivos pendientes del rol D

El trabajo del rol A queda listo para integrarse, pero la cosimulación final todavía necesita que el rol D añada sus archivos de SystemVerilog y automatización. Los nombres pueden variar, pero deben cubrir estas funciones:

```text
sv/axi4_bfm_master.sv
```

BFM que consulta `dpi_poll_request`, obtiene o entrega los datos y genera las ráfagas AXI4.

```text
sv/tb_systemc_dpi_top.sv
```

Top de cosimulación con reloj de 100 MHz, reset, DUT, BFM, llamadas a `systemc_service` y comprobación de `systemc_passed`.

```text
scripts/run_cosim.sh
```

Script que compile C++ con `xsc`, compile SystemVerilog/RTL con `xvlog`, elabore con `xelab` y ejecute con `xsim`.

Si D separa las declaraciones DPI o la lógica de ráfagas en archivos adicionales, también deben agregarse junto con esos tres componentes. Hasta recibirlos no es posible declarar finalizada la corrida real con XSim y la RAM RTL.

## Declaración de uso de inteligencia artificial

Se utilizó IA como apoyo durante el desarrollo. Su uso se concentró en revisión de código, organización de pruebas, depuración de errores de compilación y mejora de la redacción. Las decisiones de diseño se comprobaron ejecutando las pruebas localmente y revisando los resultados generados.

Prompts representativos utilizados:

- “Verifica el código de la Tarea 2 y determina qué partes se utilizarán para el rol A.”
- “Verificacion de errores de compilación del proxy y del wrapper DPI.”
- “Organiza el README para mejor redacción.”

Clase de utilización:

- Consulta de conceptos de SystemC, TLM, DPI y AXI4.
- Revisión y depuración de código.
- Preparación de pruebas y organización del repositorio.
- Mejora de redacción y documentación.
