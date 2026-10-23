# Notas de la sesión de referencia (CP4BA 26.0.0 IF002 en TechZone)

Leyenda: ✅ ejecutado en el cluster · 📄 leído en documentación IBM · 🔎 leído en el código del repo `cert-kubernetes` · ❓ no verificado

## Ambiente
- OpenShift 4.21.24, 3 masters (8 vCPU/32 GB) + 5 workers (32 vCPU/128 GB). ✅
- ODF en modo **externo**; StorageClasses `ocs-storagecluster-ceph-rbd` (default, RWO) y `ocs-storagecluster-cephfs` (RWX) aprovisionan ✅ (PVC de prueba).
- Bastión RHEL 9: 2 vCPU / 7 GB RAM / 284 GB disco. Ajustado si se cargan imágenes grandes con podman.
- TechZone ya instala `external-secrets-operator`, `itz-deployer-operator` y `openshift-pipelines` ✅ (no son de IBM CP4BA).

## Versión
- 📄 IF001 (jul-2026) e IF002 (ago-2026) existen; IF002 sustituye a todas. Repo: `git clone -b 26.0.0-IF002 https://github.com/icp4a/cert-kubernetes.git` ✅ (commit 0740107).
- ✅ Operadores instalados en `cp4ba` a **26.0.2** (CPFS 4.19.2), canal v26.0, aprobación Automatic.
- 📄 Instalación nueva: namespace sin CPFS previo. "All namespaces" deprecado.
- 📄 Defectos de IF002 relevantes: DT498940 (instalador falla con IdP externo sin LDAP → usamos LDAP), DT499473 (validación de prefijo de alias de BD en `generate`), DT496592 (PostgreSQL SCRAM channel binding en Workflow).
- ✅ La entitlement key cubre `cp.icr.io/cp/cp4a` (skopeo list-tags).

## Respuestas dadas a `cp4a-clusteradmin-setup.sh` ✅
Licencia: la aceptó el usuario · Online · OCP (Private Cloud) · Production · FIPS check: No · catálogo privado: Yes · separar operadores/operandos: No · namespace `cp4ba` · key: Yes (pegada en el prompt) · el script no pidió StorageClasses (las pide después `cp4a-deployment.sh`).
Instaló: IBM Cert Manager 4.2.23, Licensing 4.2.24, operadores v26.0.2 (cp4a, content, workflow, wfps, pfs, ads, odm, dpe, insights engine, ccx-ai-services, foundation), Redis 1.3.1, Usage Metering 1.0.7.

## Flujo de IBM (🔎 código de los scripts)
1. `cp4a-clusteradmin-setup.sh` (interactivo) ✅
2. `cp4a-prerequisites.sh -m property -n cp4ba` → editar properties → `-m generate` → crear BD/secretos → `-m validate`
3. `cp4a-deployment.sh -n cp4ba` (interactivo; sin modo silencioso; `-m` solo para upgrade). Genera el CR.
- Mismo patrón que Content Cortex: **no repetir `generate` una vez creadas BD con contraseñas generadas**.

## Base de datos 🔎
- `DB_TYPE=postgresql-edb` = PostgreSQL gestionado por el operador (CNPG desde 26.0.0 IF001 según el PDF de compatibilidad). Es la opción embebida recomendada. ❓ confirmar en el menú.
- 📄 Quien usa PostgreSQL externo no puede migrar después al embebido.

