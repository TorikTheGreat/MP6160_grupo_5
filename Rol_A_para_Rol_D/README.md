# Interfaz del rol A para integración con el rol D

Este paquete contiene el lado **SystemC/C++** necesario para que el rol D complete el puente **DPI + BFM AXI4 + XSim** de la Tarea 4.

El sistema ejecuta el flujo completo:

```text
PersistentStorage
      ↓
     CPU
      ↓ TLM
RamRtlProxy
      ↓ DPI
BFM del rol D
      ↓ AXI4 Full
RAM RTL del rol E
      ↑
Acelerador SystemC RGB→gris
```

El rol A ya validó el mismo flujo con una memoria portable en C++:

- Prueba sintética 8×8: `PASS`.
- Imagen RAW RGB 1920×1080: `PASS`.
- Solicitudes DPI atendidas: `4056`.
- Salida RAW: `2 073 600` bytes.
- Comparación bit-exact contra la referencia: `PASS`.

La integración real con XSim, el BFM y el DUT corresponde al rol D.

---

## Contenido del paquete

```text
Rol_A_para_Rol_D/
├── README.md
├── SHA256SUMS
├── include/
│   ├── accelerator.h
│   ├── cpu.h
│   ├── persistent_storage.h
│   ├── ram_rtl_proxy.h
│   ├── rgb_to_gray.h
│   └── systemc_dpi_bridge.h
├── src/
│   ├── ram_rtl_proxy.cpp
│   ├── systemc_dpi_bridge.cpp
│   └── systemc_dpi_wrapper.cpp
├── input/
│   └── sapo_perro.rgb
└── reference/
    └── sapo_perro_gray_tarea2.raw
```

### Archivos principales

- `ram_rtl_proxy.cpp`: sustituye la RAM SystemC, recibe las transacciones TLM y las divide en solicitudes de hasta 4096 bytes.
- `systemc_dpi_bridge.cpp`: implementa las cuatro funciones DPI de transferencia.
- `systemc_dpi_wrapper.cpp`: crea el sistema completo, avanza el kernel SystemC y reporta el resultado.
- `sapo_perro.rgb`: entrada oficial RAW RGB 1080p.
- `sapo_perro_gray_tarea2.raw`: salida de referencia para comprobar el resultado bit-exact.

---

## Responsabilidad del rol D

El rol D debe aportar:

- La interfaz `axi4_if` del rol B.
- El BFM maestro AXI4 de 64 bits.
- El top de cosimulación con reloj y reset.
- El ciclo que llama las funciones DPI.
- La conexión con la RAM RTL del rol E.
- Los scripts de compilación, elaboración y ejecución con XSim.
- La medición del costo de simulación.

No debe modificar el algoritmo RGB→gris ni calcular la imagen directamente en SystemVerilog. Los datos deben pasar por la RAM RTL.

---

# Contrato DPI

## Funciones de control de SystemC

El top SystemVerilog debe importar:

```systemverilog
import "DPI-C" function int  systemc_create();
import "DPI-C" function int  systemc_service();
import "DPI-C" function int  systemc_is_finished();
import "DPI-C" function int  systemc_passed();
import "DPI-C" function void systemc_destroy();
```

### Comportamiento

| Función | Retorno o efecto |
|---|---|
| `systemc_create()` | Crea CPU, acelerador, almacenamiento y proxy. Retorna `1` si tuvo éxito. |
| `systemc_service()` | Avanza el kernel SystemC exactamente `10 ns`. Retorna `1` si tuvo éxito. |
| `systemc_is_finished()` | Retorna `1` cuando el flujo end-to-end terminó o ocurrió un error. |
| `systemc_passed()` | Retorna `1` solamente si el sistema terminó con `PASS`. |
| `systemc_destroy()` | Libera el sistema y desconecta el proxy. |

`systemc_create()` debe llamarse una sola vez después del reset. `systemc_destroy()` debe llamarse al terminar.

---

## Funciones de transferencia de memoria

Importación recomendada:

```systemverilog
import "DPI-C" function int dpi_poll_request(
    output longint address,
    output int     length,
    output int     is_write
);

import "DPI-C" function void dpi_fetch(
    input  longint address,
    input  int     length,
    output byte    data[]
);

import "DPI-C" function void dpi_store(
    input longint address,
    input int     length,
    input byte    data[]
);

import "DPI-C" function void dpi_complete(
    input int axi_response
);
```

El lado SystemVerilog puede declarar un búfer fijo y pasarlo a las funciones con arreglo abierto:

```systemverilog
byte dpi_data [0:4095];
```

