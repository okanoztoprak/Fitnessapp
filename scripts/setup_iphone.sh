#!/bin/sh
# Zet RIVO klaar voor je eigen iPhone.
# Gebruik: scripts/setup_iphone.sh TEAM_ID eigen.bundle.id
# TEAM_ID: Xcode → Settings → Accounts → je team (10 tekens), of Signing & Capabilities.
set -e
if [ $# -ne 2 ]; then
  echo "Gebruik: $0 TEAM_ID eigen.bundle.id   (bijvoorbeeld: $0 AB12CD34EF nl.jouwnaam.powerup)"
  exit 1
fi
case "$2" in
  com.example.*) echo "Kies een eigen bundle-ID, niet com.example."; exit 1 ;;
esac
cd "$(dirname "$0")/.."
cat > Config/Signing.local.xcconfig <<CONFIG
BUNDLE_ID_BASE = $2
DEVELOPMENT_TEAM = $1
CONFIG
xcodegen generate
echo "Klaar. Open PowerUp.xcodeproj, kies je iPhone bovenin en druk op Run."