## IA en BAW 🔎 (componentes opcionales de Workflow Authoring, producción)
| Menú | Clave en el CR | Notas |
|---|---|---|
| Workplace Assistant | `workplace_assistant` | agente para usuarios; comparte `workflow_assistant_configuration` (watsonx) |
| (Preview) Authoring Assistant | `workflow_assistant` | **Preview** |
| Workflow Runtime MCP Server | `workflow_runtime_mcp_server` | exige `pfs`; con PFS+MCP exige OpenSearch; 📄 endpoints `/process/mcp` y `/case/mcp`, OAuth 2.1 |
| Data Collector and Data Indexer | `pfs` | |
- Propiedades `WFA.*`: `WATSONX_URL`, `WATSONX_API_KEY`, **`WATSONX_PROJECT_ID`**, `WATSONX_USERNAME/PASSWORD/TOKEN/VERSION`, `RUN_WORKPLACE_AGENT`, `RUN_AUTHORING_AGENT`, `WATSONX_MODEL_ID`, `WATSONX_DEPLOYMENT_ID`. ❓ Se necesita un *proyecto* de watsonx.ai (no el deployment space de Content Cortex).
- Machine Learning Server: CRD `businessautomationmachinelearnings` (campos `intelligent_task_prioritization`, `workforce_insights`) y no aparece en el menú de componentes. ❓ cómo se activa.
- AI Agent Server (M142FML): ❓ sin rastro en el repo. No se descargó nada de Passport Advantage.
- Autoría añade `cmis` (FileNet/CPE) automáticamente → aplica la lección del GUID de LDAP.

## LDAP de laboratorio
OpenLDAP (osixia) en `cp4ba-ldap`; usuarios `cp4admin`, `alice` (autora), `bob`; grupos `cp4admins`, `tw_admins`, `tw_authors`, `bawusers`. Contraseñas en `.state/ldap-secrets.env`. Los nombres de grupo se ajustarán cuando veamos los property files reales. SOLO laboratorio.

## Respuestas a `cp4a-prerequisites.sh -m property` ✅
Capacidad: 5a Workflow Authoring (solo) · opcionales: 3 Data Collector and Data Indexer, 5 Workplace Assistant, 6 (Preview) Authoring Assistant, 7 Workflow Runtime MCP Server · watsonx.ai: IBM SaaS (la otra opción es Lightweight Engine) · LDAP: IBM Tivoli/Security Directory Server · StorageClasses: cephfs (slow/medium/fast), rbd (Zen) · perfil small · BD: IBM Cloud Native Postgres (operador) · Vault: No · network policies: No · Instana: No · certificado externo OpenSearch/Kafka: No · Content Cortex AI Services: No.
- ⚠️ La pantalla mezcló lo escrito y el primer valor de StorageClass quedó truncado (`ocs-storagecluster-ceph`): **siempre revisar los property files** (la fase 04 lo corrige).
- ⚠️ IBM generó una misma contraseña para todas las BD y se vio en el chat → la fase 04 las rota por otras únicas antes de `generate`.

## Property files (🔎 contenido leído)
- Seis BD con el operador: gcddb, bawdocs, bawdos, bawtos, icndb, basdb (usuarios gcduser, osuser ×3, icnuser, basuser). Servidor `postgres-cp4ba-rw.{{ meta.namespace }}.svc` lo resuelve el operador.
- Licencias (📄 comentarios de IBM): CP4BA `non-production|production`; Content Cortex `user, concurrent-user, authorized-user, non-production, production`; BAW `concurrent-user, authorized-user, non-production, production`. **Decisión del usuario.**
- LDAP: `LDAP_SSL_ENABLED` viene en True → False (OpenLDAP sin TLS). Contraseñas: texto plano si no tienen caracteres especiales; `{Base64}` si los tienen (📄).
- Watsonx.ai SaaS: `WFA.WATSONX_API_KEY/URL/PROJECT_ID`; modelo opcional, **por defecto meta-llama/llama-3-3-70b-instruct** (📄). ❓ ese modelo puede estar obsoleto en la región: `tools/test-wxai.py` lo comprueba. Con modelo propio (gpt-oss-120b) ❓ no probado con el asistente. Solo existe `RUNTIME_AGENT_WATSONX_DEPLOYMENT_ID` (para despliegue personalizado).
- Juicios míos sin verificar: `LC_USER_FILTER` por `uid`; SCIM de grupos a `groupOfNames/member`; grupos de workflow admin/config = `cp4admins`; conexión PE `pe_conn_bawtos`. `SCIM.USER_GROUPS_ATTRIBUTE=memberOf` necesita el overlay memberOf de OpenLDAP (❓ puede no estar activo).
- IBM pide guardar estos archivos tras el despliegue (se usan en upgrades y al añadir/quitar componentes).

