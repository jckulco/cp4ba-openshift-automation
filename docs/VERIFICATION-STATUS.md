# Estado de verificación

✅ ejecutado en el cluster · 🧪 probado offline · ⚠️ escrito pero nunca ejecutado

| Pieza | Estado | Notas |
|---|---|---|
| Validación de cluster y almacenamiento (a mano) | ✅ | OCP 4.21.24, PVC rbd y cephfs `Bound` |
| `cp4a-clusteradmin-setup.sh` (a mano, guiado) | ✅ | Operadores v26.0.2 en Succeeded |
| Fase 00 `configure` | ⚠️ | |
| Fase 01 `bootstrap` | ⚠️ | los pasos equivalentes se hicieron a mano ✅ (helm 4.1.1, yq 4.54.1, skopeo, java 21) |
| Fase 02 `ldap` | ⚠️ | adaptada del proyecto anterior (`deploy-auth.sh`, ✅ allí) |
| Fase 03 `clusteradmin` (comprobación) | 🧪 | con `oc` falso |
| `apply_retry`, `set_env` | 🧪 | |
| Fases 04+ (prerequisitos, despliegue, IA, prueba funcional) | pendientes | |