La implementación C++ usa `svOpenArrayHandle`, por eso los argumentos formales de `dpi_fetch` y `dpi_store` deben declararse como arreglos abiertos `data[]`. El búfer real sí debe contener 4096 posiciones.

## Significado de las operaciones

### `dpi_poll_request`

Debe consultarse cuando el BFM se encuentre libre.

- Retorna `1`: existe una solicitud pendiente.
- Retorna `0`: no existe trabajo disponible.
- `address`: dirección inicial en RAM.
- `length`: cantidad total de bytes de la solicitud, entre 1 y 4096.
- `is_write = 1`: SystemC quiere **escribir** en la RAM RTL.
- `is_write = 0`: SystemC quiere **leer** desde la RAM RTL.

Solo existe una solicitud activa a la vez. No se debe solicitar otra antes de llamar `dpi_complete()`.

### Escritura: `is_write = 1`

Secuencia obligatoria:

```text
dpi_poll_request()
        ↓
dpi_fetch(address, length, dpi_data)
        ↓
Una o más ráfagas AXI de escritura
        ↓
Esperar respuesta B
        ↓
dpi_complete(respuesta)
```

`dpi_fetch()` copia hacia `dpi_data` los bytes que el CPU o el acelerador desea escribir.

### Lectura: `is_write = 0`

Secuencia obligatoria:

```text
dpi_poll_request()
        ↓
Una o más ráfagas AXI de lectura
        ↓
Guardar todos los bytes en dpi_data
        ↓
dpi_store(address, length, dpi_data)
        ↓
dpi_complete(respuesta)
```

`dpi_store()` debe llamarse después de recibir la solicitud completa desde el DUT.

## Códigos de respuesta

| Respuesta AXI | Valor entregado a `dpi_complete()` |
|---|---:|
| `OKAY` | `0` |
| `SLVERR` | `2` |

Cualquier valor diferente de cero se propaga al lado SystemC como error TLM. Para el alcance actual deben utilizarse `0` y `2`.

---

# Conversión de cada solicitud DPI a AXI4

El contrato AXI acordado es:

```text
DATA_W = 64 bits
ADDR_W = 32 bits
ID_W   = 4 bits
ID     = 0
Reloj  = 100 MHz
Reset  = activo bajo, mínimo 16 ciclos
BURST  = INCR
SIZE   = 3  (8 bytes por beat)
LEN    = 1 a 256 beats
```

Una solicitud DPI puede tener hasta 4096 bytes, pero una ráfaga AXI4 de 64 bits admite como máximo:

```text
256 beats × 8 bytes = 2048 bytes
```

Por eso el BFM debe dividir una solicitud de 4096 bytes en dos ráfagas de 2048 bytes como máximo.

## Cálculo recomendado por subráfaga

```text
remaining       = length - offset
current_address = address + offset
bytes_to_4k     = 4096 - (current_address & 12'hFFF)
burst_bytes     = min(remaining, 2048, bytes_to_4k)
beats           = burst_bytes / 8
axlen           = beats - 1
axsize          = 3
axburst         = INCR
```

Las transferencias del flujo actual están alineadas a 8 bytes y sus longitudes son múltiplos de 8. Aun así, el BFM debe validar estas condiciones antes de iniciar AXI.

El `RamRtlProxy` ya evita que una solicitud DPI cruce un límite de 4 KB. El BFM debe conservar esa regla al dividirla en subráfagas.

## Escrituras

- Obtener el bloque completo una sola vez mediante `dpi_fetch()`.
- Enviar los bytes en orden creciente de dirección.
- Colocar ocho bytes por beat en `WDATA`.
- Usar `WSTRB = '1` para el flujo normal.
- Afirmar `WLAST` únicamente en el último beat de cada subráfaga.
- Esperar `BVALID` y acumular la peor respuesta.
- Llamar `dpi_complete()` una sola vez al terminar toda la solicitud DPI.

## Lecturas

- Ejecutar todas las subráfagas necesarias.
- Guardar los ocho bytes de cada `RDATA` en el búfer DPI, respetando el orden de direcciones.
- Verificar `RLAST` en el último beat de cada subráfaga.
- Acumular la peor respuesta recibida.
- Llamar `dpi_store()` una sola vez cuando el bloque completo esté listo.
- Después llamar `dpi_complete()`.

## Precaución con `byte`

`byte` es un tipo con signo en SystemVerilog. El contenido debe tratarse como bits sin signo al empacar o desempacar `WDATA` y `RDATA`, por ejemplo mediante `$unsigned(dpi_data[i])`.

---

# Organización recomendada del top de cosimulación

El BFM debe ser una máquina de estados que avance un ciclo por flanco. No se recomienda detener el ciclo de servicio SystemC mediante una tarea AXI bloqueante larga.

En cada flanco positivo del reloj:

