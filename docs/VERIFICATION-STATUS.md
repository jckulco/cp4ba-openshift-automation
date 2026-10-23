# Estado de verificación

✅ ejecutado en el cluster · 🧪 probado offline · ⚠️ escrito pero nunca ejecutado

| Pieza | Estado | Notas |
|---|---|---|
| Validación de cluster y almacenamiento (a mano) | ✅ | OCP 4.21.24, PVC rbd y cephfs `Bound` |
| `cp4a-clusteradmin-setup.sh` (a mano, guiado) | ✅ | Operadores v26.0.2 en Succeeded |
| Fase 00 `configure` | ✅ | ejecutada en el cluster (OCP 4.21.24, 8 nodos Ready) |
| Fase 01 `bootstrap` | ⚠️ | los pasos equivalentes se hicieron a mano ✅ (helm 4.1.1, yq 4.54.1, skopeo, java 21) |
| Fase 02 `ldap` | ✅ | pod Running (1 reinicio en el primer arranque); 7 entradas con `ibm-entryUuid`; `cp4admin` se autentica |
| Fase 03 `clusteradmin` (comprobación) | ✅ | contra el cluster: detecta ibm-cp4a-operator.v26.0.2 Succeeded; también 🧪 con `oc` falso |
| `apply_retry`, `set_env` | 🧪 | |
| `cp4a-prerequisites.sh -m property` (a mano, guiado) | ✅ | archivos generados con las respuestas de SESSION-NOTES |
| Fase 04 `properties` + `tools/fill-properties.py` | 🧪 | probada offline con property files reconstruidos de la salida real; nunca ejecutada contra los archivos reales |
| `tools/test-wxai.py` | ⚠️ | nunca ejecutada |
| Fases 05-06 (generate, deploy) | ✅ a mano | CR generado y aplicado; ICP4ACluster Ready=True (~4 h). Los scripts de fase 05-08 siguen sin ejecutarse contra el cluster |
| Fases 07-08 (wait, verify) | ⚠️ | escritas, nunca ejecutadas; la heurística de 07 (❓) no se ha contrastado |
| Login Zen con Enterprise LDAP | ✅ | requiere `objectClass: person` y el workaround `tools/fix-zen-ldap-groups.sh` (no soportado por IBM) |
| Process Portal y BAStudio con cp4admin | ✅ | workflow automation de prueba creado y abierto |
| Inicialización de contenido FileNet | ❌ | dominio y object stores creados tras reiniciar CPE; falla `initProcessStore` (FNRPE2130660008E); probado sin efecto: memberOf en LDAP, reinicio de IM y CPE. Ver SESSION-NOTES |
| `tools/enable-ldap-memberof.sh`, `tools/repopulate-ldap-memberof.sh` | ✅ lab | ejecutados en el cluster; memberOf correcto; no resolvieron el FNRPE |
| Funciones de IA (watsonx.ai), MCP con OAuth, prueba funcional final | pendientes | `tools/test-wxai.py` nunca ejecutada |
