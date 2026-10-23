#!/usr/bin/env bash
# enable-ldap-memberof.sh -- SOLO LABORATORIO (OpenLDAP osixia de tools/deploy-ldap.sh)
#
# Activa el overlay "memberof" en el OpenLDAP del laboratorio y rellena el atributo
# memberOf de los usuarios a partir de los miembros de cada grupo.
#
# Motivo (hipotesis, no confirmada en cluster): la configuracion SCIM del CR usa
# user_groups_attribute=memberOf; sin ese atributo, CPE no ve a cp4admin dentro de
# cp4admins y Process Engine rechaza initProcessStore (FNRPE2130660008E).
#
# Idempotente. Uso:
#   tools/enable-ldap-memberof.sh --dry-run   # solo lee, muestra que haria
#   tools/enable-ldap-memberof.sh             # aplica (con respaldo previo)
#   tools/enable-ldap-memberof.sh --remove    # quita el overlay (marcha atras)
#
# No imprime la contrasena de admin: se usa desde la variable LDAP_ADMIN_PASSWORD
# que ya existe DENTRO del pod. El respaldo contiene hashes de passwords: chmod 600.
set -euo pipefail

NS="${LDAP_NS:-cp4ba-ldap}"
DEPLOY="${LDAP_DEPLOY:-deploy/openldap}"
BASE="${LDAP_BASE_DN:-dc=example,dc=org}"
GROUPS_DN="ou=groups,${BASE}"
USERS_DN="ou=users,${BASE}"
LOGDIR="${CP4BA_LOGDIR:-/opt/cp4ba/logs}"

MODE=apply
case "${1:-}" in
  --dry-run) MODE=dry ;;
  --remove)  MODE=remove ;;
  "")        MODE=apply ;;
  *) echo "Uso: $0 [--dry-run|--remove]" >&2; exit 2 ;;
esac

log() { printf '[memberof] %s\n' "$*"; }

# ejecutar en el pod (sin stdin)
pod()   { oc exec -n "$NS" "$DEPLOY" -- sh -c "$1"; }
# ejecutar en el pod leyendo stdin
podin() { oc exec -i -n "$NS" "$DEPLOY" -- sh -c "$1"; }

ADMIN_BIND='-x -H ldap://localhost:389 -D "cn=admin,'"${BASE}"'" -w "$LDAP_ADMIN_PASSWORD"'
EXT='-Y EXTERNAL -H ldapi:///'

command -v oc >/dev/null || { echo "oc no esta en el PATH" >&2; exit 1; }
pod 'command -v ldapsearch >/dev/null' || { echo "ldapsearch no existe en el pod" >&2; exit 1; }

# --- Estado actual ---------------------------------------------------------
OVERLAY_DN="$(pod "ldapsearch $EXT -LLL -b cn=config '(olcOverlay=memberof)' dn 2>/dev/null" | sed -n 's/^dn: //p' | head -1 || true)"
MODULE_DN="$(pod "ldapsearch $EXT -LLL -b cn=config '(objectClass=olcModuleList)' dn 2>/dev/null" | sed -n 's/^dn: //p' | head -1 || true)"
MODULE_LOADED="$(pod "ldapsearch $EXT -LLL -b cn=config '(objectClass=olcModuleList)' olcModuleLoad 2>/dev/null" | grep -ci 'memberof' || true)"
DB_DN="$(pod "ldapsearch $EXT -LLL -b cn=config '(&(objectClass=olcDatabaseConfig)(olcSuffix=${BASE}))' dn 2>/dev/null" | sed -n 's/^dn: //p' | head -1 || true)"

log "Base de datos del directorio : ${DB_DN:-<no encontrada>}"
log "Modulo de modulos            : ${MODULE_DN:-<no existe>}"
log "memberof cargado como modulo : $([ "${MODULE_LOADED:-0}" -gt 0 ] && echo si || echo no)"
log "overlay memberof presente    : ${OVERLAY_DN:-no}"

[ -n "$DB_DN" ] || { echo "No encontre la base ${BASE} en cn=config; no toco nada." >&2; exit 1; }