```text
1. Llamar systemc_service() una vez.
2. Si el BFM está IDLE, llamar dpi_poll_request().
3. Si aparece una solicitud, iniciar o continuar la FSM AXI.
4. Al terminar el bloque completo, llamar dpi_store() si era lectura.
5. Llamar dpi_complete().
6. Consultar systemc_is_finished().
```

Esto es importante porque `systemc_service()` avanza 10 ns por llamada. Con un reloj de 100 MHz debe llamarse exactamente una vez por ciclo para mantener el avance temporal entre SystemVerilog y SystemC.

Pseudocódigo general:

```systemverilog
initial begin
    aplicar_reset_de_16_ciclos();

    if (!systemc_create())
        $fatal(1, "No se pudo crear SystemC");

    while (!systemc_is_finished()) begin
        @(posedge aclk);

        if (!systemc_service())
            $fatal(1, "Error avanzando SystemC");

        // La FSM del BFM se actualiza cada ciclo.
        // Solo se consulta una solicitud nueva cuando está IDLE.
    end

    if (!systemc_passed())
        $fatal(1, "SystemC reportó FAIL");

    systemc_destroy();
    $finish;
end
```

La implementación final puede separar reloj, FSM y control en procesos distintos, pero no debe llamar `systemc_service()` más de una vez por ciclo.

---

# Compilación con Vivado XSim 2024.1

## Preparar el entorno

```bash
source /tools/Xilinx/Vivado/2024.1/settings64.sh

for tool in xsc xvlog xelab xsim; do
    command -v "$tool" >/dev/null || {
        echo "ERROR: no se encontró $tool"
        exit 1
    }
done
```

## Compilar el lado C++

Desde una carpeta de construcción limpia:

```bash
ROL_A=/ruta/Rol_A_para_Rol_D
BUILD=/ruta/build_cosim

rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"

xsc -cppversion 14 \
    --gcc_compile_options "-DSYSTEMC_DPI_XSIM" \
    --gcc_compile_options "-I$ROL_A/include" \
    "$ROL_A/src/ram_rtl_proxy.cpp" \
    "$ROL_A/src/systemc_dpi_bridge.cpp" \
    "$ROL_A/src/systemc_dpi_wrapper.cpp"
```

El macro `SYSTEMC_DPI_XSIM` es obligatorio: activa la versión de `dpi_fetch()` y `dpi_store()` que utiliza `svdpi.h` y `svOpenArrayHandle`.

La salida predeterminada normalmente queda en:

```text
xsim.dir/work/xsc/dpi.so
```

Si `xsc` no encuentra los encabezados de SystemC, agregue la ruta del SystemC compatible mediante otra opción de compilación:

```bash
--gcc_compile_options "-I$SYSTEMC_HOME/include"
```

Si aparecen símbolos de SystemC sin resolver al enlazar, agregue las opciones de biblioteca correspondientes y asegure que `LD_LIBRARY_PATH` contenga la misma instalación:

```bash
--gcc_link_options "-L$SYSTEMC_HOME/lib" \
--gcc_link_options "-lsystemc" \
--gcc_link_options "-pthread"
```

No mezcle objetos compilados con versiones incompatibles de GCC o SystemC. Ejecute `xsc --print_gcc_version` para conocer el compilador interno utilizado por Vivado.

## Compilar SystemVerilog y RTL

Ejemplo general; D debe sustituir las rutas por sus archivos reales:

```bash
xvlog -sv \
    /ruta/rol_B/axi4_if.sv \
    /ruta/rol_E/axi4_ram_slave.v \
    /ruta/rol_E/axi4_ram_slave_axi4if.sv \
    /ruta/rol_D/axi_master_bfm.sv \
    /ruta/rol_D/tb_cosim_top.sv
```

## Elaborar

```bash
SNAPSHOT=tarea4_systemc_axi_cosim

xelab work.tb_cosim_top \
    --sv_lib xsim.dir/work/xsc/dpi \
    --debug typical \
    --timescale 1ns/1ps \
    --snapshot "$SNAPSHOT"
```

## Ejecutar

Las rutas de entrada y salida pueden cambiarse mediante variables de entorno:

```bash
export SYSTEMC_INPUT_RGB="$ROL_A/input/sapo_perro.rgb"
export SYSTEMC_OUTPUT_GRAY="$BUILD/sapo_perro_gray.raw"

xsim "$SNAPSHOT" -runall
```

Sin estas variables, el wrapper busca y genera respectivamente:

```text
sapo_perro.rgb
sapo_perro_gray.raw
```

---

# Primera puerta antes de ejecutar 1080p

Antes de comprometer la corrida completa, verificar:

- `systemc_create()` retorna `1`.
- `systemc_service()` produce una solicitud pendiente.
- `dpi_poll_request()` retorna una dirección, longitud y tipo válidos.
- En escritura, `dpi_fetch()` devuelve los datos esperados.
- El DUT acepta una transacción AXI y responde.
- `dpi_complete()` permite que SystemC continúe.
- En lectura, los datos regresan mediante `dpi_store()`.
- El reloj avanzó durante el intercambio.

Enlazar `dpi.so` sin ejecutar una transferencia no se considera una prueba suficiente.

El wrapper comienza automáticamente con la prueba sintética 8×8. Si esta prueba falla, no se ejecuta la imagen 1080p.

---

# Resultados esperados

Al finalizar correctamente deben aparecer mensajes similares a:

```text
Prueba sintética: PASS (64/64 píxeles correctos)
Imagen 1080p procesada correctamente
RESULTADO SYSTEMC COSIM: PASS
```

Archivos esperados:

| Archivo | Tamaño |
|---|---:|
| `sapo_perro.rgb` | `6 220 800` bytes |
| `sapo_perro_gray.raw` | `2 073 600` bytes |

Hashes de referencia:

```text
a050fe93559639518d338529e02ffed0ed243492dd38ba0ce7e50acfcd70213a  sapo_perro.rgb
fa58ebf02d235f9a4ad68d791b7d525c43c0966d5a99eaaea8f6292072416011  sapo_perro_gray.raw
```

Comparación rápida:

```bash
cmp -s "$BUILD/sapo_perro_gray.raw" \
       "$ROL_A/reference/sapo_perro_gray_tarea2.raw" \
&& echo "BIT-EXACT: PASS" \
|| echo "BIT-EXACT: FAIL"
```

La comparación oficial debe realizarse también con el programa independiente del rol C.

---

# Mapa de memoria utilizado

| Uso | Dirección |
|---|---:|
| Entrada sintética 8×8 | `0x00000000` |
| Salida sintética 8×8 | `0x02000000` |
| Entrada RGB 1080p | `0x00010000` |
| Salida gris 1080p | `0x01000000` |
| Registros del acelerador | `0x40000000` |

Registros del acelerador:

| Offset | Registro |
|---:|---|
| `0x00` | `CTRL`: escribir bit 0 inicia; leer bit 0 entrega `DONE`. |
| `0x04` | Dirección de entrada. |
| `0x08` | Dirección de salida. |
| `0x0C` | Cantidad de píxeles. |

La RAM válida ocupa `0x00000000–0x03FFFFFF`.

---

# Errores comunes

## `dpi_poll_request()` siempre retorna 0

- Verificar que se llamó `systemc_create()`.
- Llamar `systemc_service()` cada ciclo.
- Confirmar que el BFM está libre y no conserva una solicitud anterior activa.

## El sistema se detiene después de la primera solicitud

- Falta llamar `dpi_complete()`.
- En una lectura puede faltar `dpi_store()` antes de completar.
- Revisar que dirección y longitud entregadas a `dpi_fetch()` o `dpi_store()` sean idénticas a las de `dpi_poll_request()`.

## Error al copiar el arreglo DPI

- Declarar los argumentos como arreglos abiertos `data[]`.
- Pasar un arreglo real de 4096 bytes.
- Compilar C++ con `SYSTEMC_DPI_XSIM`.

## Imagen desplazada o con datos incorrectos

- Revisar `AWLEN/ARLEN = beats - 1`.
- Revisar el orden de los bytes dentro de `WDATA` y `RDATA`.
- Revisar `WLAST` y `RLAST`.
- No aplicar extensión de signo a los valores `byte`.
- No cruzar límites de 4 KB.

## Timeout del acelerador

- Confirmar que `systemc_service()` se llama una vez por ciclo.
- Confirmar que todas las solicitudes terminan con `dpi_complete()`.
- Revisar que el DUT responda tanto lecturas como escrituras.

## Error E519 de SystemC

No debe llamarse `wait()` desde una función DPI. En este paquete los `wait()` se ejecutan dentro de procesos SystemC. D no debe añadir llamadas directas a `wait()` en las funciones importadas.

---

# Criterio de cierre de la integración D

La integración puede considerarse completa cuando:

- El top enlaza la biblioteca C++.
- SystemC y el reloj AXI avanzan coordinadamente.
- La prueba sintética termina con 64/64 píxeles correctos.
- La imagen 1080p se procesa usando la RAM RTL real.
- La salida mide 2 073 600 bytes.
- La comparación bit-exact reporta cero diferencias.
- Se conserva un log reproducible de compilación y simulación.
- Se registra el tiempo de ejecución o costo de simulación.
