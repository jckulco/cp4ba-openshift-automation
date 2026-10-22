#!/usr/bin/env bash
# Fase 00: valida el cluster y guarda la configuración NO secreta (namespace y clases de almacenamiento).
# No pide ni guarda la entitlement key: la pide el script de IBM (fase 03) y queda en el secreto ibm-entitlement-key.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_all_env
find_oc || die "No encuentro 'oc' (ponlo en /usr/local/bin)."
title "Fase 00 - Configuración y validación del cluster"

oc_ whoami >/dev/null 2>&1 || die "No hay sesión de oc. Haz 'oc login' como cluster-admin."
ver="$(oc_ get clusterversion version -o jsonpath='{.status.desired.version}')"
case "$ver" in 4.18.*|4.19.*|4.2[0-2].*) ok "OpenShift $ver (CP4BA 26.0.0 soporta 4.18-4.22)";; *) warn "OpenShift $ver fuera del rango 4.18-4.22 del reporte de compatibilidad";; esac
bad="$(oc_ get co --no-headers | awk '$3!="True"||$4!="False"||$5!="False"' | wc -l)"
[ "$bad" -eq 0 ] && ok "Todos los operadores del cluster Available y sin degradar" || warn "$bad ClusterOperators no están sanos (oc get co)"
nodes="$(oc_ get nodes --no-headers | awk '$2=="Ready"' | wc -l)"; ok "$nodes nodos Ready"

ask NS "Namespace de CP4BA (nuevo, sin CPFS previo)" "cp4ba"
ask FILE_SC "StorageClass RWX (CephFS)" "ocs-storagecluster-cephfs"
ask BLOCK_SC "StorageClass de bloque (RBD)" "ocs-storagecluster-ceph-rbd"
for sc in "$FILE_SC" "$BLOCK_SC"; do oc_ get sc "$sc" >/dev/null 2>&1 || die "No existe la StorageClass $sc"; done
if oc_ get csv -A --no-headers 2>/dev/null | grep -qE 'ibm-common-service-operator' && ! oc_ get ns "$NS" >/dev/null 2>&1; then
  warn "Ya hay CPFS en el cluster fuera de $NS: IBM pide instalar en un namespace sin CPFS previo."
fi
set_env "$CONFIG_FILE" NS "$NS"
set_env "$CONFIG_FILE" LDAP_NS "${LDAP_NS:-cp4ba-ldap}"
set_env "$CONFIG_FILE" FILE_SC "$FILE_SC"
set_env "$CONFIG_FILE" BLOCK_SC "$BLOCK_SC"
set_env "$CONFIG_FILE" APPS_DOMAIN "$(apps_domain)"
ok "Configuración guardada en $CONFIG_FILE"
mark_done 00-configure