## Primer `generate` (✅ ejecutado; falló en la validación previa)
- IBM exige `CONTENT.LTPA_PASSWORD` == `BAN.LTPA_PASSWORD` (se igualan también los keystore por prudencia ❓). La fase 04 original los generaba distintos → corregido en `fill-properties.py`.
- ⚠️ La validación de IBM **imprime los valores** cuando falla: no pegar al chat la salida de `generate`/`validate` sin revisarla. (Las dos LTPA de esa corrida se expusieron y se rotaron.)
- Con `postgresql-edb` IBM omite la validación de certificados de BD; con LDAP sin SSL omite la del LDAP.

## Despliegue (✅ ejecutado en el cluster, 2026-10-22)
- `validate`: almacenamiento y 5 secretos PASSED. LDAP falla desde el bastión (DNS interno); ✅ con `oc port-forward svc/openldap 13389:389` + LdapTest.jar el bind funciona. ⚠️ el puerto 3389 lo ocupa RDP en el bastión.
- `cp4a-deployment.sh -n cp4ba` valida el LDAP desde el bastión y **aborta** si no resuelve: solución temporal ✅ = `/etc/hosts` (127.0.0.1 -> nombre interno) + `oc port-forward svc/openldap 389:389`; limpiar después.
- Respuestas: Content CR No · Production · OCP (cluster BareMetal) · AWS/Azure No · cpadmin Yes · JDBC vacío · resumen Yes. El script solo GENERA el CR; se aplica con `oc apply -f .../generated-cr/project/cp4ba/ibm_cp4a_cr_final.yaml`.
- CR 🔎: ICP4ACluster `icp4adeploy`; sc_optional_components = baw_authoring,cmis,pfs,workflow_assistant,workflow_runtime_mcp_server,workplace_assistant,opensearch (IBM añadió opensearch). Incluye `baml_configuration` (esqueleto de ML Server; sus funciones requieren BAI, que no está) ❓ efecto real: ver pods tras el despliegue.
- CR aplicado a las 16:36 (hora CDMX). Copia original en /opt/cp4ba/logs/cr-final-original.yaml.

## Login Enterprise LDAP en Zen (✅ diagnosticado en el cluster)
- Síntoma: `Internal Server Error` en `/auth/login/oidc/callback` tras elegir Enterprise LDAP. cpadmin (IBM provided credentials) entra bien.
- Logs 🔎: `CWWKS1620E ... Entity incompatible with PersonAccount` (platform-auth-service) y `userId cannot be an array or an object` (platform-identity-provider).
- Causa: IM mapea `PersonAccount` a objectClass `person` (leído en la config Liberty) pero OpenLDAP no devuelve las clases padre y las entradas solo tenían `inetOrgPerson`.
- Arreglo: añadir `objectClass: person` explícito a cp4admin/alice/bob (ldapmodify) y en `deploy-ldap.sh` para instalaciones nuevas. ❓ Resultado del login tras el arreglo: pendiente de confirmar.
- Mi primera hipótesis (ePerson de TDS) era incorrecta.

## Login LDAP en Zen: causa raíz del 401 (✅ resuelto en el cluster, 2026-10-22)
Cadena de síntomas y qué resultó ser cada cosa:
1. `Internal Server Error` en `/auth/login/oidc/callback` (`CWWKS1620E Entity incompatible with PersonAccount`): IM mapea `PersonAccount` a objectClass `person` y OpenLDAP no devuelve clases padre; se añadió `objectClass: person` a los usuarios (✅ cambió el error; ya en `deploy-ldap.sh`).
2. `401 unauthorized_error` (`/auth/login/sso/error`): 🔎 código de usermgmt (`syncNewUserWithBedrock`): un usuario nuevo sin grupo de Zen enlazado a su grupo LDAP se rechaza. La comparación (`ldapGroupsToUserGroups`) es literal: el usuario trae el **DN** (`cn=cp4admins,ou=groups,...`, de SCIM `groups[].value`) y la interfaz guarda como clave el **UUID** del grupo en `user_group_membership_rules`.
3. Arreglo: cambiar la clave a DN (`tools/fix-zen-ldap-groups.sh`). **No soportado por IBM; solo laboratorio.** ✅ cp4admin entra tras el cambio.
- Falsas pistas (no eran la causa): roles del grupo, recrear el usuario, reiniciar platform-auth-service, `unauthorized_error` en el identity-provider, el 404 "user not found in zen instances" (es "nothing to do").
- Error mío: el `[]` de "User groups that user should be a member of" solo refleja reglas por atributos, no grupos LDAP.
- Procedimiento por cada grupo LDAP: en Zen (cpadmin) crear grupo asignado, añadir "Identity provider groups", asignar roles, y después ejecutar `tools/fix-zen-ldap-groups.sh`.
- LOG_LEVEL de usermgmt se subió temporalmente a debug/silly y se revirtió a `warn`.

