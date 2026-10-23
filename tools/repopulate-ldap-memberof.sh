#!/usr/bin/env bash
# repopulate-ldap-memberof.sh -- SOLO LABORATORIO (OpenLDAP osixia)
# Imprime la configuracion del overlay memberof y rellena memberOf forzando un cambio real
# de 'member' en cada grupo. Cada grupo se toca en UNA sola operacion LDAP (atomica):
# si falla, el grupo queda como estaba. Usa el DN base como miembro temporal.
set -euo pipefail
NS="${LDAP_NS:-cp4ba-ldap}"; DEPLOY="${LDAP_DEPLOY:-deploy/openldap}"
BASE="${LDAP_BASE_DN:-dc=example,dc=org}"
pod()   { oc exec -n "$NS" "$DEPLOY" -- sh -c "$1"; }
podin() { oc exec -i -n "$NS" "$DEPLOY" -- sh -c "$1"; }
BIND='-x -H ldap://localhost:389 -D "cn=admin,'"${BASE}"'" -w "$LDAP_ADMIN_PASSWORD"'

echo "== configuracion del overlay memberof"
pod "ldapsearch -Y EXTERNAL -H ldapi:/// -LLL -b cn=config '(olcOverlay=memberof)' olcMemberOfGroupOC olcMemberOfMemberAD olcMemberOfMemberOfAD olcMemberOfRefInt olcMemberOfDangling 2>/dev/null" || true

G="$(pod "ldapsearch $BIND -LLL -o ldif-wrap=no -b 'ou=groups,${BASE}' '(objectClass=groupOfNames)' dn member 2>/dev/null")"
MODS="$(printf '%s\n' "$G" | awk -v base="$BASE" '
  /^dn: /     { if (dn != "") flush(); dn=$0; n=0; delete m; next }
  /^member: / { m[++n]=$0; next }
  function flush(   i) {
    if (n > 0) {
      print dn; print "changetype: modify"
      print "add: member";    print "member: " base; print "-"
      print "delete: member"; for (i=1; i<=n; i++) print m[i]; print "-"
      print "add: member";    for (i=1; i<=n; i++) print m[i]; print "-"
      print "delete: member"; print "member: " base
      print ""
    }
  }
  END { if (dn != "") flush() }
')"
[ -n "$MODS" ] || { echo "No hay grupos con miembros; no hago nada." >&2; exit 1; }

echo "== reescribiendo member (una operacion atomica por grupo)"
printf '%s\n' "$MODS" | podin "ldapmodify $BIND" | sed 's/^/   /'

echo "== verificacion: memberOf de los usuarios"
pod "ldapsearch $BIND -LLL -b 'ou=users,${BASE}' '(objectClass=person)' dn memberOf 2>/dev/null" || true
