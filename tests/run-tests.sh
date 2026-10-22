#!/usr/bin/env bash
# Pruebas OFFLINE (no tocan ningún cluster): sintaxis, shellcheck (si existe), apply_retry, set_env y la fase 03 con un oc falso.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
PASS=0; FAIL=0; OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
t() { local n="$1"; shift; if "$@" >"$OUT" 2>&1; then PASS=$((PASS+1)); echo "  ok   $n"; else FAIL=$((FAIL+1)); echo "  FAIL $n"; sed 's/^/       /' "$OUT" | tail -15; fi; }

echo "== sintaxis"
for f in install.sh lib/common.sh phases/*.sh tools/*.sh tests/*.sh; do t "bash -n $f" bash -n "$f"; done
if command -v shellcheck >/dev/null; then t shellcheck shellcheck -x -S warning install.sh lib/common.sh phases/*.sh tools/*.sh; else echo "  (shellcheck no instalado: se omite)"; fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$OUT"' EXIT
export CP4BA_STATE_DIR="$TMP/state" CP4BA_WORK_DIR="$TMP/work" PATH="$ROOT/tests/fake-bin:$PATH" OC="$ROOT/tests/fake-bin/oc"

echo "== lib/common.sh"
t "set_env guarda con chmod 600" bash -c "source lib/common.sh; set_env \$CONFIG_FILE K 'a b'; [ \"\$(stat -c %a \$CONFIG_FILE)\" = 600 ] && grep -q \"K='a b'\" \$CONFIG_FILE"
t "apply_retry reintenta ante el webhook de PG" bash -c "rm -f $TMP/c; export FAKE_OC_COUNTER=$TMP/c FAKE_OC_FAILS=3 APPLY_RETRY_DELAY=0; source lib/common.sh; OC=\$OC; apply_retry -f x.yaml && [ \"\$(cat $TMP/c)\" = 4 ]"
t "apply_retry falla pronto con otros errores" bash -c "export OC=/bin/false; source lib/common.sh; ! apply_retry -f x.yaml"

echo "== fase 03 con oc falso"
t "sin operadores => rc 10" bash -c "FAKE_OC_MODE=none bash phases/03-clusteradmin.sh; [ \$? -eq 10 ]"
t "operadores 26.0.2 => hecho" bash -c "FAKE_OC_MODE=ok bash phases/03-clusteradmin.sh && [ -f $TMP/state/done/03-clusteradmin ]"
rm -rf "$TMP/state/done"
t "CSV no Succeeded => falla" bash -c "FAKE_OC_MODE=failing bash phases/03-clusteradmin.sh; [ \$? -ne 0 ] && [ ! -f $TMP/state/done/03-clusteradmin ]"
t "operador 26.0.0 => aviso de IF002" bash -c "FAKE_OC_MODE=old bash phases/03-clusteradmin.sh 2>&1 | grep -q 'no es 26.0.2'"

echo; echo "Resultado: $PASS ok, $FAIL fallas"; [ "$FAIL" -eq 0 ]
