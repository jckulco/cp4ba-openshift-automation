#!/usr/bin/env bash
# Despliega un OpenLDAP de LABORATORIO en OpenShift para CP4BA (sin Keycloak: IF002 exige LDAP, ver docs/SESSION-NOTES.md).
# Uso (oc con sesión de cluster-admin):   OC=oc LDAP_NS=cp4ba-ldap bash tools/deploy-ldap.sh
# Genera contraseñas en .state/ldap-secrets.env (chmod 600). No las pegues en ningún chat. Es idempotente.
set -euo pipefail
OC="${OC:-oc}"
LDAP_NS="${LDAP_NS:-cp4ba-ldap}"
LDAP_IMAGE="${LDAP_IMAGE:-docker.io/osixia/openldap:1.5.0}"
BASE_DN="${BASE_DN:-dc=example,dc=org}"
STATE_DIR="${CP4BA_STATE_DIR:-$(cd "$(dirname "$0")/.." && pwd)/.state}"
mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
SECRETS_FILE="$STATE_DIR/ldap-secrets.env"
gen() { openssl rand -base64 18 | tr -d '=+/' | cut -c1-16; }

$OC whoami >/dev/null || { echo "ERROR: sin sesión de oc" >&2; exit 1; }

if [[ -f "$SECRETS_FILE" ]]; then
  echo ">> Reutilizando contraseñas de $SECRETS_FILE"
  # shellcheck disable=SC1090
  source "$SECRETS_FILE"
else
  LDAP_ADMIN_PW="$(gen)"; PW_CP4ADMIN="$(gen)"; PW_ALICE="$(gen)"; PW_BOB="$(gen)"
  ( umask 077; cat > "$SECRETS_FILE" <<EOS
LDAP_ADMIN_PW='${LDAP_ADMIN_PW}'
PW_CP4ADMIN='${PW_CP4ADMIN}'
PW_ALICE='${PW_ALICE}'
PW_BOB='${PW_BOB}'
EOS
  )
  chmod 600 "$SECRETS_FILE"
  echo ">> Contraseñas guardadas en $SECRETS_FILE (chmod 600)"
fi

$OC get ns "$LDAP_NS" >/dev/null 2>&1 || $OC create namespace "$LDAP_NS"
$OC -n "$LDAP_NS" create serviceaccount openldap --dry-run=client -o yaml | $OC apply -f -
# osixia/openldap necesita root: se permite SOLO a esta cuenta de servicio
$OC adm policy add-scc-to-user anyuid -z openldap -n "$LDAP_NS"
$OC -n "$LDAP_NS" create secret generic ldap-admin --from-literal=password="$LDAP_ADMIN_PW" --dry-run=client -o yaml | $OC apply -f -

# Usuarios: cp4admin (administrador), alice (autora), bob (usuario).  Grupos: cp4admins, tw_admins, tw_authors, bawusers.
cat <<EOF2 | $OC -n "$LDAP_NS" apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ldap-seed
data:
  50-seed.ldif: |
    dn: ou=users,${BASE_DN}
    objectClass: organizationalUnit
    ou: users

    dn: ou=groups,${BASE_DN}
    objectClass: organizationalUnit
    ou: groups

    dn: uid=cp4admin,ou=users,${BASE_DN}
    objectClass: inetOrgPerson
    uid: cp4admin
    cn: CP4BA Admin
    sn: Admin
    mail: cp4admin@example.org
    userPassword: ${PW_CP4ADMIN}

    dn: uid=alice,ou=users,${BASE_DN}
    objectClass: inetOrgPerson
    uid: alice
    cn: Alice Author
    sn: Author
    mail: alice@example.org
    userPassword: ${PW_ALICE}

    dn: uid=bob,ou=users,${BASE_DN}
    objectClass: inetOrgPerson
    uid: bob
    cn: Bob User
    sn: User
    mail: bob@example.org
    userPassword: ${PW_BOB}

    dn: cn=cp4admins,ou=groups,${BASE_DN}
    objectClass: groupOfNames
    cn: cp4admins
    member: uid=cp4admin,ou=users,${BASE_DN}

    dn: cn=tw_admins,ou=groups,${BASE_DN}
    objectClass: groupOfNames
    cn: tw_admins
    member: uid=cp4admin,ou=users,${BASE_DN}

    dn: cn=tw_authors,ou=groups,${BASE_DN}
    objectClass: groupOfNames
    cn: tw_authors
    member: uid=cp4admin,ou=users,${BASE_DN}
    member: uid=alice,ou=users,${BASE_DN}

    dn: cn=bawusers,ou=groups,${BASE_DN}
    objectClass: groupOfNames
    cn: bawusers
    member: uid=cp4admin,ou=users,${BASE_DN}
    member: uid=alice,ou=users,${BASE_DN}
    member: uid=bob,ou=users,${BASE_DN}
EOF2

cat <<EOF2 | $OC -n "$LDAP_NS" apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: ldap-data}
spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Gi}}}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: ldap-config}
spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Gi}}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: openldap}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: openldap}}
  template:
    metadata: {labels: {app: openldap}}
    spec:
      serviceAccountName: openldap
      containers:
        - name: openldap
          image: ${LDAP_IMAGE}
          args: ["--copy-service"]
          env:
            - {name: LDAP_ORGANISATION, value: "Example Org"}
            - {name: LDAP_DOMAIN, value: "example.org"}
            - {name: LDAP_TLS, value: "false"}
            - name: LDAP_ADMIN_PASSWORD
              valueFrom: {secretKeyRef: {name: ldap-admin, key: password}}
          ports: [{containerPort: 389, name: ldap}]
          readinessProbe: {tcpSocket: {port: 389}, initialDelaySeconds: 10, periodSeconds: 5}
          volumeMounts:
            - {name: data, mountPath: /var/lib/ldap}
            - {name: config, mountPath: /etc/ldap/slapd.d}
            - {name: seed, mountPath: /container/service/slapd/assets/config/bootstrap/ldif/custom}
      volumes:
        - {name: data, persistentVolumeClaim: {claimName: ldap-data}}
        - {name: config, persistentVolumeClaim: {claimName: ldap-config}}
        - {name: seed, configMap: {name: ldap-seed}}
---
apiVersion: v1
kind: Service
metadata: {name: openldap}
spec:
  selector: {app: openldap}
  ports: [{name: ldap, port: 389, targetPort: 389}]
EOF2
$OC -n "$LDAP_NS" rollout status deploy/openldap --timeout=300s
echo ">> OpenLDAP listo: ldap://openldap.${LDAP_NS}.svc.cluster.local:389  base ${BASE_DN}"
