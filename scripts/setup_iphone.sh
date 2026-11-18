#!/bin/sh
# Zet RIVO klaar voor je eigen iPhone.
# Gebruik: scripts/setup_iphone.sh TEAM_ID eigen.bundle.id
# TEAM_ID: Xcode → Settings → Accounts → je team (10 tekens), of Signing & Capabilities.
set -e
if [ $# -ne 2 ]; then
  echo "Gebruik: $0 TEAM_ID eigen.bundle.id   (bijvoorbeeld: $0 AB12CD34EF nl.jouwnaam.powerup)"
  exit 1
fi
# Team-ID: precies 10 hoofdletters/cijfers (staat in Xcode → Settings → Accounts).
if ! printf '%s' "$1" | grep -Eq '^[A-Z0-9]{10}$'; then
  echo "\"$1\" is geen team-ID. Die bestaat uit 10 hoofdletters en cijfers, bijvoorbeeld AB12CD34EF."
  echo "Voeg eerst je Apple ID toe in Xcode → Settings → Accounts; daar staat je team-ID."
  exit 1
fi
case "$2" in
  com.example.*|*jouwnaam*) echo "Kies een eigen bundle-ID, bijvoorbeeld nl.okan.rivo (niet de voorbeeldwaarde)."; exit 1 ;;
esac
if ! printf '%s' "$2" | grep -Eq '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$'; then
  echo "\"$2\" is geen geldige bundle-ID. Gebruik iets als nl.okan.rivo."
  exit 1
fi
cd "$(dirname "$0")/.."
cat > Config/Signing.local.xcconfig <<CONFIG
BUNDLE_ID_BASE = $2
DEVELOPMENT_TEAM = $1
CONFIG
xcodegen generate
echo "Klaar. Open PowerUp.xcodeproj, kies je iPhone bovenin en druk op Run."
