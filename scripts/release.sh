#!/bin/bash
# scripts/release.sh — Publier une RELEASE stable vers Nexus
# Usage: ./scripts/release.sh <release-version> <next-snapshot-version>
# Exemple: ./scripts/release.sh 1.0.0 1.1.0-SNAPSHOT
#
# Prérequis : NEXUS_PASSWORD doit être défini dans l'environnement
#   export NEXUS_PASSWORD="<mot-de-passe>"

set -e

RELEASE_VERSION=${1:?"Usage: $0 <release-version> <next-snapshot-version>"}
NEXT_SNAPSHOT_VERSION=${2:?"Usage: $0 <release-version> <next-snapshot-version>"}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -z "$NEXUS_PASSWORD" ]]; then
  echo "ERREUR: la variable NEXUS_PASSWORD n'est pas définie."
  echo "  export NEXUS_PASSWORD='<mot-de-passe>'"
  exit 1
fi

echo "=== Publication de la RELEASE $RELEASE_VERSION ==="

cd "$PROJECT_ROOT/backend"

# 1. Passer de SNAPSHOT à RELEASE dans tous les pom.xml
mvn -s ../settings.xml versions:set \
    -DnewVersion="$RELEASE_VERSION" \
    -DgenerateBackupPoms=false

# 2. Build + deploy vers nexus-releases
#    Maven route automatiquement vers nexus-releases car la version ne contient pas -SNAPSHOT
mvn -s ../settings.xml clean deploy -DskipTests

# 3. Commit + tag git de la release
cd "$PROJECT_ROOT"
git add backend/pom.xml backend/user-service/pom.xml backend/product-service/pom.xml \
        backend/media-service/pom.xml backend/order-service/pom.xml
git commit -m "release: $RELEASE_VERSION"
git tag -a "v$RELEASE_VERSION" -m "Release $RELEASE_VERSION"

# 4. Passer à la prochaine version SNAPSHOT
cd "$PROJECT_ROOT/backend"
mvn -s ../settings.xml versions:set \
    -DnewVersion="$NEXT_SNAPSHOT_VERSION" \
    -DgenerateBackupPoms=false

cd "$PROJECT_ROOT"
git add backend/pom.xml backend/user-service/pom.xml backend/product-service/pom.xml \
        backend/media-service/pom.xml backend/order-service/pom.xml
git commit -m "chore: bump to $NEXT_SNAPSHOT_VERSION"

echo ""
echo "=== RELEASE $RELEASE_VERSION publiée dans Nexus (maven-releases) ==="
echo "=== Prochaine version de développement : $NEXT_SNAPSHOT_VERSION ==="