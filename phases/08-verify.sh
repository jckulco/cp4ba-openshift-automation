#!/usr/bin/env bash
# Fase 08: verificación posterior (solo lectura): URLs de acceso, pods de IA/MCP, ML Server (❓). No imprime secretos.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; source "$ROOT/lib/common.sh"
load_all_env; find_oc || die "No encuentro 'oc'."
title "Fase 08 - Verificación"
oc_ get cm icp4adeploy-cp4ba-access-info -n "$NS" -o jsonpath='{.data}' 2>/dev/null | tr ',' '\n' | grep -iE 'url|mcp' | grep -viE 'password|token' || warn "Sin ConfigMap de acceso todavía"
log "Pods de IA / MCP / ML (✔ si aparecen):"
oc_ get pods -n "$NS" --no-headers | grep -iE 'workflow-assistant|workplace|agent|mcp|baml|machine|opensearch|pfs' | awk '{print "  "$1" "$2" "$3}' || warn "ninguno encontrado"
oc_ get pods -n "$NS" --no-headers | grep -iqE 'baml|machine-learning' && warn "Hay pods de ML Server (baml): documentar en VERIFICATION-STATUS" || log "Sin pods de ML Server (esperado ❓)"
mark_done 08-verify
