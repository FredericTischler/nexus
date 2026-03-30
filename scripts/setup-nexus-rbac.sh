#!/bin/bash
# scripts/setup-nexus-rbac.sh — Configurer les rôles et utilisateurs Nexus (RBAC)
# Usage: ./scripts/setup-nexus-rbac.sh
#
# Prérequis : les 3 variables doivent être définies
#   export NEXUS_PASSWORD="<mot-de-passe-admin>"
#   export CI_DEPLOYER_PASSWORD="<mot-de-passe-ci-deployer>"
#   export DEV_USER_PASSWORD="<mot-de-passe-dev-user>"

set -e

NEXUS_URL="http://localhost:8091"

if [[ -z "$NEXUS_PASSWORD" ]]; then
  echo "ERREUR: NEXUS_PASSWORD non défini."
  exit 1
fi

CI_DEPLOYER_PASSWORD="${CI_DEPLOYER_PASSWORD:?"Définir CI_DEPLOYER_PASSWORD (mot de passe pour ci-deployer)"}"
DEV_USER_PASSWORD="${DEV_USER_PASSWORD:?"Définir DEV_USER_PASSWORD (mot de passe pour dev-user)"}"

AUTH="admin:${NEXUS_PASSWORD}"

echo "=== Création des rôles ==="

# 1. developer-role : lecture partout + déploiement snapshots
curl -sf -u "$AUTH" -X POST \
  "$NEXUS_URL/service/rest/v1/security/roles" \
  -H "Content-Type: application/json" -d '{
    "id": "developer-role",
    "name": "Developer",
    "description": "Lecture sur tous les repos, déploiement snapshots uniquement",
    "privileges": [
      "nx-repository-view-maven2-maven-snapshots-add",
      "nx-repository-view-maven2-maven-snapshots-edit",
      "nx-repository-view-maven2-maven-snapshots-read",
      "nx-repository-view-maven2-maven-snapshots-browse",
      "nx-repository-view-maven2-maven-public-read",
      "nx-repository-view-maven2-maven-public-browse",
      "nx-repository-view-docker-docker-hosted-read",
      "nx-repository-view-docker-docker-hosted-browse"
    ]
  }' && echo "OK developer-role" || echo "developer-role existe déjà"

# 2. deployer-role : déploiement releases Maven + push Docker
curl -sf -u "$AUTH" -X POST \
  "$NEXUS_URL/service/rest/v1/security/roles" \
  -H "Content-Type: application/json" -d '{
    "id": "deployer-role",
    "name": "Deployer",
    "description": "Déploiement releases Maven + push images Docker",
    "privileges": [
      "nx-repository-view-maven2-maven-releases-add",
      "nx-repository-view-maven2-maven-releases-edit",
      "nx-repository-view-maven2-maven-releases-read",
      "nx-repository-view-maven2-maven-releases-browse",
      "nx-repository-view-maven2-maven-snapshots-add",
      "nx-repository-view-maven2-maven-snapshots-edit",
      "nx-repository-view-maven2-maven-snapshots-read",
      "nx-repository-view-maven2-maven-snapshots-browse",
      "nx-repository-view-docker-docker-hosted-add",
      "nx-repository-view-docker-docker-hosted-edit",
      "nx-repository-view-docker-docker-hosted-read",
      "nx-repository-view-docker-docker-hosted-browse"
    ]
  }' && echo "OK deployer-role" || echo "deployer-role existe déjà"

# 3. readonly-role : lecture seule sur tous les repositories
curl -sf -u "$AUTH" -X POST \
  "$NEXUS_URL/service/rest/v1/security/roles" \
  -H "Content-Type: application/json" -d '{
    "id": "readonly-role",
    "name": "ReadOnly",
    "description": "Lecture seule sur tous les repositories",
    "privileges": [
      "nx-repository-view-*-*-read",
      "nx-repository-view-*-*-browse"
    ]
  }' && echo "OK readonly-role" || echo "readonly-role existe déjà"

echo ""
echo "=== Création des utilisateurs ==="

# ci-deployer — utilisé par Jenkins
curl -sf -u "$AUTH" -X POST \
  "$NEXUS_URL/service/rest/v1/security/users" \
  -H "Content-Type: application/json" -d '{
    "userId": "ci-deployer",
    "firstName": "CI",
    "lastName": "Deployer",
    "emailAddress": "ci@ecommerce.local",
    "password": "'"$CI_DEPLOYER_PASSWORD"'",
    "status": "active",
    "roles": ["deployer-role"]
  }' && echo "OK ci-deployer" || echo "ci-deployer existe déjà"

# dev-user — utilisé par les développeurs en local
curl -sf -u "$AUTH" -X POST \
  "$NEXUS_URL/service/rest/v1/security/users" \
  -H "Content-Type: application/json" -d '{
    "userId": "dev-user",
    "firstName": "Developer",
    "lastName": "User",
    "emailAddress": "dev@ecommerce.local",
    "password": "'"$DEV_USER_PASSWORD"'",
    "status": "active",
    "roles": ["developer-role"]
  }' && echo "OK dev-user" || echo "dev-user existe déjà"

echo ""
echo "=== RBAC configuré ==="
echo "  ci-deployer / \$CI_DEPLOYER_PASSWORD  → deployer-role"
echo "  dev-user    / \$DEV_USER_PASSWORD    → developer-role"