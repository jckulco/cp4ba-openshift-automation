#!/usr/bin/env bash
# Fase 05: generate + secretos + validate de IBM (cp4a-prerequisites.sh). Guiada: comprueba el resultado y,
# si falta algo, imprime cómo hacerlo (exit 10). Nunca repite 'generate' si los secretos ya existen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; source "$ROOT/lib/common.sh"
load_all_env; find_oc || die "No encuentro 'oc'."
title "Fase 05 - generate / secretos / validate"
missing=0
for s in ldap-bind-secret ibm-fncm-secret ibm-ban-secret icp4adeploy-bas-admin-secret ibm-workflow-assistant-secrets; do
  if oc_ get secret "$s" -n "$NS" >/dev/null 2>&1; then ok "secreto $s"; else warn "falta el secreto $s"; missing=1; fi
done
if [ "$missing" = 0 ]; then mark_done 05-generate; exit 0; fi
cat <<MSG
Faltan secretos. Con la fase 04 hecha, en tmux (revisa la salida antes de pegarla: puede imprimir valores):
  cd ${CP4BA_IBM_DIR:-/opt/cp4ba/cert-kubernetes}/scripts
  ./cp4a-prerequisites.sh -m generate -n $NS          # UNA sola vez
  # crea los secretos con create_secret.sh (project/$NS/secret_template/)
  ./cp4a-prerequisites.sh -m validate -n $NS
Nota: la validación LDAP falla desde el bastión (no resuelve *.svc.cluster.local). Se verifica con un túnel:
  oc port-forward -n $LDAP_NS svc/openldap 13389:389   (NO uses 3389: lo ocupa RDP)
Luego:  ./install.sh --only 05
MSG
exit 10
