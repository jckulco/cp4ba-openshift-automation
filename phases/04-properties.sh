#!/usr/bin/env bash
# Fase 04: rellena los property files que dejó `cp4a-prerequisites.sh -m property` (paso interactivo previo, ver SESSION-NOTES).
#   - genera contraseñas únicas (BD, LTPA, keystore) en .state/cp4ba-secrets.env (chmod 600) y NO las imprime
#   - pide los datos de watsonx.ai (la API key sin eco) y los tipos de licencia (decisión del usuario, sin valor por defecto)
#   - hace una copia de seguridad de los property files en .state/ antes de tocarlos
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_all_env
CP4BA_SECRETS_FILE="$STATE_DIR/cp4ba-secrets.env"; load_env "$CP4BA_SECRETS_FILE"
title "Fase 04 - Property files de CP4BA"
PROP_DIR="${PROP_DIR:-$IBM_SCRIPTS/cp4ba-prerequisites/project/$NS/propertyfile}"
if [ ! -f "$PROP_DIR/cp4ba_user_profile.property" ]; then
  cat <<MSG
No hay property files en $PROP_DIR. Primero (interactivo; ver docs/SESSION-NOTES.md):
  cd $IBM_DIR && script -q -f /opt/cp4ba/logs/prereq-\$(date +%H%M).log -c "./scripts/cp4a-prerequisites.sh -m property -n $NS"
MSG
  exit 10
fi
need_cmd python3 openssl

# --- datos que decide el usuario ---
echo "Tipos de licencia (decisión tuya según tu derecho de uso). Valores que acepta IBM:"
echo "  CP4BA: non-production | production      Content Cortex: user, concurrent-user, authorized-user, non-production, production"
echo "  BAW: concurrent-user, authorized-user, non-production, production"
ask LIC_CP4BA "Licencia CP4BA"
ask LIC_CONTENT_CORTEX "Licencia Content Cortex"
ask LIC_BAW "Licencia BAW"
ask WXAI_URL "URL de watsonx.ai (SaaS)" "https://us-south.ml.cloud.ibm.com"
ask WXAI_PROJECT_ID "Project ID del proyecto de watsonx.ai"
ask_optional WXAI_MODEL_ID "Modelo (vacío = el de IBM: meta-llama/llama-3-3-70b-instruct)"
ask_secret WXAI_API_KEY "API key de IBM Cloud para watsonx.ai"
for v in LIC_CP4BA LIC_CONTENT_CORTEX LIC_BAW WXAI_URL WXAI_PROJECT_ID WXAI_MODEL_ID; do set_env "$CONFIG_FILE" "$v" "${!v:-}"; done
set_env "$SECRETS_FILE" WXAI_API_KEY "$WXAI_API_KEY"

if confirm "¿Probar ahora la API key, el proyecto y el modelo contra watsonx.ai?" y; then
  WXAI_API_KEY="$WXAI_API_KEY" WXAI_URL="$WXAI_URL" WXAI_PROJECT_ID="$WXAI_PROJECT_ID" WXAI_MODEL_ID="${WXAI_MODEL_ID:-}" \
    python3 "$ROOT/tools/test-wxai.py" || { err "La prueba de watsonx.ai falló: corrígelo y repite la fase (reconfigura con CP4BA_... o borra esos valores de $CONFIG_FILE)."; exit 1; }
fi

# --- contraseñas generadas (una sola vez) ---
for v in PW_DB_GCD PW_DB_OS PW_DB_ICN PW_DB_BAS LTPA_CONTENT KS_CONTENT LTPA_BAN KS_BAN; do
  [ -n "${!v:-}" ] || { printf -v "$v" '%s' "$(gen_pw)"; set_env "$CP4BA_SECRETS_FILE" "$v" "${!v}"; }
done
load_env "$LDAP_SECRETS_FILE"
[ -n "${PW_CP4ADMIN:-}" ] && [ -n "${LDAP_ADMIN_PW:-}" ] || die "Faltan contraseñas del LDAP: ejecuta la fase 02."

# --- copia de seguridad (una vez) y relleno ---
BK="$STATE_DIR/properties-backup"
if [ ! -d "$BK" ]; then cp -a "$PROP_DIR" "$BK"; chmod -R go-rwx "$BK"; ok "Copia original en $BK"; fi
export FILE_SC BLOCK_SC LIC_CP4BA LIC_CONTENT_CORTEX LIC_BAW WXAI_URL WXAI_PROJECT_ID WXAI_MODEL_ID WXAI_API_KEY
export LDAP_HOST="openldap.${LDAP_NS}.svc.cluster.local" LDAP_PORT=389 LDAP_BASE_DN="dc=example,dc=org"
export LDAP_ADMIN_PW PW_CP4ADMIN PW_DB_GCD PW_DB_OS PW_DB_ICN PW_DB_BAS LTPA_CONTENT KS_CONTENT LTPA_BAN KS_BAN
python3 -I "$ROOT/tools/fill-properties.py" "$PROP_DIR"
if python3 -I "$ROOT/tools/fill-properties.py" --check "$PROP_DIR"; then ok "No quedan <Required>"; else die "Quedan <Required> sin rellenar (ver arriba)."; fi
chmod 600 "$PROP_DIR"/*.property
mark_done 04-properties
log "Siguiente: revisa los valores no secretos (¡sin pegar contraseñas!) y ejecuta cp4a-prerequisites.sh -m generate -n $NS UNA SOLA VEZ."
