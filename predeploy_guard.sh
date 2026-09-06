#!/bin/bash
# predeploy_guard.sh — rete di sicurezza della home di ticketto.it.
#
# Gira AUTOMATICAMENTE prima di ogni `firebase deploy` (hook "predeploy" in
# firebase.json), quindi protegge il sito anche se qualcuno salta
# ./deploy_landing.sh e lancia `firebase deploy` a mano.
#
# Due modi noti di rompere la home, entrambi silenziosi (build verde, deploy OK):
#  1. build/web/index.html esiste -> Firebase serve quel file statico e il
#     rewrite "/" -> /index_landing.html non scatta: su "/" compare l'app.
#  2. flutter_service_worker.js contiene la entry "/" -> il service worker
#     gia' installato nei browser risponde per "/" con la shell dell'app
#     tenuta in cache: l'utente vede il LOGIN al posto della landing.
# Qui li correggiamo prima di pubblicare; se non e' possibile, il deploy si ferma.

WEB="build/web"

if [ ! -d "$WEB" ]; then
  # niente build da controllare (es. deploy delle sole functions/rules):
  # lasciamo decidere a firebase, non blocchiamo.
  echo "ℹ️  [guard] $WEB non esiste, niente da controllare."
  exit 0
fi

# 1) la shell dell'app non deve chiamarsi index.html
if [ -f "$WEB/index.html" ]; then
  echo "⚠️  [guard] Trovato $WEB/index.html (shell dell'app): lo rinomino in app.html,"
  echo "           altrimenti '/' mostrerebbe l'app invece della landing."
  mv -f "$WEB/index.html" "$WEB/app.html" || exit 1
fi

# 2) i due file che reggono il routing devono esserci
for f in index_landing.html app.html; do
  if [ ! -f "$WEB/$f" ]; then
    echo "❌ [guard] Manca $WEB/$f. Deploy annullato per non rompere il sito."
    echo "           Rilancia: ./deploy_landing.sh --deploy"
    exit 1
  fi
done

# 3) la landing non deve essere per sbaglio la shell dell'app
if grep -q "flutter_bootstrap" "$WEB/index_landing.html"; then
  echo "❌ [guard] $WEB/index_landing.html sembra la shell Flutter, non la landing."
  echo "           Deploy annullato. Controlla web/index_landing.html nel repo."
  exit 1
fi

# 4) il service worker non deve tenere in cache la home (patch idempotente)
if [ -f "$WEB/flutter_service_worker.js" ]; then
  python3 fix_service_worker.py "$WEB/flutter_service_worker.js" || {
    echo "❌ [guard] Patch del service worker fallita: senza, i browser che hanno gia' aperto"
    echo "           l app servirebbero il login al posto della landing. Deploy annullato."
    exit 1; }
fi

# 5) niente file di backup pubblicati online
rm -f "$WEB"/*.bak

echo "✅ [guard] OK: '/' -> landing, app su /app.html, service worker pulito."
