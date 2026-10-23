#!/usr/bin/env bash
# Workaround de LABORATORIO (NO soportado por IBM): corrige en la metastore de Zen las correspondencias
# "grupo LDAP -> grupo de Zen" para que usen el DN como clave en lugar del UUID.
# Motivo (🔎 código de usermgmt): el login compara de forma literal ldap_groups (DN que devuelve SCIM)
# contra la clave guardada (el id/UUID que escribe la interfaz). Si no coinciden, un usuario nuevo da 401.
# Uso: tools/fix-zen-ldap-groups.sh [--dry-run]   (idempotente; repítelo después de enlazar cada grupo LDAP nuevo en la UI)
set -euo pipefail
NS="${CP4BA_NS:-cp4ba}"; OC="${OC:-oc}"; GROUP_BASE="${LDAP_GROUP_BASE:-ou=groups,dc=example,dc=org}"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
BK_DIR="${CP4BA_LOG_DIR:-/opt/cp4ba/logs}"; mkdir -p "$BK_DIR"; chmod 700 "$BK_DIR" 2>/dev/null || true
PRIM=""
for pod in zen-metastore-1 zen-metastore-2; do
  r="$($OC exec -n "$NS" "$pod" -- psql -U postgres -d zen -At -c 'select pg_is_in_recovery()' 2>/dev/null || true)"
  [ "$r" = "f" ] && { PRIM="$pod"; break; }
done
[ -n "$PRIM" ] || { echo "ERROR: no encuentro el primario de zen-metastore" >&2; exit 1; }
psql_() { $OC exec -n "$NS" "$PRIM" -- psql -U postgres -d zen "$@"; }
echo ">> primario: $PRIM"
echo ">> reglas actuales (grupo | atributos):"
psql_ -At -c "select group_id, attributes from user_group_membership_rules where attributes like '%ldap_group%'" 2>/dev/null
[ "$DRY" = 1 ] && { echo ">> --dry-run: no se cambia nada"; exit 0; }
BK="$BK_DIR/zen-membership-rules-$(date +%Y%m%d-%H%M%S).txt"
psql_ -At -c "select group_id, attributes from user_group_membership_rules" > "$BK" 2>/dev/null; chmod 600 "$BK"; echo ">> copia: $BK"
psql_ -c "UPDATE user_group_membership_rules
  SET attributes = json_build_object('ldap_group', json_build_object('name', (attributes::json->'ldap_group'->>'name'),
        'id', 'cn='||(attributes::json->'ldap_group'->>'name')||',${GROUP_BASE}'))::text
  WHERE attributes like '%ldap_group%' AND (attributes::json->'ldap_group'->>'id') NOT LIKE 'cn=%'" 2>/dev/null
echo ">> listo (no hace falta reiniciar: usermgmt lee la tabla en cada login)"
