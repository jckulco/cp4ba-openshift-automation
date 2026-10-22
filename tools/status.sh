#!/usr/bin/env bash
# Estado rápido: CSV, CRs de CP4BA y pods no listos (incluye 0/1 Running). Uso: NS=cp4ba tools/status.sh
OC="${OC:-oc}"; NS="${NS:-cp4ba}"
echo "== CSV";  $OC get csv -n "$NS" -o custom-columns=NAME:.metadata.name,VER:.spec.version,PHASE:.status.phase 2>/dev/null
echo "== CRs";  $OC get icp4acluster,content,foundation,workflowauthoring -n "$NS" 2>/dev/null
echo "== Pods no listos"; $OC get pods -n "$NS" --no-headers 2>/dev/null | awk '{split($2,a,"/"); if ($3!="Completed" && (a[1]!=a[2]||$3!="Running")) print}'
echo "== PVC pendientes"; $OC get pvc -n "$NS" --no-headers 2>/dev/null | awk '$2!="Bound"'
