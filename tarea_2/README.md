# Tarea 2 (EC2) — Modelo SystemC / TLM 2.0

Modelo a nivel de transacciones de un sistema **CPU + RAM (64 MB) + almacenamiento
persistente + acelerador** de imagen (RGB → escala de grises), descrito en
**SystemC** con comunicación **TLM 2.0**.


La CPU controla el flujo general del sistema:

-Solicita la lectura del archivo de entrada al almacenamiento persistente.
-Transfiere los datos hacia la memoria RAM mediante una transacción TLM.
-Configura los registros del acelerador.
-Inicia el procesamiento.
-Espera la finalización del acelerador mediante polling.
-Lee la imagen procesada desde la memoria RAM.
-Solicita al almacenamiento persistente la escritura del archivo de salida.

Este directorio es **autocontenido**: instala y compila sus propias dependencias
en `tools/`, sin afectar otras tareas ni el proyecto. Cada tarea del curso tiene
su propio entorno aislado.

---

## Requisitos

- **Linux Debian** o **Ubuntu 24.04** (x86_64). En Windows: WSL2 con Ubuntu. En macOS: VM Linux.
- Compilador compatible con C++17.
- Permisos `sudo` (solo para instalar paquetes de sistema con `apt`).
- ~150 MB de disco y conexión a internet la primera vez (se descarga y compila
  SystemC).

En Windows puede utilizarse WSL2 con Ubuntu o una máquina virtual Linux.



## Instalación (una sola vez)

```bash
cd tarea_2
chmod +x setup.sh activate.sh
./setup.sh
```

Esto:
1. Instala con `apt` lo necesario: `build-essential cmake git curl gtkwave`
   (pide tu contraseña `sudo`; omite los que ya estén).
2. Descarga y compila **SystemC 2.3.4** (incluye **TLM 2.0**) en
   `tools/systemc/`. Tarda ~3 min.

Es seguro re-ejecutarlo: los pasos completados se omiten.

La carpeta tools/ contiene las fuentes y la instalación local de SystemC generadas por setup.sh. Este contenido se reconstruye automáticamente y no necesita incluirse en el repositorio.

## Activar el entorno (en cada terminal nueva)

```bash
source activate.sh
```

Define `SYSTEMC_HOME` y `LD_LIBRARY_PATH` para esta tarea y aplica el arreglo de
GTKWave en Ubuntu 24.04. La configuración es **por terminal**; no persiste.

Para comprobar la ruta configurada:

  echo "$SYSTEMC_HOME"

La salida debe apuntar a la instalación local:

  .../tarea_2/tools/systemc

> **Tip:** agrega un alias a tu `~/.bashrc`:
> ```bash
> alias t2='cd <ruta-al-repo>/MP6160_grupo_5/tarea_2 && source activate.sh'
> ```

## Verificar la instalación

```bash
cd examples/sanity
make clean
make run
```

Salida esperada (una transacción TLM de ida y vuelta):

```
TLM round-trip: escrito 0xdeadbeef, leido 0xdeadbeef   [OK]
Tiempo de simulacion tras 2 transacciones: 20 ns
```

Si ves `[OK]`, SystemC y TLM están bien instalados.



## Instalación ImageMagick

ImageMagick para convertir la imagen PNG de entrada a RAW RGB y transformar la salida RAW a PNG.

  sudo apt update
  sudo apt install -y imagemagick

---

## Compilar tu propio módulo

Reutiliza el patrón del Makefile de `examples/sanity/`:

```make
SYSTEMC_HOME ?= $(abspath ../../tools/systemc)
CXXFLAGS = -std=c++17 -I$(SYSTEMC_HOME)/include
LDFLAGS  = -L$(SYSTEMC_HOME)/lib -Wl,-rpath,$(SYSTEMC_HOME)/lib
LDLIBS   = -lsystemc
```

Con `source activate.sh` cargado, `SYSTEMC_HOME` ya está en el entorno y no hace
falta pasarlo a mano.

## Estructura del directorio

