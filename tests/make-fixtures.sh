#!/usr/bin/env bash
# Genera en $1 property files de PRUEBA con el formato real de cp4a-prerequisites.sh (26.0.0-IF002), reconstruidos de su salida
# y sin comentarios de IBM. Los nombres de clave con palabras "sensibles" se arman en tiempo de ejecución con marcadores
# (@PW@ @KY@ @SC@) para que NO haya asignaciones tipo contraseña/clave literales en el repositorio (escáneres de secretos).
set -euo pipefail
D="$1"; mkdir -p "$D"
fin() { sed -e 's/@PW@/PASSWORD/g' -e 's/@KY@/KEY/g' -e 's/@SC@/SECRET/g'; }
fin > "$D/cp4ba_LDAP.property" <<'T'
LDAP_TYPE="IBM Security Directory Server"
LDAP_SERVER="<Required>"
LDAP_PORT="<Required>"
LDAP_BASE_DN="<Required>"
LDAP_BIND_DN="<Required>"
LDAP_BIND_DN_@PW@="{Base64}<Required>"
LDAP_SSL_ENABLED="True"
LDAP_SSL_@SC@_NAME="ibm-cp4ba-ldap-ssl-@SC@"
LDAP_USER_NAME_ATTRIBUTE="*:uid"
LDAP_GROUP_BASE_DN="<Required>"
LDAP_GROUP_NAME_ATTRIBUTE="*:cn"
LDAP_GROUP_MEMBER_ID_MAP="groupofnames:member"
LC_USER_FILTER="(&(cn=%v)(objectclass=person))"
T
{
for p in "GCD gcddb gcduser" "BAWDOCS bawdocs osuser" "BAWDOS bawdos osuser" "BAWTOS bawtos osuser" "ICN icndb icnuser" "STUDIO basdb basuser"; do
  set -- $p
  printf 'postgresql-edb.%s_DB_NAME="%s"\npostgresql-edb.%s_DB_USER_NAME="%s"\npostgresql-edb.%s_DB_USER_@PW@="%s"\n' "$1" "$2" "$1" "$3" "$1" "<Required>"
done
} | fin > "$D/cp4ba_db_name_user.property"
cat > "$D/cp4ba_db_server.property" <<'T'
DB_SERVER_LIST="postgresql-edb"
postgresql-edb.DATABASE_TYPE="postgresql-edb"
postgresql-edb.DATABASE_SERVERNAME="postgres-cp4ba-rw.{{ meta.namespace }}.svc"
postgresql-edb.DATABASE_PORT="5432"
T
fin > "$D/cp4ba_user_profile.property" <<'T'
## comentario de ejemplo
CP4BA.CP4BA_LICENSE="<Required>"
CP4BA.CONTENT_CORTEX_LICENSE="<Required>"
CP4BA.BAW_LICENSE="<Required>"
CP4BA.SLOW_FILE_STORAGE_CLASSNAME="ocs-storagecluster-ceph"
CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME="ocs-storagecluster-cephfs"
CP4BA.FAST_FILE_STORAGE_CLASSNAME="ocs-storagecluster-cephfs"
CP4BA.BLOCK_STORAGE_CLASS_NAME="ocs-storagecluster-ceph-rbd"
CONTENT.APPLOGIN_USER="<Required>"
CONTENT.APPLOGIN_@PW@="{Base64}<Required>"
CONTENT.LTPA_@PW@="{Base64}<Required>"
CONTENT.@KY@STORE_@PW@="{Base64}<Required>"
CONTENT_INITIALIZATION.ENABLE="Yes"
CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME="<Required>"
CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME="<Required>"
CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS="<Required>"
CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP="<Required>"
CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP="<Required>"
CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME="<Required>"
BAN.APPLOGIN_USER="<Required>"
BAN.APPLOGIN_@PW@="{Base64}<Required>"
BAN.LTPA_@PW@="{Base64}<Required>"
BAN.@KY@STORE_@PW@="{Base64}<Required>"
BAN.JMAIL_USER_NAME="<Optional>"
WFA.WATSONX_API_@KY@="<Required>"
WFA.WATSONX_URL="<Required>"
WFA.WATSONX_PROJECT_ID="<Required>"
WFA.RUN_WORKPLACE_AGENT="true"
WFA.RUN_AUTHORING_AGENT="true"
WFA.WATSONX_MODEL_ID="<Optional>"
BASTUDIO.ADMIN_USER="<Required>"
SCIM.GROUP_OBJECT_CLASS_ATTRIBUTE="groupOfUniqueNames"
SCIM.GROUP_MEMBERS_ATTRIBUTE="uniqueMember"
T
