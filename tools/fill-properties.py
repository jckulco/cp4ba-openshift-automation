#!/usr/bin/env python3
"""Rellena los property files de cp4a-prerequisites.sh (formato CLAVE="valor") sin imprimir NUNCA los valores.

Uso:  fill-properties.py DIRECTORIO_PROPERTYFILE
Todos los valores llegan por VARIABLES DE ENTORNO (nunca por argumentos, para que no aparezcan en `ps`):
  FILE_SC BLOCK_SC LDAP_HOST LDAP_PORT LDAP_BASE_DN LDAP_ADMIN_PW PW_CP4ADMIN
  PW_DB_GCD PW_DB_OS PW_DB_ICN PW_DB_BAS LTPA_CONTENT KS_CONTENT LTPA_BAN KS_BAN
  LIC_CP4BA LIC_CONTENT_CORTEX LIC_BAW WXAI_API_KEY WXAI_URL WXAI_PROJECT_ID [WXAI_MODEL_ID]
Reglas de IBM: valores entre comillas dobles; usuarios/contraseñas sin comilla simple; LDAP/perfil sin comilla doble.
Solo sustituye claves que YA existen (si IBM cambia el formato, falla con código 3 en vez de inventar claves).
Código de salida: 0 ok · 2 falta una variable · 3 clave inexistente · 4 valor con caracteres no permitidos · 5 (--check) quedan <Required>.
"""
import os
import re
import sys

KEY_RE = re.compile(r'^([A-Za-z0-9_.\-]+)=(.*)$')


def env(name, required=True):
    v = os.environ.get(name, "")
    if required and not v:
        print("Falta la variable de entorno %s" % name, file=sys.stderr)
        sys.exit(2)
    return v


def plan():
    """Devuelve {archivo: {clave: valor}}."""
    base = env("LDAP_BASE_DN")
    admin, admin_grp = "cp4admin", "cp4admins"
    pw = env("PW_CP4ADMIN")
    prof = {
        "CP4BA.CP4BA_LICENSE": env("LIC_CP4BA"),
        "CP4BA.CONTENT_CORTEX_LICENSE": env("LIC_CONTENT_CORTEX"),
        "CP4BA.BAW_LICENSE": env("LIC_BAW"),
        "CP4BA.SLOW_FILE_STORAGE_CLASSNAME": env("FILE_SC"),
        "CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME": env("FILE_SC"),
        "CP4BA.FAST_FILE_STORAGE_CLASSNAME": env("FILE_SC"),
        "CP4BA.BLOCK_STORAGE_CLASS_NAME": env("BLOCK_SC"),
        "CONTENT.APPLOGIN_USER": admin, "CONTENT.APPLOGIN_PASSWORD": pw,
        "CONTENT.LTPA_PASSWORD": env("LTPA_CONTENT"), "CONTENT.KEYSTORE_PASSWORD": env("KS_CONTENT"),
        "CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME": admin,
        "CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME": admin_grp,
        "CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS": "%s,%s" % (admin, admin_grp),
        "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP": admin_grp,
        "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP": admin_grp,
        "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME": "pe_conn_bawtos",
        "BAN.APPLOGIN_USER": admin, "BAN.APPLOGIN_PASSWORD": pw,
        "BAN.LTPA_PASSWORD": env("LTPA_BAN"), "BAN.KEYSTORE_PASSWORD": env("KS_BAN"),
        "WFA.WATSONX_API_KEY": env("WXAI_API_KEY"),
        "WFA.WATSONX_URL": env("WXAI_URL"),
        "WFA.WATSONX_PROJECT_ID": env("WXAI_PROJECT_ID"),
        "BASTUDIO.ADMIN_USER": admin,
        # el grupo de OpenLDAP es groupOfNames/member (el perfil trae groupOfUniqueNames/uniqueMember)
        "SCIM.GROUP_OBJECT_CLASS_ATTRIBUTE": "groupOfNames",
        "SCIM.GROUP_MEMBERS_ATTRIBUTE": "member",
    }
    if env("WXAI_MODEL_ID", False):
        prof["WFA.WATSONX_MODEL_ID"] = env("WXAI_MODEL_ID", False)
    ldap = {
        "LDAP_SERVER": env("LDAP_HOST"), "LDAP_PORT": env("LDAP_PORT"), "LDAP_BASE_DN": base,
        "LDAP_BIND_DN": "cn=admin," + base, "LDAP_BIND_DN_PASSWORD": env("LDAP_ADMIN_PW"),
        "LDAP_SSL_ENABLED": "False",                       # el OpenLDAP de laboratorio no usa TLS
        "LDAP_GROUP_BASE_DN": "ou=groups," + base,
        "LC_USER_FILTER": "(&(uid=%v)(objectclass=person))",  # los usuarios se identifican por uid, no por cn
    }
    pre = "postgresql-edb."
    dbs = {
        pre + "GCD_DB_USER_PASSWORD": env("PW_DB_GCD"),
        pre + "BAWDOCS_DB_USER_PASSWORD": env("PW_DB_OS"),   # los tres object stores comparten el usuario osuser
        pre + "BAWDOS_DB_USER_PASSWORD": env("PW_DB_OS"),
        pre + "BAWTOS_DB_USER_PASSWORD": env("PW_DB_OS"),
        pre + "ICN_DB_USER_PASSWORD": env("PW_DB_ICN"),
        pre + "STUDIO_DB_USER_PASSWORD": env("PW_DB_BAS"),
    }
    return {"cp4ba_user_profile.property": prof, "cp4ba_LDAP.property": ldap, "cp4ba_db_name_user.property": dbs}