```
tarea_2/
  setup.sh                  # instalador del entorno (correr una vez)
  activate.sh               # cargar el entorno (source en cada terminal)
  README.md                 # este archivo
  .gitignore                # ignora tools/ y artefactos

  examples/sanity/          # verificación SystemC + TLM (hello_tlm)

  include/                  # módulos principales y funciones compartidas
    accelerator.h           # acelerador RGB a escala de grises
    cpu.h                   # CPU e interfaces TLM
    persistent_storage.h    # lectura y escritura de archivos binarios
    ram.h                   # memoria RAM simulada de 64 MB
    rgb_to_gray.h           # función de conversión RGB a gris

  tests/                    # pruebas unitarias y de integración
    tb_cpu_ram_accel.cpp    # prueba integrada CPU + RAM + acelerador
    persistent_storage/
      test_persistent_storage.cpp   # prueba individual del almacenamiento
  
  build/                    # ejecutables generados por compilación
  articulo/                 # informe (plantilla IEEE)
  tools/                    # SystemC compilado — NO se commitea (lo regenera setup.sh)
  sapo_perro.png            # imagen original utilizada para la demostración
  sapo_perro_gray.raw       # salida RAW en escala de grises, 1 byte por píxel 
  sapo_perro.rgb            # imagen RAW RGB de entrada, 1920 × 1080 y 3 bytes por píxel 
  sapo_perro_gray.png       # representación PNG de la salida para inspección visual
```

## Mapa de Memoria

El espacio de direcciones del sistema se divide de la siguiente manera. La comunicación se realiza a través de un bus TLM que enruta las transacciones al componente correspondiente según la dirección.

| Rango de Direcciones      | Tamaño | Componente          | Descripción                                          |
|---------------------------|--------|---------------------|------------------------------------------------------|
| `0x0000_0000-0x03FF_FFFF` | 64 MB  | **Memoria RAM**     | Espacio de trabajo principal.                        |
| `↳ 0x0000_0000`           | ~6 MB  | Buffer de Entrada   | Imagen RAW RGB 1080p (1920x1080x3 bytes).            |
| `↳ 0x0200_0000`           | ~2 MB  | Buffer de Salida    | Imagen en escala de grises (1920x1080x1 byte).       |
| `0x4000_0000-0x4000_000F` | 16 B   | **Acelerador Regs** | Registros de control para el acelerador.             |
| `↳ 0x4000_0000`           | 4 B    | `CONTROL`           | Registro de control (e.g., `START=1`, `DONE` flag).  |
| `↳ 0x4000_0004`           | 4 B    | `ADDR_INPUT`        | Dirección base del buffer de entrada en RAM.         |
| `↳ 0x4000_0008`           | 4 B    | `ADDR_OUTPUT`       | Dirección base del buffer de salida en RAM.          |
| `↳ 0x4000_000C`           | 4 B    | `NUM_PIXELS`        | Cantidad de píxeles a procesar.                      |


El **Almacenamiento Persistente** no se encuentra mapeado dentro del espacio de direcciones.

La CPU utiliza el módulo `PersistentStorage` para leer y escribir archivos. La transferencia entre la CPU y la memoria RAM se realiza mediante transacciones TLM.

La implementación utiliza conexiones directas entre sockets TLM. No existe un módulo de bus independiente con decodificación de direcciones.


## Compilación del informe en LaTeX

La carpeta `articulo/` también puede cargarse en un proyecto de Overleaf. Esta incluye la clase IEEEtran.cls y los archivos necesarios para compilar el documento.


### Opción A — TeX Live local (recomendada)

```bash
sudo apt update
sudo apt install -y \
    texlive-latex-base texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-science texlive-publishers latexmk
```

Cubre todo lo que usa el artículo: `IEEEtran` (texlive-publishers), `algorithmic`
(texlive-science), `cite`, `amsmath/amssymb/amsfonts`, `graphicx`, `textcomp`,
`xcolor`. Si en algún momento falta un paquete, `sudo apt install texlive-full`
lo trae todo (~5 GB).

Compilar:

```bash
cd articulo
make          # genera conference_101719.pdf
make watch    # recompila automáticamente al guardar (latexmk -pvc)
make clean    # borra los artefactos de compilación
```

