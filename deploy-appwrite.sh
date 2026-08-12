#!/usr/bin/env bash
# Appwrite Sites deploy helper (REST fallback for self-hosted servers)
# Usage:
#   ./deploy-appwrite.sh <ENDPOINT> <PROJECT_ID> <API_KEY> <SITE_ID> [OUTPUT_DIR]
set -euo pipefail

ENDPOINT="${1:?Usage: $0 <endpoint> <projectId> <apiKey> <siteId> [outputDir]}"
PROJECT_ID="${2:?projectId required}"
API_KEY="${3:?apiKey required}"
SITE_ID="${4:?siteId required}"
OUTDIR="${5:-dist}"

TARBALL="/tmp/appwrite-site-${SITE_ID}.tar.gz"

echo "==> Archiving code (excluding node_modules, .git, dist) ..."
tar --exclude=node_modules --exclude=.git --exclude="$OUTDIR" --exclude=.DS_Store \
  -czf "$TARBALL" .

echo "==> Checking if site '${SITE_ID}' exists ..."
SITE=$(curl -s -o /dev/null -w "%{http_code}" "${ENDPOINT}/sites/${SITE_ID}" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" -H "X-Appwrite-Key: ${API_KEY}" \
  -H "X-Appwrite-Response-Format: 1.9.5")

if [ "$SITE" = "404" ]; then
  echo "==> Site not found, creating it ..."
  curl -s -X POST "${ENDPOINT}/sites" \
    -H "X-Appwrite-Project: ${PROJECT_ID}" -H "X-Appwrite-Key: ${API_KEY}" \
    -H "Content-Type: application/json" -H "X-Appwrite-Response-Format: 1.9.5" \
    -d "{\"siteId\":\"${SITE_ID}\",\"name\":\"${SITE_ID}\",\"framework\":\"vite\",\"buildRuntime\":\"node-22\",\"installCommand\":\"npm install\",\"buildCommand\":\"npm run build\",\"outputDirectory\":\"${OUTDIR}\",\"adapter\":\"static\"}" >/dev/null
  echo "==> Site created."
fi

echo "==> Creating deployment ..."
DEPLOY=$(curl -s -X POST "${ENDPOINT}/sites/${SITE_ID}/deployments" \
  -H "X-Appwrite-Project: ${PROJECT_ID}" -H "X-Appwrite-Key: ${API_KEY}" \
  -H "X-Appwrite-Response-Format: 1.9.5" \
  -F "installCommand=npm install" -F "buildCommand=npm run build" \
  -F "outputDirectory=${OUTDIR}" -F "code=@${TARBALL}" -F "activate=true")

DEPLOY_ID=$(echo "$DEPLOY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('\$id',''))" 2>/dev/null)
if [ -z "$DEPLOY_ID" ]; then
  echo "!! Deploy failed:"; echo "$DEPLOY"; exit 1
fi
echo "==> Deployment ID: $DEPLOY_ID"

echo "==> Polling build status ..."
while true; do
  sleep 10
  ST=$(curl -s "${ENDPOINT}/sites/${SITE_ID}/deployments/${DEPLOY_ID}" \
    -H "X-Appwrite-Project: ${PROJECT_ID}" -H "X-Appwrite-Key: ${API_KEY}" \
    -H "X-Appwrite-Response-Format: 1.9.5")
  STATUS=$(echo "$ST" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
  echo "    status: $STATUS"
  case "$STATUS" in
    ready) echo "==> Deploy SUCCESS"; exit 0 ;;
    failed) echo "!! Build failed:"; echo "$ST" | python3 -c "import sys,json; print(json.load(sys.stdin).get('buildLogs','')[ -3000:])" 2>/dev/null; exit 1 ;;
    *) : ;;
  esac
done