def check_chars(fname, key, val):
    if "'" in val and ("PASSWORD" in key or "USER" in key):
        return "comilla simple no permitida"
    if '"' in val and fname in ("cp4ba_LDAP.property", "cp4ba_user_profile.property"):
        return "comilla doble no permitida"
    return None


def apply(path, changes):
    lines = open(path, encoding="utf-8").read().split("\n")
    seen = set()
    for i, line in enumerate(lines):
        m = KEY_RE.match(line)
        if m and m.group(1) in changes:
            lines[i] = '%s="%s"' % (m.group(1), changes[m.group(1)])
            seen.add(m.group(1))
    missing = sorted(set(changes) - seen)
    if missing:
        print("%s: claves que no existen en el archivo: %s" % (os.path.basename(path), ", ".join(missing)), file=sys.stderr)
        sys.exit(3)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return sorted(seen)


def pending(propdir):
    out = []
    for fn in sorted(os.listdir(propdir)):
        if not fn.endswith(".property"):
            continue
        for line in open(os.path.join(propdir, fn), encoding="utf-8"):
            m = KEY_RE.match(line.rstrip("\n"))
            if m and "<Required>" in m.group(2):
                out.append("%s: %s" % (fn, m.group(1)))
    return out


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    if len(args) != 1 or not os.path.isdir(args[0]):
        sys.exit(__doc__)
    propdir = args[0]
    if "--check" in sys.argv:
        p = pending(propdir)
        for x in p:
            print("pendiente:", x)
        sys.exit(5 if p else 0)
    pl = plan()
    for fn, ch in pl.items():
        for k, v in ch.items():
            why = check_chars(fn, k, v)
            if why:
                print("%s %s: %s" % (fn, k, why), file=sys.stderr)
                sys.exit(4)
    for fn, ch in pl.items():
        keys = apply(os.path.join(propdir, fn), ch)
        print("%s: %d claves actualizadas" % (fn, len(keys)))
    p = pending(propdir)
    if p:
        print("Aún quedan <Required> (no se rellenan automáticamente):")
        for x in p:
            print("  -", x)


if __name__ == "__main__":
    main()
