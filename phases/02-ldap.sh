#!/usr/bin/env bash
# Fase 02: OpenLDAP de LABORATORIO + atributo ibm-entryUuid. IF002 falla con IdP externo sin LDAP (DT498940).
# Debe hacerse ANTES de crear el dominio P8 de FileNet (lección del proyecto anterior: si no, el admin queda sin permisos).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_all_env
find_oc || die "No encuentro 'oc'."
export OC CP4BA_STATE_DIR="$STATE_DIR" LDAP_NS
title "Fase 02 - OpenLDAP de laboratorio"
bash "$ROOT/tools/deploy-ldap.sh"
load_env "$LDAP_SECRETS_FILE"
log "Añadiendo ibm-entryUuid a usuarios y grupos"
bash "$ROOT/tools/fix-ldap-guid.sh" | tail -10
mark_done 02-ldap
