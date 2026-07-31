# MP-6160 — Tarea 4, rol A
# Uso: source activate.sh

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "Este archivo debe cargarse con: source activate.sh" >&2
    exit 1
fi

_ROL_A_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export SYSTEMC_HOME="$_ROL_A_ROOT/tools/systemc"
export LD_LIBRARY_PATH="$SYSTEMC_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ -f "$SYSTEMC_HOME/include/systemc.h" ]; then
    echo "Entorno del rol A cargado."
    echo "  SystemC: $SYSTEMC_HOME"
    echo "  TLM 2.0: $([ -f "$SYSTEMC_HOME/include/tlm.h" ] && echo 'disponible' || echo 'no encontrado')"
else
    echo "SystemC no está instalado. Ejecute ./setup.sh primero." >&2
fi
