#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_BUILD=1
TARGET="ZERO2"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build)
            RUN_BUILD=0
            shift
            ;;
        --target)
            TARGET="${2:-}"
            if [[ -z "$TARGET" ]]; then
                echo "ERROR: --target requiere un valor"
                exit 2
            fi
            shift 2
            ;;
        -h|--help)
            cat <<EOF
Uso: $0 [--no-build] [--target ZERO2]

Micro-bateria INVES:
- Verifica invariantes criticos (T3/T6/timing/base audio)
- Opcionalmente compila firmware con ./build_all.sh
EOF
            exit 0
            ;;
        *)
            echo "ERROR: argumento no reconocido: $1"
            exit 2
            ;;
    esac
done

cd "$ROOT_DIR"

PASS=0
FAIL=0

ok() {
    echo "[OK]   $1"
    PASS=$((PASS + 1))
}

ko() {
    echo "[FAIL] $1"
    FAIL=$((FAIL + 1))
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if rg -n --no-heading -e "$pattern" "$file" >/dev/null 2>&1; then
        ok "$desc"
    else
        ko "$desc"
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if rg -n --no-heading -e "$pattern" "$file" >/dev/null 2>&1; then
        ko "$desc"
    else
        ok "$desc"
    fi
}

echo "=== Micro-bateria de regresion INVES ==="

echo "[1/5] Validando timing base INVES"
require_pattern "src/CPU.h" "#define[[:space:]]+TSTATES_PER_FRAME_INVES[[:space:]]+70908" "TSTATES_PER_FRAME_INVES = 70908"
require_pattern "src/CPU.h" "#define[[:space:]]+INT_START_INVES[[:space:]]+15801" "INT_START_INVES = 15801"

echo "[2/5] Validando T6 (INTA espurio en IM2)"
require_pattern "src/Z80_JLS.cpp" "if[[:space:]]*\([[:space:]]*Z80Ops::isInves[[:space:]]*&&[[:space:]]*modeINT[[:space:]]*==[[:space:]]*IntMode::IM2[[:space:]]*\)" "Guardia IM2 para INTA espurio en INVES"
require_pattern "src/Z80_JLS.cpp" "MemESP::ram\[inta_addr >> 14\]\.write\(inta_addr & 0x3FFF, 0xFF\)" "Escritura espuria INTA en RAM"

echo "[3/5] Validando T3 (sin mascara RAM en OUT FE)"
reject_pattern "src/Ports.cpp" "read\(0x00FE\)" "No usar RAM[0x00FE] para enmascarar OUT FE"
reject_pattern "src/Ports.cpp" "data[[:space:]]*&=[[:space:]]*ramValue" "No enmascarar FE con valor RAM temporal"
require_pattern "src/Ports.cpp" "if[[:space:]]*\([[:space:]]*Z80Ops::isInves[[:space:]]*\)" "Existe salida condicional INVES en OUT ULA"

echo "[4/5] Validando audio INVES (XOR MIC/SPK)"
require_pattern "src/Ports.cpp" "\(\(data >> 3\) \^ \(data >> 4\)\) & 0x01" "Beeper INVES usa XOR bit3/bit4"

echo "[4b/5] Validando Kempston fijo en INVES (0x1F)"
require_pattern "src/Ports.cpp" "return port\[0x1F\] & 0x1F;" "Lectura INVES de Kempston fija en 0x1F"
require_pattern "src/Config.cpp" "if \(Config::arch == \"INVES\"\)[[:space:]]*\{" "Existe saneamiento de config para INVES"
require_pattern "src/Config.cpp" "Config::kempstonPort = 0x1F;" "Config fuerza kempstonPort=0x1F en INVES"

echo "[5/5] Build opcional"
if [[ "$RUN_BUILD" -eq 1 ]]; then
    if ./build_all.sh "$TARGET" >/tmp/regression_inves_build.log 2>&1; then
        ok "Build $TARGET completada"
    else
        ko "Build $TARGET fallida (ver /tmp/regression_inves_build.log)"
    fi
else
    echo "[SKIP] Build desactivada por --no-build"
fi

echo
echo "=== Resultado ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
    echo "Regresion detectada"
    exit 1
fi

echo "Todo correcto"
