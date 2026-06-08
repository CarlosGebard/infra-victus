#!/usr/bin/env bash

set -euo pipefail

: "${PROD_HOST:?Missing PROD_HOST}"

SSH_PORT="${PROD_SSH_PORT:-22}"
DEPLOY_SSH_USER="${DEPLOY_SSH_USER:-carlos}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/deploy_key}"

[[ -f /tmp/wiki-runtime.env ]] || { echo "Missing /tmp/wiki-runtime.env" >&2; exit 1; }

rm -rf /tmp/wiki-deploy
mkdir -p \
  /tmp/wiki-deploy/apps/wiki \
  /tmp/wiki-deploy/secrets/runtime

cp compose/projects/wiki/compose.yml /tmp/wiki-deploy/apps/wiki/compose.yml
cp compose/projects/wiki/compose.prod.yml /tmp/wiki-deploy/apps/wiki/compose.prod.yml
cp /tmp/wiki-runtime.env /tmp/wiki-deploy/secrets/runtime/wiki.env

tar -C /tmp/wiki-deploy -czf /tmp/wiki-deploy.tgz .
scp -i "$SSH_KEY_PATH" -P "$SSH_PORT" /tmp/wiki-deploy.tgz "$DEPLOY_SSH_USER@$PROD_HOST:/tmp/wiki-deploy.tgz"

ssh -i "$SSH_KEY_PATH" -p "$SSH_PORT" "$DEPLOY_SSH_USER@$PROD_HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail

mkdir -p /srv/apps/wiki /srv/secrets/runtime /srv/data/wiki/postgres
tar -xzf /tmp/wiki-deploy.tgz -C /srv
chmod 600 /srv/secrets/runtime/wiki.env
ln -sfn /srv/secrets/runtime/wiki.env /srv/apps/wiki/.env
docker network inspect infra_shared_backend >/dev/null 2>&1 || docker network create infra_shared_backend

cd /srv/apps/wiki
docker compose --env-file /srv/secrets/runtime/wiki.env -f compose.yml -f compose.prod.yml up -d --remove-orphans
rm -f /tmp/wiki-deploy.tgz
REMOTE
