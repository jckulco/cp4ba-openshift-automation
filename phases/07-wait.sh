#!/usr/bin/env bash
# Fase 07: espera a que el operador termine (FASE LARGA, estimación 1-3 h ❓). Reanudable: se puede repetir.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; source "$ROOT/lib/common.sh"
load_all_env; find_oc || die "No encuentro 'oc'."
title "Fase 07 - Espera del despliegue (larga; usa tmux)"
MAX="${CP4BA_WAIT_MIN:-240}"; t0=$(date +%s)
while :; do
  total=$(oc_ get pods -n "$NS" --no-headers 2>/dev/null | wc -l)
  bad=$(oc_ get pods -n "$NS" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if ($3!="Completed" && (a[1]!=a[2]||$3!="Running")) n++} END{print n+0}')
  log "$(date +%H:%M) pods=$total no_listos=$bad"
  oc_ get pods -n "$NS" --no-headers 2>/dev/null | awk '$3 ~ /ImagePullBackOff|ErrImagePull|CrashLoopBackOff|Error/ {print "  !! "$1" "$3}' | head -10
  # ❓ el campo exacto de estado de ICP4ACluster no está verificado: se usa también el ConfigMap de acceso (🔎 lo crea al final)
  if oc_ get cm icp4adeploy-cp4ba-access-info -n "$NS" >/dev/null 2>&1 && [ "$total" -gt 20 ] && [ "$bad" -eq 0 ]; then
    ok "Sin pods pendientes y con ConfigMap de acceso."; mark_done 07-wait; exit 0; fi
  [ $(( ($(date +%s)-t0)/60 )) -lt "$MAX" ] || { warn "Pasaron $MAX min. Revisa: tools/status.sh y logs del operador."; exit 1; }
  sleep 120
done
