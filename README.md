# CP4BA 26.0.0 (IF002) + Business Automation Workflow con IA en OpenShift

Proyecto en construcción para preparar un taller de BAW con sus funciones de IA en un cluster de TechZone
(OpenShift 4.21, ODF). Estructura heredada del proyecto de Content Cortex: `install.sh`, fases idempotentes en `phases/`
(marcas en `.state/done`), `lib/common.sh`, `tools/`, `docs/` y `tests/`.

**Estado real:** fases 00–04 escritas; 03 solo comprueba (el script de IBM es interactivo). Ver `docs/VERIFICATION-STATUS.md`.
Las notas de la sesión, con lo verificado y lo no verificado, están en `docs/SESSION-NOTES.md`.

```bash
./install.sh status | ./install.sh --only 02 | bash tests/run-tests.sh
```
Secretos: solo en `.state/` (chmod 600), nunca en Git. La licencia de IBM la aceptas tú; el instalador no lo hace.
Scripts y docs: MIT. CP4BA y sus artefactos son de IBM.
