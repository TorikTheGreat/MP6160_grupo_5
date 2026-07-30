#!/usr/bin/env bash
# run_verification.sh
# Rol C - EC4 (Verificacion, MP6160)
#
# Script de simulacion y reporte de verificacion. Encadena:
#   1) Compilar golden_generate y compare_bitexact (si no estan compilados).
#   2) (Opcional) Correr la simulacion del sistema completo con XSim, si
#      Vivado esta disponible y se le pasa --run-sim.
#   3) Generar el golden 1080p de forma independiente.
#   4) Comparar bit-exact contra la salida del sistema.
#   5) Escribir un reporte de verificacion con fecha, resultado y detalle.
#
# Uso:
#   ./run_verification.sh [opciones]
#
# Opciones:
#   --input <path>       Ruta a la imagen RAW RGB de entrada (default: busca sapo_perro.rgb)
#   --system-output <p>  Ruta a la salida del sistema (.pgm o .raw) (default: busca sapo_perro.pgm)
#   --run-sim            Intenta correr la simulacion XSim del sistema antes de comparar
#                         (requiere Vivado en el PATH y el script run_image_cosim.sh del repo)
#   --sim-script <path>  Ruta al script de simulacion a usar con --run-sim
#                         (default: ../MP6160_grupo_5-tarea3/tarea3_integracion/scripts/run_image_cosim.sh)
#   -h, --help            Muestra esta ayuda
#
# Salida:
#   report_verificacion_<timestamp>.txt   Reporte con resultado PASS/FAIL y detalle.
#   Codigo de salida 0 si PASS, 1 si FAIL o error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INPUT_RGB=""
SYSTEM_OUTPUT=""
RUN_SIM=0
SIM_SCRIPT="../MP6160_grupo_5-tarea3/tarea3_integracion/scripts/run_image_cosim.sh"

DEFAULT_INPUT_CANDIDATES=(
    "../MP6160_grupo_5-tarea3/tarea3_integracion/input/sapo_perro.rgb"
    "./sapo_perro.rgb"
)
DEFAULT_OUTPUT_CANDIDATES=(
    "../MP6160_grupo_5-tarea3/tarea3_integracion/output/sapo_perro.pgm"
    "./sapo_perro.pgm"
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT_RGB="$2"; shift 2 ;;
        --system-output)
            SYSTEM_OUTPUT="$2"; shift 2 ;;
        --run-sim)
            RUN_SIM=1; shift ;;
        --sim-script)
            SIM_SCRIPT="$2"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "[ERROR] Argumento desconocido: $1" >&2
            exit 2 ;;
    esac
done

if [[ -z "$INPUT_RGB" ]]; then
    for cand in "${DEFAULT_INPUT_CANDIDATES[@]}"; do
        if [[ -f "$cand" ]]; then INPUT_RGB="$cand"; break; fi
    done
fi
if [[ -z "$SYSTEM_OUTPUT" ]]; then
    for cand in "${DEFAULT_OUTPUT_CANDIDATES[@]}"; do
        if [[ -f "$cand" ]]; then SYSTEM_OUTPUT="$cand"; break; fi
    done
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="report_verificacion_${TIMESTAMP}.txt"

log() { echo "$@" | tee -a "$REPORT_FILE"; }

: > "$REPORT_FILE"
log "=================================================================="
log " Reporte de verificacion - EC4 MP6160 - Rol C"
log " Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
log " Host:  $(hostname)"
log "=================================================================="
log ""

if [[ -z "$INPUT_RGB" || ! -f "$INPUT_RGB" ]]; then
    log "[ERROR] No se encontro la imagen de entrada RAW RGB."
    log "        Especificar con --input <ruta>."
    exit 1
fi
log "[INFO] Imagen de entrada : $INPUT_RGB"

