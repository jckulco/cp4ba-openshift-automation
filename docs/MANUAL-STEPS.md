# Pasos manuales (borrador)
1. Aceptar la licencia de IBM en `cp4a-clusteradmin-setup.sh` (decisión tuya).
2. Responder los menús de `cp4a-prerequisites.sh -m property` y `cp4a-deployment.sh` (ver SESSION-NOTES).
3. watsonx.ai: crear un **proyecto** con el servicio Runtime asociado y tu Service ID como colaborador; anotar su Project ID. (❓ confirmar con los property files `WFA.*`).
4. Pendiente: pasos posteriores al despliegue (usuarios/roles en Zen, activar agentes, prueba funcional).

## Despliegue (fases 05-06)
1. Túnel LDAP temporal para `cp4a-deployment.sh` (ver SESSION-NOTES) y limpiar `/etc/hosts` al terminar.
2. Revisar el CR antes de aplicar; la licencia la acepta quien ejecuta (nunca el instalador).
3. Espera larga (fase 07), en tmux.
