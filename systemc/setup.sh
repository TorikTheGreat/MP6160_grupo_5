#!/usr/bin/env bash
#
# MP-6160 — Tarea 4, rol A
# Instala SystemC 2.3.4 dentro de este mismo directorio.
#
# Uso:
#   chmod +x setup.sh
#   ./setup.sh

set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SYSTEMC_VERSION="2.3.4"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*"; }

log "Verificando paquetes del sistema"
APT_PKGS=(build-essential cmake git curl)
MISSING=()
for package in "${APT_PKGS[@]}"; do
    dpkg -s "$package" >/dev/null 2>&1 || MISSING+=("$package")
done

if [ ${#MISSING[@]} -gt 0 ]; then
    warn "Instalando: ${MISSING[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING[@]}"
else
    ok "los paquetes requeridos ya están instalados"
fi

log "Preparando SystemC $SYSTEMC_VERSION"
if [ -f "$ROOT/tools/systemc/include/systemc.h" ]; then
    ok "SystemC ya está instalado en tools/systemc"
else
    mkdir -p "$ROOT/tools/src"
    cd "$ROOT/tools/src"

    [ -f "$SYSTEMC_VERSION.tar.gz" ] || \
        curl -fLO "https://github.com/accellera-official/systemc/archive/refs/tags/$SYSTEMC_VERSION.tar.gz"

    [ -d "systemc-$SYSTEMC_VERSION" ] || \
        tar xzf "$SYSTEMC_VERSION.tar.gz"

    cd "systemc-$SYSTEMC_VERSION"
    mkdir -p build
    cd build

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$ROOT/tools/systemc" \
        -DCMAKE_CXX_STANDARD=17 \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    make -j"$(nproc)"
    make install
    ok "SystemC quedó instalado en tools/systemc"
fi

cat <<'NEXT'

Entorno listo. En esta terminal ejecute:

    source activate.sh
    make wrapper-test

Use 'source activate.sh' en cada terminal nueva.
NEXT