log ""
log "---- Paso 1: Compilacion de herramientas ----"
if [[ ! -x ./golden_generate || golden_generate.cpp -nt ./golden_generate ]]; then
    log "[BUILD] Compilando golden_generate..."
    if g++ -O2 -Wall -o golden_generate golden_generate.cpp >> "$REPORT_FILE" 2>&1; then
        log "[BUILD] golden_generate: OK"
    else
        log "[BUILD] golden_generate: FALLO"
        log "[RESULT] VERIFICATION_ABORTED"
        exit 1
    fi
else
    log "[BUILD] golden_generate ya compilado, se reutiliza."
fi

if [[ ! -x ./compare_bitexact || compare_bitexact.cpp -nt ./compare_bitexact ]]; then
    log "[BUILD] Compilando compare_bitexact..."
    if g++ -O2 -Wall -o compare_bitexact compare_bitexact.cpp >> "$REPORT_FILE" 2>&1; then
        log "[BUILD] compare_bitexact: OK"
    else
        log "[BUILD] compare_bitexact: FALLO"
        log "[RESULT] VERIFICATION_ABORTED"
        exit 1
    fi
else
    log "[BUILD] compare_bitexact ya compilado, se reutiliza."
fi

log ""
log "---- Paso 2: Simulacion del sistema (opcional) ----"
if [[ "$RUN_SIM" -eq 1 ]]; then
    if ! command -v xsim >/dev/null 2>&1; then
        log "[WARN] --run-sim solicitado pero 'xsim' no esta en el PATH."
        log "       Corre: source /tools/Xilinx/Vivado/2024.1/settings64.sh"
        log "       Se continua con la salida existente del sistema (si hay)."
    elif [[ ! -f "$SIM_SCRIPT" ]]; then
        log "[WARN] No se encontro el script de simulacion: $SIM_SCRIPT"
        log "       Se continua con la salida existente del sistema (si hay)."
    else
        log "[SIM] Corriendo simulacion con $SIM_SCRIPT ..."
        chmod +x "$SIM_SCRIPT" 2>/dev/null
        if (cd "$(dirname "$SIM_SCRIPT")" && "./$(basename "$SIM_SCRIPT")") >> "$REPORT_FILE" 2>&1; then
            log "[SIM] Simulacion completada."
        else
            log "[SIM] La simulacion termino con error (revisar log arriba)."
        fi
    fi
else
    log "[INFO] --run-sim no especificado. Se usa la salida ya existente del sistema."
fi

if [[ -z "$SYSTEM_OUTPUT" || ! -f "$SYSTEM_OUTPUT" ]]; then
    log "[ERROR] No se encontro la salida del sistema a verificar."
    log "        Especificar con --system-output <ruta>, o correr con --run-sim."
    log "[RESULT] VERIFICATION_ABORTED"
    exit 1
fi
log "[INFO] Salida del sistema: $SYSTEM_OUTPUT"

log ""
log "---- Paso 3: Generacion del golden (independiente) ----"
GOLDEN_FILE="golden_$(basename "${INPUT_RGB%.*}").gray"
if ./golden_generate "$INPUT_RGB" "$GOLDEN_FILE" >> "$REPORT_FILE" 2>&1; then
    log "[GOLDEN] Generado correctamente: $GOLDEN_FILE"
else
    log "[GOLDEN] FALLO al generar el golden."
    log "[RESULT] VERIFICATION_ABORTED"
    exit 1
fi

log ""
log "---- Paso 4: Comparacion bit-exact ----"
CMP_ARGS=("$GOLDEN_FILE" "$SYSTEM_OUTPUT")
case "$SYSTEM_OUTPUT" in
    *.pgm) CMP_ARGS+=("--skip-pgm-header") ;;
esac

if ./compare_bitexact "${CMP_ARGS[@]}" >> "$REPORT_FILE" 2>&1; then
    CMP_STATUS=0
else
    CMP_STATUS=$?
fi

log ""
log "=================================================================="
if [[ "$CMP_STATUS" -eq 0 ]]; then
    log " RESULTADO FINAL: PASS (bit-exact)"
else
    log " RESULTADO FINAL: FAIL (ver diferencias arriba)"
fi
log "=================================================================="
log ""
log "Reporte completo guardado en: $REPORT_FILE"

exit "$CMP_STATUS"