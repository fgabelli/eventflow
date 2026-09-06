#!/usr/bin/env python3
"""
fix_service_worker.py — toglie la home dal service worker Flutter.

Perche' serve:
`flutter build web` genera flutter_service_worker.js con, dentro RESOURCES,
la entry "/" che punta all'hash di index.html (= la shell dell'app Flutter).
Dopo lo swap index.html -> app.html il server serve correttamente la landing
su "/", ma il service worker installato nel browser continua a rispondere
per "/" con la copia dell'app tenuta in cache => l'utente vede il LOGIN
invece della landing (bug del 2026-09-06).

Rimuovendo "/" e "index.html" da RESOURCES:
 - il fetch handler non intercetta piu' "/" e lascia passare la richiesta
   alla rete (=> landing sempre fresca);
 - all'activate il service worker cancella dalla cache le risorse non piu'
   presenti nel manifest, quindi la vecchia home cachata sparisce da sola
   su tutti i browser che hanno gia' il service worker installato.
In CORE "index.html" viene sostituito da "app.html" cosi' la shell dell'app
resta pre-caricata come prima.

Lo script e' idempotente: rilanciarlo su un file gia' a posto non fa nulla.
Uso: python3 fix_service_worker.py [percorso/flutter_service_worker.js]
"""
import json
import re
import sys
from pathlib import Path

DROP_RESOURCES = ("/", "index.html")

sw = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web/flutter_service_worker.js")
if not sw.is_file():
    print("❌ file non trovato: %s" % sw)
    sys.exit(1)

src = sw.read_text()
orig = src

# --- RESOURCES: manifest delle risorse messe in cache ---------------------
m = re.search(r"const RESOURCES = (\{.*?\});", src, re.S)
if not m:
    print("❌ blocco RESOURCES non trovato in %s: formato del service worker cambiato." % sw)
    sys.exit(1)
try:
    resources = json.loads(m.group(1))
except ValueError as err:
    print("❌ RESOURCES non e' JSON valido (%s): formato del service worker cambiato." % err)
    sys.exit(1)

removed = [k for k in DROP_RESOURCES if k in resources]
for key in removed:
    del resources[key]
# stessa impaginazione di Flutter: una risorsa per riga
body = ",\n".join("%s: %s" % (json.dumps(k), json.dumps(v)) for k, v in resources.items())
src = src[:m.start()] + "const RESOURCES = {" + body + "};" + src[m.end():]

# --- CORE: file pre-caricati all'install ----------------------------------
c = re.search(r"const CORE = (\[.*?\]);", src, re.S)
if not c:
    print("❌ blocco CORE non trovato in %s: formato del service worker cambiato." % sw)
    sys.exit(1)
core = json.loads(c.group(1))
if "index.html" in core:
    core = ["app.html" if x == "index.html" else x for x in core]
    core = list(dict.fromkeys(core))  # niente doppioni se app.html c'era gia'
    src = src[:c.start()] + "const CORE = [" + ",\n".join(json.dumps(x) for x in core) + "];" + src[c.end():]

# --- verifica ------------------------------------------------------------
check = json.loads(re.search(r"const RESOURCES = (\{.*?\});", src, re.S).group(1))
still = [k for k in DROP_RESOURCES if k in check]
if still or "index.html" in json.loads(re.search(r"const CORE = (\[.*?\]);", src, re.S).group(1)):
    print("❌ patch incompleta, controllare %s (rimaste: %s)" % (sw, still))
    sys.exit(1)

if src == orig:
    print("✅ service worker gia' a posto (nessuna modifica necessaria)")
    sys.exit(0)

sw.write_text(src)
print("✅ service worker patchato: rimosse da RESOURCES %s, CORE -> app.html"
      % ", ".join(repr(k) for k in removed))