### Opción B — Overleaf (cero instalación)

La carpeta `articulo/` también puede cargarse en un proyecto de Overleaf. Incluye `IEEEtran.cls`,
así que compila sin configurar nada y permite edición simultánea.

> Los artefactos de LaTeX (`.aux`, `.log`, `.pdf` generado, etc.) están en el
> `.gitignore` de `articulo/`: no se commitean, se regeneran con `make`.

---

## Problemas comunes

| Problema | Solución |
|---|---|
| `source activate.sh` dice "SystemC no encontrado" | Aún no corriste `./setup.sh`, o `tools/` se borró. |
| Al compilar: `systemc.h: No such file or directory` | Falta `source activate.sh` en esta terminal (o `SYSTEMC_HOME` mal). |
| Al ejecutar: `libsystemc.so: cannot open shared object file` | Idem: `source activate.sh` define `LD_LIBRARY_PATH`. |
| GTKWave: `__libc_pthread_init ... GLIBC_PRIVATE` | Ejecútalo tras `source activate.sh`; o `unset LD_LIBRARY_PATH; gtkwave archivo.vcd`. |
| `setup.sh` falla en `apt` por `sudo` | Instala a mano: `sudo apt install build-essential cmake git curl gtkwave`. |

## Organización de los módulos

### CPU

El módulo CPU `CPU` se encuentra en:

La `CPU` coordina el flujo general del sistema.

Dispone de dos sockets iniciadores TLM:

tlm_utils::simple_initiator_socket<CPU> socket_ram;
tlm_utils::simple_initiator_socket<CPU> socket_acc;

`socket_ram` se utiliza para leer y escribir datos en la memoria RAM.

`socket_acc` se utiliza para configurar y consultar los registros del acelerador.

Funciones principales de la `CPU` son:

-Solicitar la lectura de archivos;
-Transferir datos hacia RAM mediante TLM;
-Configurar los registros del acelerador;
-Iniciar el procesamiento;
-Esperar la finalización mediante polling;
-Leer los resultados desde RAM;
-Solicitar la escritura del archivo de salida.

### Memoria RAM

Representa el almacenamiento temporal del sistema y tiene una capacidad máxima de 64 MB.

Dispone de sockets target para atender transacciones provenientes de:

-CPU;
-Acelerador.

La RAM valida:

-Dirección solicitada;
-Longitud de los datos;
-Comando de lectura o escritura;
-Límites de memoria;
-Estado de respuesta de la transacción.

### Almacenamiento persistente

Funciones principales son:

bool read_file(
    const std::string& filename,
    std::vector<uint8_t>& data
);
bool write_file(
    const std::string& filename,
    const std::vector<uint8_t>& data
);

Este módulo se encarga de:

-Abrir archivos binarios;
-Leer su contenido;
-Almacenar los datos en un vector;
-Escribir vectores en archivos;
-Reportar errores de entrada o salida.

La comunicación entre `PersistentStorage` y el CPU se realiza mediante llamadas funcionales.

### Acelerador

El `accelerator` recibe:

-Dirección de entrada;
-Dirección de salida;
-Cantidad de píxeles;
-Señal de inicio.

El acelerador funciona como target para las operaciones de configuración realizadas por la CPU y como iniciador TLM para acceder a la RAM.

Su flujo de trabajo es:

-Leer los datos RGB desde la memoria RAM.
-Convertir cada píxel a escala de grises.
-Escribir el resultado en la memoria RAM.
-Indicar que el procesamiento finalizó.

### Conversión RGB a escala de grises

La función de conversión se encuentra en:

include/rgb_to_gray.h

La entrada utiliza tres bytes por píxel:

  R, G, B

La salida utiliza un byte por píxel, con valores entre 0 y 255.

La conversión se basa en la luminancia BT.709:

  Y = 0.2126R + 0.7152G + 0.0722B

La implementación utiliza coeficientes enteros para evitar operaciones innecesarias en punto flotante.

## Arquitectura del sistema

flowchart LR
  PS[Almacenamiento persistente]
  CPU[CPU]
  RAM[64 MB]
  ACC[Acelerador RGB a gris]