# --- Marcha atras ----------------------------------------------------------
if [ "$MODE" = remove ]; then
  if [ -z "$OVERLAY_DN" ]; then log "No hay overlay que quitar."; exit 0; fi
  log "Quitando overlay: $OVERLAY_DN (los atributos memberOf ya escritos se quedan)"
  printf 'dn: %s\nchangetype: delete\n' "$OVERLAY_DN" | podin "ldapmodify $EXT"
  log "Hecho."
  exit 0
fi

# --- Plan ------------------------------------------------------------------
GROUPS_LDIF="$(pod "ldapsearch $ADMIN_BIND -LLL -o ldif-wrap=no -b '${GROUPS_DN}' '(objectClass=groupOfNames)' dn member 2>/dev/null")"
NGROUPS="$(printf '%s\n' "$GROUPS_LDIF" | grep -c '^dn: ' || true)"
log "Grupos groupOfNames a repoblar: ${NGROUPS}"

if [ "$MODE" = dry ]; then
  log "--dry-run: no se cambia nada. Se haria:"
  [ "${MODULE_LOADED:-0}" -gt 0 ] || log "  1) cargar el modulo memberof"
  [ -n "$OVERLAY_DN" ]            || log "  2) crear el overlay memberof en $DB_DN"
  log "  3) reescribir 'member' de cada grupo con los mismos valores (rellena memberOf)"
  log "  (antes se haria un respaldo en ${LOGDIR})"
  exit 0
fi

# --- Respaldo --------------------------------------------------------------
mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR" 2>/dev/null || true
BK="${LOGDIR}/ldap-backup-$(date +%Y%m%d-%H%M%S).ldif"
pod "ldapsearch $ADMIN_BIND -LLL -b '${BASE}' '*' '+' 2>/dev/null" > "$BK"
chmod 600 "$BK"
log "Respaldo guardado: $BK (contiene hashes: no lo compartas)"

# --- 1) modulo -------------------------------------------------------------
if [ "${MODULE_LOADED:-0}" -eq 0 ]; then
  if [ -n "$MODULE_DN" ]; then
    log "Anadiendo memberof a $MODULE_DN"
    printf 'dn: %s\nchangetype: modify\nadd: olcModuleLoad\nolcModuleLoad: memberof\n' "$MODULE_DN" | podin "ldapmodify $EXT"
  else
    log "Creando entrada de modulos con memberof"
    printf 'dn: cn=module,cn=config\nobjectClass: olcModuleList\ncn: module\nolcModulePath: /usr/lib/ldap\nolcModuleLoad: memberof\n' | podin "ldapadd $EXT"
  fi
fi

# --- 2) overlay ------------------------------------------------------------
if [ -z "$OVERLAY_DN" ]; then
  log "Creando overlay memberof en $DB_DN"
  cat <<LDIF | podin "ldapadd $EXT"
dn: olcOverlay=memberof,${DB_DN}
objectClass: olcConfig
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: top
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf
LDIF
fi

# --- 3) repoblar memberOf --------------------------------------------------
# memberOf solo se calcula cuando cambia 'member'; se reescribe con los mismos valores.
MODS="$(printf '%s\n' "$GROUPS_LDIF" | awk '
  /^dn: /      { if (dn != "") flush(); dn=$0; n=0; delete m; next }
  /^member: /  { m[++n]=$0; next }
  function flush(   i) {
    if (n > 0) {
      print dn; print "changetype: modify"; print "replace: member";
      for (i=1; i<=n; i++) print m[i];
      print "-"; print ""
    }
  }
  END { if (dn != "") flush() }
')"
if [ -n "$MODS" ]; then
  log "Rellenando memberOf (reescribiendo member de cada grupo)"
  printf '%s\n' "$MODS" | podin "ldapmodify $ADMIN_BIND" >/dev/null
fi

# --- Verificacion ----------------------------------------------------------
log "Verificacion: memberOf de los usuarios"
pod "ldapsearch $ADMIN_BIND -LLL -b '${USERS_DN}' '(objectClass=person)' dn memberOf 2>/dev/null" || true
log "Listo. CPE/IM pueden tardar en refrescar su cache de grupos; si no cambia, reinicia el pod de CPE."