## Inicialización de contenido (FileNet/CPE): bloqueada (investigado en el cluster, 2026-10-22/23)
Estado: ❌ sin resolver. BAStudio y Process Portal funcionan con cp4admin; Case Builder, repositorios de Navigator y el contenido de documentos NO.
- Síntoma: Navigator sin repositorios (solo Admin Desktop), Case Builder "Content Platform Engine server is not available". Zen/BAStudio "current user didn't load properly" fue transitorio (se resolvió solo).
- ConfigMap `icp4adeploy-initialization-config` 🔎: `cpe_initialized=False`, `nav_initialized` pasó a True tras reiniciar CPE.
- Operador de contenido 🔎: falla la tarea `Create Content Process Engine P8 Domain` (fncm-cpe-ums-init.yaml:157) al instante; llama `POST /cpe/init/v1/domain`. CPE: `[CPERestAPI] Failure occurred fetching domain: P8DOMAIN` por `FNRCD0019E ... relation "fngcd" does not exist` (gcddb con 0 tablas). No hay tarea previa que prepare el GCD.
- ✅ Tras reiniciar el pod de CPE una vez, el dominio se creó (gcddb: cpeservers, fngcd, fngcd_addon) y los tres object stores (bawdocs 89, bawdos 83, bawtos 105 tablas). Causa del primer fallo: ❓ desconocida (estado del primer arranque de CPE).
- Nuevo bloqueo, persistente: tarea `API POST call to Configure Workflow for Object Store` (BAWTOS) falla con `[FNRPE2130660008E] User "cp4admin" does not have permission to perform function` en `EJBPEUtils.checkAdminUserSecurity` (`EJB_rpc_initProcessStore.initializeRegion`, FFDC leído en el pod de CPE).
- Credencial que CPE ve para cp4admin 🔎: solo permisos de Zen como grupos (administrator, can_provision, manage_users, ... sign_in_only); NINGÚN grupo LDAP (no aparece cp4admins, que es el grupo admin/config del workflow en el CR).
- Hipótesis descartadas ✅: permisos de PostgreSQL (gcduser es dueño de gcddb, CREATE en public), tablespace bawtos_tbs (existe), timeout (falla en 2-4 s), identidad del login (CPE autentica a cp4admin con role Admin).
- Hipótesis probada sin efecto: `memberOf` en OpenLDAP. 🔎 El overlay memberof existía pero con `groupOfUniqueNames/uniqueMember` (defecto osixia); se cambió a `groupOfNames/member` y se repobló (`tools/repopulate-ldap-memberof.sh`): cp4admin tiene memberOf correcto. Tras eso, dos reinicios/ciclos del operador (≈25 min) siguen fallando igual. ❓ puede haber caché de IAM no vencida; no se probó reiniciar IM.
- Pendiente: caso IBM con estos datos, o probar reiniciar platform-auth/identity-management y reintentar. El tablespace y el overlay quedan como están (reversibles: `enable-ldap-memberof.sh --remove`).
- Errores de procedimiento míos: pod de PostgreSQL embebido es `postgres-cp4ba-*` (no `postgresql-edb`); `zen-core-svc` escucha en 3443 (no 4000).
