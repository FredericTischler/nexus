#!/bin/bash
# scripts/docker-push-nexus.sh — Build et push des images vers Nexus Docker registry
# Usage: ./scripts/docker-push-nexus.sh [version]
# Exemple: ./scripts/docker-push-nexus.sh 1.1.0-SNAPSHOT
#
# Prérequis : NEXUS_PASSWORD doit être défini dans l'environnement
#   export NEXUS_PASSWORD="<mot-de-passe>"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

NEXUS_REGISTRY="localhost:5000"
VERSION=${1:-"1.1.0-SNAPSHOT"}
SERVICES=("user-service" "product-service" "media-service" "order-service")

if [[ -z "$NEXUS_PASSWORD" ]]; then
  echo "ERREUR: la variable NEXUS_PASSWORD n'est pas définie."
  echo "  export NEXUS_PASSWORD='<mot-de-passe>'"
  exit 1
fi

cd "$PROJECT_ROOT"

echo "=== Login vers Nexus Docker Registry ($NEXUS_REGISTRY) ==="
echo "$NEXUS_PASSWORD" | docker login "$NEXUS_REGISTRY" -u admin --password-stdin

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "=== Build + Push $SERVICE:$VERSION ==="

  docker build \
    --network=host \
    --build-arg NEXUS_PASSWORD="$NEXUS_PASSWORD" \
    -f "backend/$SERVICE/Dockerfile" \
    -t "$NEXUS_REGISTRY/ecommerce/$SERVICE:$VERSION" \
    -t "$NEXUS_REGISTRY/ecommerce/$SERVICE:latest" \
    .

  docker push "$NEXUS_REGISTRY/ecommerce/$SERVICE:$VERSION"
  docker push "$NEXUS_REGISTRY/ecommerce/$SERVICE:latest"

  echo "OK $SERVICE -> $NEXUS_REGISTRY/ecommerce/$SERVICE:$VERSION"
done

echo ""
echo "=== Toutes les images poussées vers Nexus ($NEXUS_REGISTRY) ==="