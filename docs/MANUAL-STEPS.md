# Pasos manuales (borrador)
1. Aceptar la licencia de IBM en `cp4a-clusteradmin-setup.sh` (decisión tuya).
2. Responder los menús de `cp4a-prerequisites.sh -m property` y `cp4a-deployment.sh` (ver SESSION-NOTES).
3. watsonx.ai: crear un **proyecto** con el servicio Runtime asociado y tu Service ID como colaborador; anotar su Project ID. (❓ confirmar con los property files `WFA.*`).
4. Pendiente: pasos posteriores al despliegue (usuarios/roles en Zen, activar agentes, prueba funcional).

## Despliegue (fases 05-06)
1. Túnel LDAP temporal para `cp4a-deployment.sh` (ver SESSION-NOTES) y limpiar `/etc/hosts` al terminar.
2. Revisar el CR antes de aplicar; la licencia la acepta quien ejecuta (nunca el instalador).
3. Espera larga (fase 07), en tmux.

## Enlazar grupos LDAP en Zen (workaround de laboratorio)
1. Zen como `cpadmin` -> Access control -> User groups -> New (Assigned) -> Users -> *Identity provider groups* -> elegir el grupo LDAP -> asignar roles.
2. En el bastión: `tools/fix-zen-ldap-groups.sh` (usa `--dry-run` para ver). Corrige la clave UUID -> DN. NO soportado por IBM.
3. Probar el login del usuario en ventana de incógnito.

## Si la inicialización de contenido falla (observado, no documentado por IBM)
1. `oc get cm icp4adeploy-initialization-config -n cp4ba -o jsonpath='{.data}'` debe terminar con `cpe_initialized: True`.
2. Si `gcddb` está vacío y el operador falla en `Create Content Process Engine P8 Domain` con `FNRCD0019E`: ❓ reiniciar una vez el pod de CPE (guardar antes sus logs) hizo que se creara el dominio. No es un procedimiento soportado.
3. Si falla `Configure Workflow for Object Store` con `FNRPE2130660008E`: sin resolver; abrir caso con IBM (ver SESSION-NOTES).
4. OpenLDAP del laboratorio: el overlay memberof de osixia viene para `groupOfUniqueNames`; los grupos del laboratorio son `groupOfNames`. `tools/repopulate-ldap-memberof.sh` lo corrige (laboratorio).
