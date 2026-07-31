# Rol A — Sistema SystemC y puente DPI

La base es el sistema desarrollado en la Tarea 2: un CPU carga una imagen RAW RGB, configura el acelerador, el acelerador convierte la imagen a escala de grises y el CPU guarda el resultado.

Para esta tarea se conservó ese flujo y se sustituyó la RAM original de SystemC por `RamRtlProxy`. El proxy publica las operaciones de memoria para que el rol D pueda convertirlas en transferencias AXI4 hacia la RAM RTL del rol E.

El lado SystemC ya fue probado de forma independiente. La cosimulación real con XSim no se marca como terminada porque todavía faltan los archivos de integración del rol D.

## Qué se desarrolló

* Se agregó un `Makefile` para reconstruir y ejecutar el sistema desde las fuentes.
* Se conservó la RAM SystemC original para repetir la corrida baseline.
* El sondeo del CPU pasó de 10 ns a 1 µs, manteniendo el límite de 500 000 consultas.
* El acelerador ahora reporta errores TLM en lugar de detenerse con `sc_assert`.
* Se creó `RamRtlProxy` con un socket para el CPU y otro para el acelerador.
* Las transferencias grandes se dividen en bloques de hasta 4096 bytes sin cruzar una frontera de 4 KB.
* Se implementaron `dpi_poll_request`, `dpi_fetch`, `dpi_store` y `dpi_complete`.
* Se creó el wrapper que permite a SystemVerilog crear, avanzar, consultar y destruir el sistema SystemC.
* Se verificó la prueba 8×8 y el procesamiento completo de la imagen 1920×1080.

## Organización

```text
systemc/
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
├── docs/
├── images/
├── logs/
├── reference/
├── sapo_perro.rgb
├── sapo_perro_gray.raw
├── Makefile
├── setup.sh
└── activate.sh
```

`ram.h` se mantiene solamente para la baseline. La integración nueva utiliza `ram_rtl_proxy.h` y `ram_rtl_proxy.cpp`.

## Preparación del entorno

El script instala SystemC 2.3.4 dentro de `systemc/tools/`:

```bash
cd systemc
chmod +x setup.sh
./setup.sh
source activate.sh
```

En cada terminal nueva se debe ejecutar:

```bash
cd systemc
source activate.sh
```

Para comprobar la instalación:

```bash
cd examples/sanity
make clean
make run
cd ../..
```

## Pruebas disponibles

**Baseline con la RAM SystemC:**

```bash
make baseline
```

**Prueba local del proxy:**

```bash
make proxy-test
```

**Flujo completo con proxy y memoria simulada:**

```bash
make proxy-e2e
```

**Prueba portable de las cuatro funciones DPI:**

```bash
make dpi-test
```

**Comprobación de compilación del wrapper:**

```bash
make wrapper-check
```

**Flujo completo mediante el wrapper:**

```bash
make wrapper-test
```

Para ejecutar todas las pruebas portables:

```bash
make test-all
```

Desde la raíz del repositorio también puede usarse:

```bash
./scripts/run_systemc_tests.sh
```

## Resultados obtenidos

Las evidencias guardadas en `logs/` muestran:

* Baseline SystemC: prueba 8×8 correcta y salida 1080p generada.
* Prueba del proxy: 13 solicitudes atendidas de 13 esperadas.
* Puente DPI portable: 13 solicitudes atendidas y propagación correcta de `SLVERR`.
* End-to-end con memoria simulada: 4056 solicitudes atendidas.
* Wrapper portable: 4251 iteraciones, 4056 solicitudes DPI y resultado final `PASS`.
* La salida es bit-exact respecto a la referencia de la Tarea 2.

Tamaños esperados:

```text
sapo_perro.rgb       6 220 800 bytes
sapo_perro_gray.raw  2 073 600 bytes
```

Hashes SHA-256 verificados:

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

## Flujo del sistema

```text
PersistentStorage
      ↓
     CPU ─────────────→ registros del acelerador
      ↓
RamRtlProxy ←──────── Accelerator
      ↓
 funciones DPI
      ↓
BFM AXI4 del rol D
      ↓
RAM RTL del rol E
```

