#!/usr/bin/env bash
# CP4BA 26.0.0 (IF002) + BAW con funciones de IA en Red Hat OpenShift - instalador por fases.
#   ./install.sh                 ejecuta las fases pendientes
#   ./install.sh --from 02       desde una fase       ./install.sh --only 03     una sola fase
#   ./install.sh --force         ignora las marcas de "hecho"
#   ./install.sh status          fases hechas y pods con problemas
#   ./install.sh credentials     contraseñas del LDAP de laboratorio (explícito)
# Fases: 00 configure | 01 bootstrap | 02 ldap | 03 clusteradmin (manual guiado) | 04 properties | 05 generate | 06 deploy | 07 wait | 08 verify
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
PHASES=(00-configure 01-bootstrap 02-ldap 03-clusteradmin 04-properties 05-generate 06-deploy 07-wait 08-verify)
FROM=""; ONLY=""; FORCE=0; CMD="all"
while [ $# -gt 0 ]; do
  case "$1" in
    status|credentials|all) CMD="$1" ;;
    --from) FROM="$2"; shift ;;
    --only) ONLY="$2"; shift ;;
    --force) FORCE=1 ;;
    --yes|-y) export CP4BA_ASSUME_YES=1 ;;
    --non-interactive) export CP4BA_NONINTERACTIVE=1 CP4BA_ASSUME_YES=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "Argumento desconocido: $1"; exit 2 ;;
  esac; shift
done
if [ "$CMD" = status ]; then
  load_all_env; find_oc || die "No encuentro oc"
  for p in "${PHASES[@]}"; do if phase_done "$p"; then printf '  %s✔%s %s (%s)\n' "$C_G" "$C_0" "$p" "$(cat "$DONE_DIR/$p")"; else printf '  ·  %s\n' "$p"; fi; done
  oc_ get pods -n "$NS" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if ($3!="Completed" && (a[1]!=a[2]||$3!="Running")) print "  pod con problema:", $1, $2, $3}' || true
  exit 0
fi
if [ "$CMD" = credentials ]; then
  [ -f "$LDAP_SECRETS_FILE" ] || die "Aún no hay credenciales ($LDAP_SECRETS_FILE)."
  echo "Usuarios de prueba (LDAP) - NO compartas esta salida:"
  ( . "$LDAP_SECRETS_FILE"; echo "  cp4admin: $PW_CP4ADMIN"; echo "  alice   : $PW_ALICE"; echo "  bob     : $PW_BOB"; echo "  LDAP admin: $LDAP_ADMIN_PW" )
  exit 0
fi
started=0; PENDING=0
for p in "${PHASES[@]}"; do
  n="${p%%-*}"
  [ -n "$ONLY" ] && [ "$n" != "$ONLY" ] && continue
  if [ -n "$FROM" ] && [ "$started" = 0 ]; then [ "$n" = "$FROM" ] || continue; started=1; fi
  if [ "$FORCE" = 0 ] && phase_done "$p"; then ok "Fase $p ya completada (usa --force)"; continue; fi
  rc=0; bash "$ROOT/phases/$p.sh" || rc=$?
  if [ "$rc" -eq 10 ]; then warn "Fase $p pendiente de un paso manual."; PENDING=1; break; fi
  [ "$rc" -eq 0 ] || { err "La fase $p falló (código $rc). Corrige y repite ./install.sh (retoma donde quedó)."; exit "$rc"; }
done
[ "$PENDING" = 1 ] && exit 10
exit 0
