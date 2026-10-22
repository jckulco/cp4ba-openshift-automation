#!/usr/bin/env bash
# Fase 03: operadores de CP4BA con cp4a-clusteradmin-setup.sh de IBM. Es INTERACTIVO (y la licencia la aceptas tú):
# por eso esta fase solo comprueba si ya se hizo y, si no, imprime cómo hacerlo (código de salida 10 = paso manual).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_all_env
find_oc || die "No encuentro 'oc'."
title "Fase 03 - Operadores de CP4BA (cp4a-clusteradmin-setup.sh)"
csv="$(oc_ get csv -n "$NS" --no-headers 2>/dev/null | awk '$1 ~ /^ibm-cp4a-operator/ {print $1" "$NF}' | head -1 || true)"
if [ -n "$csv" ]; then
  name="${csv% *}"; phase="${csv##* }"
  [ "$phase" = "Succeeded" ] || die "El CSV $name está en '$phase' (esperando Succeeded). Revisa: oc get csv -n $NS"
  case "$name" in *26.0.2*) ok "Operador $name Succeeded (IF002)";; *) warn "Operador $name: no es 26.0.2 (IF002). Revisa el catálogo antes de desplegar.";; esac
  bad="$(oc_ get csv -n "$NS" --no-headers | awk '$NF!="Succeeded"' | wc -l)"
  [ "$bad" -eq 0 ] || die "$bad CSV no están en Succeeded (oc get csv -n $NS)"
  oc_ get sub -n "$NS" -o jsonpath='{range .items[*]}{.spec.installPlanApproval}{"\n"}{end}' | grep -qv Automatic && warn "Hay Subscriptions con aprobación manual (IBM pide Automatic)"
  mark_done 03-clusteradmin; exit 0
fi
cat <<MSG
Todavía no hay operadores en $NS. Ejecuta (en tmux) el script de IBM y responde los menús (ver docs/SESSION-NOTES.md):

  mkdir -p /opt/cp4ba/logs && chmod 700 /opt/cp4ba/logs
  cd $IBM_DIR && script -q -f /opt/cp4ba/logs/clusteradmin-\$(date +%H%M).log -c "./scripts/cp4a-clusteradmin-setup.sh"

Respuestas usadas en la sesión de referencia: licencia (decides tú) · Online · OCP · Production · FIPS: No ·
catálogo privado: Yes · separar operadores/operandos: No · namespace: $NS · tienes key: Yes (se pega en el prompt, no en el chat).
Luego repite:  ./install.sh --only 03
MSG
exit 10