┌──────────────────────────────┐
│ Almacenamiento persistente   │
└──────────────────────────────┘           
.              ▲
.              │
.              │                           
.              ▼                           
┌─────────────────────────────┐            
│             CPU             │            
└─────────────────────────────┘            
.       ▲               ▲
.       │               │                  
.       ▼               ▼                  
┌──────────────┐   ┌────────────┐          
│ Memoria RAM  │◄─►│ Acelerador │          
│ 64 MB        │   │ RGB → gris │          
└──────────────┘   └────────────┘          
 
La CPU coordina el funcionamiento general. Primero solicita al almacenamiento persistente la lectura del archivo de entrada y transfiere sus datos a la memoria RAM. Después configura el acelerador mediante transacciones TLM y ordena el inicio del procesamiento.
El acelerador lee los píxeles RGB desde la RAM, calcula su valor en escala de grises y almacena el resultado nuevamente en memoria. Finalmente, la CPU recupera los datos procesados y solicita su escritura en el archivo de salida.

## Conexiones entre módulos

| Módulo iniciador |   Socket iniciador  |    Módulo Destino      | Socket de Destino |                 Función                 |
|------------------|---------------------|------------------------|-------------------|-----------------------------------------|
| CPU              | socket_ram          |          RAM           |     socket_cpu    | Lectura y escritura de datos            |
| CPU              | socket_acc          |       Acelerador       |     cfg_socket    | Configuración y consulta de estado      |
| Acelerador       | mem_socket          |          RAM           |     socket_acc    | Lectura RGB y escritura del resultado   |

La comunicación entre la CPU, la RAM y el acelerador utiliza transacciones TLM 2.0. El acceso al almacenamiento persistente se realiza mediante llamadas funcionales controladas por la CPU.

## Diagrama de secuencia


Almacenamiento        CPU             RAM            Acelerador
 persistente
      │                 │               │                 │
      │◄─ read_file() ──│               │                 │
      │                 │               │                 │
      │── Datos RGB ───►│               │                 │
      │                 │               │                 │
      │                 │── TLM WRITE ─►│                 │
      │                 │◄── TLM OK ────│                 │
      │                 │               │                 │
      │                 │── ADDR_INPUT ──────────────────►│
      │                 │── ADDR_OUTPUT ─────────────────►│
      │                 │── NUM_PIXELS ──────────────────►│
      │                 │── START ───────────────────────►│
      │                 │               │                 │
      │                 │               │◄── TLM READ ────│
      │                 │               │── Datos RGB ───►│
      │                 │               │                 │
      │                 │               │◄── TLM WRITE ───│
      │                 │               │─── TLM OK ─────►│
      │                 │               │                 │
      │                 │── STATUS ──────────────────────►│
      │                 │◄──── DONE ──────────────────────│
      │                 │               │                 │
      │                 │── TLM READ ──►│                 │
      │                 │◄─ Datos gris ─│                 │
      │                 │               │                 │
      │◄─ write_file() ─│               │                 │
      │                 │               │                 │
      │─ Confirmación ─►│               │                 │
      │                 │               │                 │


La secuencia inicia con la lectura del archivo de entrada, continúa con la transferencia y procesamiento de los datos mediante TLM 2.0, y finaliza con la escritura del archivo de salida.



## Comunicación TLM 2.0

La comunicación entre la CPU, la memoria RAM y el acelerador utiliza:

tlm::tlm_generic_payload

Cada transacción incluye:

  -Comando.
  -Dirección.
  -Puntero a los datos.
  -Longitud.
  -Ancho de streaming.
  -Tiempo anotado.
  -Estado de respuesta.

La estructura general de una transacción es:

  tlm::tlm_generic_payload trans;
  sc_time delay = SC_ZERO_TIME;

  trans.set_command(command); 
  trans.set_address(address); 
  trans.set_data_ptr(data); 
  trans.set_data_length(length); 
  trans.set_streaming_width(length); 
  trans.set_byte_enable_ptr(nullptr); 
  trans.set_dmi_allowed(false);
  
  trans.set_response_status(
    
    tlm::TLM_INCOMPLETE_RESPONSE 
  
  );

  socket->b_transport(trans, delay);
  wait(delay);

