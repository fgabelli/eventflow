#!/bin/bash
# deploy_landing.sh — Builds Flutter web and swaps index.html with landing page
# Usage: ./deploy_landing.sh [--deploy]
set -e

echo "🔨 Building Flutter web..."
flutter build web --release

echo "📄 Moving Flutter shell to app.html (root '/' is served via firebase rewrite → /index_landing.html)..."
# Flutter app shell -> app.html, and REMOVE build/web/index.html so that the
# firebase rewrite "/" -> "/index_landing.html" takes effect (no index.html to shadow it).
# index_landing.html is already copied into build/web/ by `flutter build web` (it lives in web/).
mv build/web/index.html build/web/app.html

echo "✅ Flutter app at build/web/app.html · landing served at '/' via rewrite (build/web/index_landing.html)"

# Update the landing page links to point to /app.html for login

if [ "$1" = "--deploy" ]; then
  echo "🚀 Deploying to Firebase Hosting..."
  firebase deploy --only hosting
  echo "✅ Deployed!"
else
  echo "ℹ️  Run with --deploy to deploy to Firebase Hosting"
fi
