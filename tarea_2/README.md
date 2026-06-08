# Tarea 2 (EC2) — Modelo SystemC / TLM 2.0

Modelo a nivel de transacciones de un sistema **CPU + RAM (64 MB) + almacenamiento
persistente + acelerador** de imagen (RGB → escala de grises), descrito en
**SystemC** con comunicación **TLM 2.0**.

Este directorio es **autocontenido**: instala y compila sus propias dependencias
en `tools/`, sin afectar otras tareas ni el proyecto. Cada tarea del curso tiene
su propio entorno aislado.

---

## Requisitos

- **Ubuntu 24.04** (x86_64). En Windows: WSL2 con Ubuntu. En macOS: VM Linux.
- Permisos `sudo` (solo para instalar paquetes de sistema con `apt`).
- ~150 MB de disco y conexión a internet la primera vez (se descarga y compila
  SystemC).

## Instalación (una sola vez)

```bash
cd tarea_2
./setup.sh
```

Esto:
1. Instala con `apt` lo necesario: `build-essential cmake git curl gtkwave`
   (pide tu contraseña `sudo`; omite los que ya estén).
2. Descarga y compila **SystemC 2.3.4** (incluye **TLM 2.0**) en
   `tools/systemc/`. Tarda ~3 min.

Es seguro re-ejecutarlo: los pasos completados se omiten.

## Activar el entorno (en cada terminal nueva)

```bash
source activate.sh
```

Define `SYSTEMC_HOME` y `LD_LIBRARY_PATH` para esta tarea y aplica el arreglo de
GTKWave en Ubuntu 24.04. La configuración es **por terminal**; no persiste.

> **Tip:** agrega un alias a tu `~/.bashrc`:
> ```bash
> alias t2='cd <ruta-al-repo>/MP6160_grupo_5/tarea_2 && source activate.sh'
> ```

## Verificar la instalación

```bash
cd examples/sanity
make run
```

Salida esperada (una transacción TLM de ida y vuelta):

```
TLM round-trip: escrito 0xdeadbeef, leido 0xdeadbeef   [OK]
Tiempo de simulacion tras 2 transacciones: 20 ns
```

Si ves `[OK]`, SystemC y TLM están bien instalados.

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
  setup.sh              # instalador del entorno (correr una vez)
  activate.sh           # cargar el entorno (source en cada terminal)
  README.md             # este archivo
  .gitignore            # ignora tools/ y artefactos
  examples/sanity/      # verificación SystemC + TLM (hello_tlm)
  articulo/             # informe (plantilla IEEE)
  tools/                # SystemC compilado — NO se commitea (lo regenera setup.sh)
```

## Por qué `tools/` no se commitea

SystemC se compila desde el código fuente y sus binarios no son relocalizables
(rpath embebido). Subirlo al repo lo rompería en otra máquina. En su lugar, cada
integrante clona el repo y corre `./setup.sh` para reconstruirlo localmente.

---

## Artículo (LaTeX) — que todos usemos lo mismo

El informe está en `articulo/` (plantilla IEEE `conference`). LaTeX **no** se
instala por tarea como SystemC: TeX Live es un paquete de sistema. Para que todos
compilemos con las mismas herramientas, usen **una** de estas dos opciones.

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

Suban la carpeta `articulo/` a un proyecto de Overleaf. Incluye `IEEEtran.cls`,
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
