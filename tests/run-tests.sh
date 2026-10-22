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
t "set_env guarda con chmod 600" bash -c "source lib/common.sh; set_env \$CONFIG_FILE K 'a b'; m=\$(stat -c %a \$CONFIG_FILE 2>/dev/null || stat -f %Lp \$CONFIG_FILE); [ \"\$m\" = 600 ] && grep -q \"K='a b'\" \$CONFIG_FILE"
t "apply_retry reintenta ante el webhook de PG" bash -c "rm -f $TMP/c; export FAKE_OC_COUNTER=$TMP/c FAKE_OC_FAILS=3 APPLY_RETRY_DELAY=0; source lib/common.sh; OC=\$OC; apply_retry -f x.yaml && [ \"\$(cat $TMP/c)\" = 4 ]"
t "apply_retry falla pronto con otros errores" bash -c "export OC=/bin/false; source lib/common.sh; ! apply_retry -f x.yaml"

echo "== fase 03 con oc falso"
t "sin operadores => rc 10" bash -c "FAKE_OC_MODE=none bash phases/03-clusteradmin.sh; [ \$? -eq 10 ]"
t "operadores 26.0.2 => hecho" bash -c "FAKE_OC_MODE=ok bash phases/03-clusteradmin.sh && [ -f $TMP/state/done/03-clusteradmin ]"
rm -rf "$TMP/state/done"
t "CSV no Succeeded => falla" bash -c "FAKE_OC_MODE=failing bash phases/03-clusteradmin.sh; [ \$? -ne 0 ] && [ ! -f $TMP/state/done/03-clusteradmin ]"
t "operador 26.0.0 => aviso de IF002" bash -c "FAKE_OC_MODE=old bash phases/03-clusteradmin.sh 2>&1 | grep -q 'no es 26.0.2'"

echo "== tools/fill-properties.py (property files generados en tiempo de prueba)"
for f in tools/*.py; do t "py_compile $f" python3 -m py_compile "$f"; done
bash tests/make-fixtures.sh "$TMP/pf"
# valores ficticios ALEATORIOS creados en cada ejecución (nada literal en el repo)
r() { openssl rand -hex 6; }
A1=$(r); A2=$(r); A3=$(r); A4=$(r); A5=$(r); A6=$(r); A7=$(r); A8=$(r); A9=$(r)
FILLENV="FILE_SC=sc-file BLOCK_SC=sc-block LDAP_HOST=ldap.example LDAP_PORT=389 LDAP_BASE_DN=dc=example,dc=org LDAP_ADMIN_PW=$A1 PW_CP4ADMIN=$A2 PW_DB_GCD=$A3 PW_DB_OS=$A4 PW_DB_ICN=$A5 PW_DB_BAS=$A6 LTPA_CONTENT=$A7 KS_CONTENT=$A8 LIC_CP4BA=non-production LIC_CONTENT_CORTEX=non-production LIC_BAW=non-production WXAI_API_KEY=$A1$A2 WXAI_URL=https://us-south.ml.cloud.ibm.com WXAI_PROJECT_ID=pid"
t "--check detecta <Required>" bash -c "python3 -I tools/fill-properties.py --check $TMP/pf; [ \$? -eq 5 ]"
t "relleno ok y sin <Required>" bash -c "env $FILLENV python3 -I tools/fill-properties.py $TMP/pf >$TMP/o.txt && python3 -I tools/fill-properties.py --check $TMP/pf"
t "no imprime secretos" bash -c "! grep -qE '$A1|$A2|$A3|$A4' $TMP/o.txt"
t "corrige el storageclass truncado" bash -c "grep -q '^CP4BA.SLOW_FILE_STORAGE_CLASSNAME=\"sc-file\"' $TMP/pf/cp4ba_user_profile.property"
t "LDAP sin TLS y filtro por uid" bash -c "grep -q 'LDAP_SSL_ENABLED=\"False\"' $TMP/pf/cp4ba_LDAP.property && grep -q 'uid=%v' $TMP/pf/cp4ba_LDAP.property"
t "osuser comparte contraseña en los 3 object stores" bash -c "[ \$(grep -c 'DB_USER_PASSWORD=\"$A4\"' $TMP/pf/cp4ba_db_name_user.property) -eq 3 ]"
t "SCIM de grupos = groupOfNames/member" bash -c "grep -q 'GROUP_OBJECT_CLASS_ATTRIBUTE=\"groupOfNames\"' $TMP/pf/cp4ba_user_profile.property && grep -q 'GROUP_MEMBERS_ATTRIBUTE=\"member\"' $TMP/pf/cp4ba_user_profile.property"
t "LTPA y keystore de CONTENT y BAN son iguales (exigencia de IBM)" bash -c "f=$TMP/pf/cp4ba_user_profile.property; [ \"\$(grep '^CONTENT.LTPA_' \$f | cut -d= -f2)\" = \"\$(grep '^BAN.LTPA_' \$f | cut -d= -f2)\" ] && [ \"\$(grep '^CONTENT.KEYSTORE_' \$f | cut -d= -f2)\" = \"\$(grep '^BAN.KEYSTORE_' \$f | cut -d= -f2)\" ]"
t "conserva comentarios" bash -c "grep -q '^## comentario de ejemplo' $TMP/pf/cp4ba_user_profile.property"
t "rechaza comilla simple en contraseñas (rc 4)" bash -c "env $FILLENV PW_DB_GCD=\"a'b\" python3 -I tools/fill-properties.py $TMP/pf >/dev/null 2>&1; [ \$? -eq 4 ]"
t "falta una variable => rc 2" bash -c "env -i PATH=\$PATH python3 -I tools/fill-properties.py $TMP/pf >/dev/null 2>&1; [ \$? -eq 2 ]"
t "clave inexistente => rc 3" bash -c "bash tests/make-fixtures.sh $TMP/pf2 && grep -v '^BASTUDIO.ADMIN_USER' $TMP/pf2/cp4ba_user_profile.property > $TMP/x && mv $TMP/x $TMP/pf2/cp4ba_user_profile.property && env $FILLENV python3 -I tools/fill-properties.py $TMP/pf2 >/dev/null 2>&1; [ \$? -eq 3 ]"

echo; echo "Resultado: $PASS ok, $FAIL fallas"; [ "$FAIL" -eq 0 ]