Después de ejecutar la transacción se comprueba el estado:

  if (trans.is_response_error()) { // Manejo del error }


## Formato de las transacciones

| Origen           |        Destino      |         Comando        |          Contenido        |
|------------------|---------------------|------------------------|---------------------------|
| CPU              |         RAM         |    TLM_WRITE_COMMAND   |     Datos RGB de entrada  |
| CPU              |         RAM         |    TLM_READ_COMMAND    |    Datos grises de salida |
| CPU              |      Acelerador     |    TLM_WRITE_COMMAND   |     Dirección de entrada  |
| CPU              |      Acelerador     |    TLM_WRITE_COMMAND   |     Dirección de salida   |
| CPU              |      Acelerador     |    TLM_WRITE_COMMAND   |     Cantidad de píxeles   |
| CPU              |      Acelerador     |    TLM_WRITE_COMMAND   |       Orden de inicio     |
| CPU              |      Acelerador     |    TLM_READ_COMMAND    |  Estado del procesamiento |
| Acelerador       |         RAM         |    TLM_READ_COMMAND    |          Datos RGB        |
| Acelerador       |         RAM         |    TLM_WRITE_COMMAND   | Datos en escala de grises |


## Prueba funcional

La prueba principal utiliza una imagen real denominada Sapo Perro

La prueba principal se encuentra en:

 tests/tb_cpu_ram_accel.cpp

La resolución utilizada es:

  1920 × 1080 píxeles

La imagen original se almacena como:

  sapo_perro.png

El archivo utilizado por la simulación es:

  sapo_perro.rgb


## Preparación de la imagen de entrada

Desde la raíz del proyecto, convertir la imagen PNG a formato RAW RGB:

  convert sapo_perro.png \
  -resize 1920x1080 \
    -background black \
    -gravity center \
    -extent 1920x1080 \
    -depth 8 \
    RGB:sapo_perro.rgb

El comando conserva la proporción de la imagen y evita el recorte de sus bordes. El espacio sobrante se completa con color negro.

Verificar las dimensiones de la imagen original:

  identify sapo_perro.png

Verificar el tamaño de la entrada RAW:

  stat -c%s sapo_perro.rgb

La salida debe ser:

  6220800

Este valor corresponde a:

  1920 × 1080 × 3 = 6 220 800 bytes


## Conversión de la salida RAW a PNG


Verificación del tamaño de salida:

  stat -c%s sapo_perro_gray.raw

El resultado esperado es:

  2073600


Para visualizar el resultado:

  convert \
    -size 1920x1080 \
    -depth 8 \
    gray:sapo_perro_gray.raw \
    sapo_perro_gray.png

Verificar la resolución:

  identify sapo_perro_gray.png

La salida debe indicar:

  1920x1080


## Resultados obtenidos

La simulación procesó correctamente una imagen RAW RGB con resolución de:

  1920 × 1080 píxeles

El archivo de entrada presenta el tamaño esperado:

  sapo_perro.rgb = 6 220 800 bytes

La salida generada presenta el tamaño esperado:

  sapo_perro_gray.raw = 2 073 600 bytes


La visualización del resultado final, puede verificarse en el archivo final:

  sapo_perro_gray.png


## Declaración de uso de inteligencia artificial

Para el presente trabajo se hizo uso de la herramienta Claude Code de forma conversacional para:

-Generar un resumen de conceptos relacionados a SystemC utilizando el standard IEEE Std 1666‐2023
-Revisión y sugerencias de código (por medio del comando code-review)
-Generación de la estructura básica del readme

Adicionalmente, se utilizó la herramienta ChatGPT, desarrollada por OpenAI, de forma conversacional para:

-Revisar la integración de los módulos mediante SystemC y TLM 2.0.
-Sugerir correcciones en el código y en las transacciones de comunicación.
-Sugerir una organización visual de diagrama de arquitectura en sus módulos y conexiones.
-Verificar los resultados obtenidos en las pruebas.