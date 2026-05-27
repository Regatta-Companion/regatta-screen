#!/bin/bash
# Regatta Screen — web update script
# Downloadt de nieuwste web bestanden van de GitHub release en zet ze klaar
# voor de webserver.
#
# Gebruik: sudo ./update.sh [/pad/naar/webroot]
#          (standaard webroot: /var/www/regatta-screen)
#
# Dit script:
# 1. Zoekt de nieuwste release tag op GitHub
# 2. Downloadt de web.zip van die release
# 3. Vervangt de web bestanden in de opgegeven map

set -euo pipefail

REPO="FutureCow/regatta-screen"
WEBROOT="${1:-/var/www/regatta-screen}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "📦 Regatta Screen — web update"
echo "   Repo: $REPO"
echo "   Webroot: $WEBROOT"
echo ""

# ── 1. Vind nieuwste release ───────────────────────────────────────────
echo "🔍 Zoeken naar nieuwste release..."
LATEST=$(curl -sf "https://api.github.com/repos/$REPO/releases/latest" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tag_name',''))" 2>/dev/null || true)

if [ -z "$LATEST" ]; then
  echo "❌ Kan nieuwste release niet vinden."
  echo "   Controleer of de repo $REPO bestaat en releases heeft."
  exit 1
fi
echo "   Nieuwste release: $LATEST"

# ── 2. Download web.zip ────────────────────────────────────────────────
echo "⬇️  Downloaden web.zip van $LATEST..."
ZIP_URL="https://github.com/$REPO/releases/download/$LATEST/web.zip"
ZIP_FILE="$TMPDIR/web.zip"

HTTP_CODE=$(curl -sfL -o "$ZIP_FILE" -w "%{http_code}" "$ZIP_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
  echo "⚠️  Geen web.zip in release $LATEST (HTTP $HTTP_CODE)"
  echo "   Fallback: git clone..."
  git clone --depth 1 --branch main "https://github.com/$REPO.git" "$TMPDIR/repo"
  SOURCE="$TMPDIR/repo/web"
else
  echo "   web.zip gedownload (HTTP $HTTP_CODE)"
  unzip -q -o "$ZIP_FILE" -d "$TMPDIR/extracted"
  SOURCE="$TMPDIR/extracted"
fi

# Controleer of de bron web bestanden bevat
if [ ! -f "$SOURCE/index.html" ]; then
  echo "❌ Geen index.html gevonden in de bron."
  echo "   Bron: $SOURCE"
  ls -la "$SOURCE/" 2>/dev/null || true
  exit 1
fi

# ── 3. Back-up van huidige webroot ─────────────────────────────────────
if [ -d "$WEBROOT" ]; then
  BACKUP="/tmp/regatta-screen-backup-$(date +%Y%m%d-%H%M%S)"
  echo "💾 Back-up maken naar $BACKUP..."
  cp -a "$WEBROOT" "$BACKUP"
fi

# ── 4. Web bestanden kopiëren ──────────────────────────────────────────
echo "📂 Web bestanden kopiëren naar $WEBROOT..."
mkdir -p "$WEBROOT"
cp -a "$SOURCE/"* "$WEBROOT/"

# ── 5. Controle ────────────────────────────────────────────────────────
echo "✅ Gereed! Bestanden in $WEBROOT:"
ls -lh "$WEBROOT/"*.html "$WEBROOT/css/"*.css "$WEBROOT/js/"*.js 2>/dev/null || \
  ls -lh "$WEBROOT/" 2>/dev/null

echo ""
echo "   🚀 Herstart je webserver om de wijzigingen door te voeren:"
echo "      sudo systemctl reload nginx   (of apache2)"