En las pruebas portables, el BFM y la RAM RTL se reemplazan por una memoria C++ para verificar el lado del rol A sin depender todavía de XSim.

## Mapa de memoria

```text
RAM válida: 0x00000000–0x03FFFFFF
Acelerador: 0x40000000
```

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

## Contrato DPI

Funciones de control:

```text
systemc_create()
systemc_service()
systemc_is_finished()
systemc_passed()
systemc_destroy()
```

Funciones de memoria:

```text
dpi_poll_request()
dpi_fetch()
dpi_store()
dpi_complete()
```

Convenciones:

* `is_write = 1`: SystemC desea escribir en la RAM RTL. El BFM obtiene los bytes mediante `dpi_fetch`.
* `is_write = 0`: SystemC desea leer desde la RAM RTL. El BFM devuelve los bytes mediante `dpi_store`.
* `axi_response = 0`: respuesta `OKAY`.
* `axi_response = 2`: respuesta `SLVERR`.
* Solo existe una solicitud activa a la vez.
* Cada solicitud DPI tiene un máximo de 4096 bytes.
* AXI4 usa datos de 64 bits, por lo que una solicitud de 4096 bytes requiere dos ráfagas de hasta 2048 bytes.
* Ninguna ráfaga AXI debe cruzar una frontera de 4 KB.

Para XSim, `systemc_dpi_bridge.cpp` debe compilarse con:

```text
-DSYSTEMC_DPI_XSIM
```

La firma exacta de los arreglos DPI debe validarse contra las declaraciones `import "DPI-C"` y el encabezado generado por la herramienta durante la integración del rol D. Las pruebas portables no sustituyen esa validación de ABI.

## Relación con los otros roles

**Rol B:** ya existe `tb/interfaces/axi4_if.sv`, con `DATA_W=64`, `ADDR_W=32`, `ID_W=4` y modports `master` y `slave`. Este archivo pertenece al rol B y no se duplica dentro de `systemc/`.

**Rol E:** aporta la RAM AXI4 Full y su wrapper para `axi4_if.slave`. Tampoco se copia dentro de esta carpeta.

**Rol C:** aporta el golden independiente y el comparador bit-exact. La salida de este rol debe entregarse como `sapo_perro_gray.raw`.

## Archivos pendientes del rol D

Para cerrar la cosimulación faltan archivos equivalentes a:

```text
tb/cosim/axi4_dpi_bfm.sv
tb/cosim/tb_systemc_cosim.sv
scripts/run_cosim.sh
```

El BFM debe consumir las cuatro funciones DPI, dividir las solicitudes en ráfagas AXI4, conectarse a `tb/interfaces/axi4_if.sv` y llamar `dpi_complete` cuando finalice cada solicitud completa.

El top debe incluir el reloj de 100 MHz, reset activo bajo durante al menos 16 ciclos, la interfaz de B, el BFM de D y la RAM de E.

El script debe compilar el C++ con `xsc`, el SystemVerilog y RTL con `xvlog`, elaborar con `xelab` y ejecutar con `xsim`.

Hasta recibir y probar esos archivos no se declara completada la corrida real de XSim.

## Archivos generados que no se suben

La carpeta incluye un `.gitignore` para excluir:

```text
build/
tools/
xsim.dir/
*.o
*.so
*.wdb
*.jou
input.rgb
output.gray
```

## Declaración de uso de inteligencia artificial

Se utilizó IA como apoyo para revisar código, organizar pruebas, localizar errores de compilación y mejorar la documentación. Las decisiones aplicadas se comprobaron mediante las pruebas locales y la comparación bit-exact de la salida.

Prompts representativos:

* “Verifica el código de la Tarea 2.
* “Revisa los errores de compilación del proxy y del wrapper DPI.”
* “Organiza el README del rol A para integrarlo en la estructura del repositorio.”

Clase de uso:

* Consulta de conceptos de SystemC, TLM, DPI y AXI4.
* Revisión y depuración de código.
* Preparación de pruebas.
* Organización del repositorio y mejora de redacción.
