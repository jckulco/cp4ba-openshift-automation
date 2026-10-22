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
| Fases 05+ (generate, validate, despliegue, IA, prueba funcional) | pendientes | |
