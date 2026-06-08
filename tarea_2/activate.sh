# MP-6160 — Tarea 2: entorno de desarrollo (SystemC + TLM 2.0)
# Uso:  source activate.sh
#
# Deriva las rutas de su propia ubicación, así que el entorno de esta tarea
# es independiente del de las demás tareas / el proyecto.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "Este script debe ejecutarse con 'source', no directamente:  source activate.sh" >&2
    exit 1
fi

_T2_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# --- SystemC + TLM ---
export SYSTEMC_HOME="$_T2_ROOT/tools/systemc"
export LD_LIBRARY_PATH="$SYSTEMC_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# --- Corrección Ubuntu 24.04: las rutas /snap/core* filtradas en
#     LD_LIBRARY_PATH hacen fallar GTKWave; se eliminan. ---
LD_LIBRARY_PATH="$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v '^/snap/core' | paste -sd ':' -)"
export LD_LIBRARY_PATH

if [ -f "$SYSTEMC_HOME/include/systemc.h" ]; then
    echo "Entorno Tarea 2 cargado."
    echo "  SystemC : $SYSTEMC_HOME ($(ls "$SYSTEMC_HOME"/lib/libsystemc.so.* 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null))"
    echo "  TLM 2.0 : $([ -f "$SYSTEMC_HOME/include/tlm.h" ] && echo 'incluido' || echo 'NO ENCONTRADO')"
else
    echo "Entorno Tarea 2: SystemC no encontrado en tools/. Ejecuta ./setup.sh primero." >&2
fi
