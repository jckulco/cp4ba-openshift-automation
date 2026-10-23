#!/usr/bin/env bash
# Fase 06: cp4a-deployment.sh (interactivo) genera el CR; aquí se revisa y se aplica. El script de IBM valida el LDAP
# desde el bastión: hace falta resolver el nombre interno (túnel + /etc/hosts TEMPORAL, ver docs/MANUAL-STEPS.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; source "$ROOT/lib/common.sh"
load_all_env; find_oc || die "No encuentro 'oc'."
title "Fase 06 - Despliegue del CR"
if oc_ get icp4acluster icp4adeploy -n "$NS" >/dev/null 2>&1; then ok "CR icp4adeploy ya aplicado"; mark_done 06-deploy; exit 0; fi
CR="${CP4BA_IBM_DIR:-/opt/cp4ba/cert-kubernetes}/scripts/generated-cr/project/$NS/ibm_cp4a_cr_final.yaml"
if [ ! -f "$CR" ]; then
cat <<MSG
Aún no existe el CR. Ejecuta (tmux) y responde: licencia (tú) · Content CR: No · Production · OCP · AWS/Azure: No ·
IM admin cpadmin: Yes · drivers JDBC: vacío · resumen: Yes
  sudo sh -c 'echo "127.0.0.1 openldap.$LDAP_NS.svc.cluster.local # TEMP-cp4ba" >> /etc/hosts'
  oc port-forward -n $LDAP_NS svc/openldap 389:389      # en otra ventana
  cd ${CP4BA_IBM_DIR:-/opt/cp4ba/cert-kubernetes}/scripts && ./cp4a-deployment.sh -n $NS
  sed -i '/TEMP-cp4ba/d' /etc/hosts                     # al terminar: limpia
Luego:  ./install.sh --only 06
MSG
exit 10
fi
log "Revisión del CR (sin valores secretos):"
grep -nE '^  name:|ibm_license|sc_optional_components|sc_deployment_(license|type|platform|profile_size)|storage_classname' "$CR" | grep -viE 'password|key:' || true
grep -q 'ibm_license: "accept"' "$CR" || die "El CR no tiene ibm_license: \"accept\""
confirm "¿Aplicar el CR ahora? (inicia la instalación larga)" || { warn "No aplicado."; exit 10; }
cp -f "$CR" "$STATE_DIR/ibm_cp4a_cr_final.applied.yaml" 2>/dev/null || true
oc_ apply -f "$CR" -n "$NS"; mark_done 06-deploy; ok "CR aplicado. Sigue con la fase 07."
