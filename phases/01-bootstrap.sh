#!/usr/bin/env bash
# Fase 01: herramientas del bastión (RHEL 9) y repo de IBM (cert-kubernetes, tag IF002).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
load_all_env
find_oc || die "No encuentro 'oc'."
title "Fase 01 - Bootstrap del bastión"
HELM_VERSION="${HELM_VERSION:-v4.1.1}"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

missing=()
for c in git jq openssl curl unzip skopeo podman; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
command -v python3.12 >/dev/null 2>&1 || missing+=(python3.12 python3.12-pip)
command -v java >/dev/null 2>&1 || missing+=(java-21-openjdk-headless)   # cp4a-prerequisites.sh acepta --java-path
if [ "${#missing[@]}" -gt 0 ]; then
  mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
  log "Instalando paquetes: ${missing[*]}"
  command -v dnf >/dev/null 2>&1 || die "No hay dnf. Instala manualmente: ${missing[*]}"
  $SUDO dnf install -y "${missing[@]}"
fi
ok "paquetes base presentes"

helm_major() { helm version --template '{{.Version}}' 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }
if ! command -v helm >/dev/null 2>&1 || [ "$(helm_major || echo 0)" -lt 4 ]; then
  log "Instalando Helm $HELM_VERSION"
  T="$(mktemp -d)"; curl -fsSL -o "$T/helm.tgz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
  tar -xzf "$T/helm.tgz" -C "$T"; $SUDO install -m 0755 "$T/linux-amd64/helm" /usr/local/bin/helm; rm -rf "$T"; hash -r
fi
ok "helm $(helm version --template '{{.Version}}')"
if ! command -v yq >/dev/null 2>&1; then
  $SUDO curl -fsSL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && $SUDO chmod +x /usr/local/bin/yq
fi
ok "yq $(yq --version | awk '{print $NF}')"
command -v oc >/dev/null 2>&1 || { $SUDO ln -sf "$OC" /usr/local/bin/oc; }
command -v kubectl >/dev/null 2>&1 || $SUDO ln -sf /usr/local/bin/oc /usr/local/bin/kubectl

if [ ! -d "$IBM_DIR/.git" ]; then
  log "Clonando $IBM_REPO_URL (rama/tag $IBM_REPO_REF) en $IBM_DIR"
  git clone --depth 1 --branch "$IBM_REPO_REF" "$IBM_REPO_URL" "$IBM_DIR"
fi
branch="$(git -C "$IBM_DIR" branch --show-current 2>/dev/null || true)"
[ -n "$branch" ] || branch="$(git -C "$IBM_DIR" describe --tags 2>/dev/null || echo '?')"
[ "$branch" = "$IBM_REPO_REF" ] && ok "Repo de IBM en $branch" || warn "El repo de IBM está en '$branch', se esperaba '$IBM_REPO_REF'"
for s in cp4a-clusteradmin-setup.sh cp4a-prerequisites.sh cp4a-deployment.sh; do [ -f "$IBM_SCRIPTS/$s" ] || die "Falta $IBM_SCRIPTS/$s"; done
mark_done 01-bootstrap
