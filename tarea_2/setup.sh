#!/usr/bin/env bash
#
# MP-6160 — Tarea 2: instalador del entorno de desarrollo.
# Instala SystemC 2.3.4 (incluye TLM 2.0) dentro de ESTE directorio (tarea_2/),
# de forma autocontenida: no toca el resto del repo ni otras tareas.
#
#   tarea_2/tools/systemc/   <- prefijo de instalación de SystemC
#
# Uso:
#   ./setup.sh
#
# Seguro de re-ejecutar: cada paso se omite si ya está completo.
# Probado en Ubuntu 24.04 (x86_64). En Windows usar WSL2 (Ubuntu).

set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SYSTEMC_VERSION="2.3.4"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Paquetes del sistema (requiere sudo)
# ---------------------------------------------------------------------------
log "Verificando paquetes del sistema (apt)"
APT_PKGS=(build-essential cmake git curl gtkwave)
MISSING=()
for p in "${APT_PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
done
if [ ${#MISSING[@]} -gt 0 ]; then
    warn "Instalando: ${MISSING[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING[@]}"
else
    ok "todos los paquetes apt ya están instalados"
fi

# ---------------------------------------------------------------------------
# 2. SystemC 2.3.4 + TLM 2.0 (compila desde el código fuente)
# ---------------------------------------------------------------------------
log "Instalando SystemC $SYSTEMC_VERSION (TLM 2.0 incluido)"
if [ -f "$ROOT/tools/systemc/include/systemc.h" ]; then
    ok "SystemC ya instalado en tools/systemc/"
else
    mkdir -p "$ROOT/tools/src"
    cd "$ROOT/tools/src"
    [ -f "$SYSTEMC_VERSION.tar.gz" ] || \
        curl -fLO "https://github.com/accellera-official/systemc/archive/refs/tags/$SYSTEMC_VERSION.tar.gz"
    [ -d "systemc-$SYSTEMC_VERSION" ] || tar xzf "$SYSTEMC_VERSION.tar.gz"
    cd "systemc-$SYSTEMC_VERSION"
    mkdir -p build && cd build
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$ROOT/tools/systemc" \
        -DCMAKE_CXX_STANDARD=17 \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    make -j"$(nproc)"
    make install
    cd "$ROOT"
    ok "SystemC instalado en tools/systemc/ (TLM 2.0 en include/tlm.h)"
fi

# ---------------------------------------------------------------------------
log "Listo. Siguientes pasos:"
cat <<EOF

    source activate.sh                 # cargar el entorno en esta terminal
    cd examples/sanity && make run     # verificar la instalación

Ejecuta 'source activate.sh' en CADA terminal nueva.
Para recuperar ~200 MB una vez verificado:  rm -rf tools/src
EOF
