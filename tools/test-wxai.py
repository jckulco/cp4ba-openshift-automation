#!/usr/bin/env python3
"""Prueba una API key de IBM Cloud contra un PROYECTO de watsonx.ai (el Workflow Assistant pide Project ID, no space).

  1) Lista los modelos de chat disponibles en la región (endpoint público) y dice si el modelo pedido está y si
     está retirado/obsoleto. IBM documenta como modelo por defecto del asistente meta-llama/llama-3-3-70b-instruct.
  2) Cambia la API key por un token IAM y muestra QUIÉN es (sin imprimir el token).
  3) Petición mínima de chat al proyecto.
La API key se lee de WXAI_API_KEY o se pide sin eco. No se guarda ni se imprime.
Uso: WXAI_URL=https://us-south.ml.cloud.ibm.com WXAI_PROJECT_ID=... WXAI_MODEL_ID=... python3 tools/test-wxai.py
Código de salida: 0 todo bien · 1 falló la petición al proyecto · 2 clave inválida
"""
import base64
import getpass
import json
import os
import urllib.error
import urllib.parse
import urllib.request


def http(url, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method or ("POST" if data else "GET"))
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        return "ERROR", repr(e)


def claims(token):
    try:
        p = token.split(".")[1]
        p += "=" * (-len(p) % 4)
        return json.loads(base64.urlsafe_b64decode(p))
    except Exception:  # noqa: BLE001
        return {}


def main():
    url = (os.environ.get("WXAI_URL") or input("URL de watsonx.ai [https://us-south.ml.cloud.ibm.com]: ").strip()
           or "https://us-south.ml.cloud.ibm.com").rstrip("/")
    project = os.environ.get("WXAI_PROJECT_ID") or input("Project ID: ").strip()
    model = os.environ.get("WXAI_MODEL_ID") or input("Modelo [meta-llama/llama-3-3-70b-instruct]: ").strip() or "meta-llama/llama-3-3-70b-instruct"
    key = os.environ.get("WXAI_API_KEY") or getpass.getpass("API key (no se muestra): ").strip()

    print("\n== 1) Modelos de chat en la región ==")
    st, txt = http(url + "/ml/v1/foundation_model_specs?version=2024-05-01&limit=200&filters=function_text_chat")
    if st == 200:
        res = json.loads(txt).get("resources", [])
        ids = {r["model_id"]: r for r in res}
        print("%d modelos de chat disponibles" % len(ids))
        r = ids.get(model)
        if not r:
            print("!! %s NO aparece en esta región. Algunos disponibles: %s" % (model, ", ".join(sorted(ids)[:12])))
        else:
            lc = [x.get("id") for x in (r.get("lifecycle") or [])]
            print("%s disponible; ciclo de vida: %s" % (model, ", ".join(str(x) for x in lc) or "n/d"))
            for x in r.get("lifecycle") or []:
                if x.get("id") in ("deprecated", "withdrawn"):
                    print("!! estado %s desde %s" % (x.get("id"), x.get("start_date")))
    else:
        print("No pude listar modelos (HTTP %s); se continúa." % st)

    print("\n== 2) Token IAM ==")
    st, txt = http("https://iam.cloud.ibm.com/identity/token",
                   urllib.parse.urlencode({"grant_type": "urn:ibm:params:oauth:grant-type:apikey", "apikey": key}).encode(),
                   {"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"})
    del key
    print("HTTP", st)
    if st != 200:
        print(txt[:300])
        raise SystemExit(2)
    token = json.loads(txt)["access_token"]
    c = claims(token)
    print("identidad (iam_id):", c.get("iam_id"))
    print("cuenta (bss):      ", (c.get("account") or {}).get("bss"))

    print("\n== 3) Petición mínima al proyecto ==")
    body = json.dumps({"model_id": model, "project_id": project, "max_tokens": 64,
                       "messages": [{"role": "user", "content": "Reply with the single word: OK"}]}).encode()
    st, txt = http(url + "/ml/v1/text/chat?version=2023-05-29", body,
                   {"Content-Type": "application/json", "Accept": "application/json", "Authorization": "Bearer " + token})
    print("HTTP", st)
    print(txt[:400])
    if st == 200:
        print("\nOK: la clave, el proyecto y el modelo funcionan.")
        raise SystemExit(0)
    if st == 403:
        print("\n403: esa identidad no tiene acceso al proyecto (añádela como colaborador del proyecto de watsonx.ai).")
    if st == 404:
        print("\n404: revisa el Project ID, la región o que el modelo exista en ella.")
    raise SystemExit(1)


if __name__ == "__main__":
    main()
