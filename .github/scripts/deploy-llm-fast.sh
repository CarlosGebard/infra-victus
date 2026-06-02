#!/usr/bin/env bash

set -euo pipefail

: "${PROD_HOST:?Missing PROD_HOST}"

SSH_PORT="${PROD_SSH_PORT:-22}"
DEPLOY_SSH_USER="${DEPLOY_SSH_USER:-carlos}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/deploy_key}"

[[ -f /tmp/llm-runtime.env ]] || { echo "Missing /tmp/llm-runtime.env" >&2; exit 1; }

rm -rf /tmp/llm-deploy
mkdir -p \
  /tmp/llm-deploy/apps/llm/litellm \
  /tmp/llm-deploy/apps/llm/prompts \
  /tmp/llm-deploy/apps/llm/llm-postgres/init \
  /tmp/llm-deploy/secrets/runtime

cp compose/projects/llm/compose.yml /tmp/llm-deploy/apps/llm/compose.yml
cp compose/projects/llm/compose.prod.yml /tmp/llm-deploy/apps/llm/compose.prod.yml
cp ops/scripts/runtime/render-litellm-config.py /tmp/llm-deploy/apps/llm/litellm/render-litellm-config.py
cp ops/scripts/runtime/sync-langfuse-prompts.py /tmp/llm-deploy/apps/llm/sync-langfuse-prompts.py
cp prompts/*.md prompts/langfuse-prompts.json /tmp/llm-deploy/apps/llm/prompts/
cp compose/configs/llm-postgres/init/01-create-llm-databases.sh /tmp/llm-deploy/apps/llm/llm-postgres/init/01-create-llm-databases.sh
cp /tmp/llm-runtime.env /tmp/llm-deploy/secrets/runtime/llm.env

tar -C /tmp/llm-deploy -czf /tmp/llm-deploy.tgz .
scp -i "$SSH_KEY_PATH" -P "$SSH_PORT" /tmp/llm-deploy.tgz "$DEPLOY_SSH_USER@$PROD_HOST:/tmp/llm-deploy.tgz"

ssh -i "$SSH_KEY_PATH" -p "$SSH_PORT" "$DEPLOY_SSH_USER@$PROD_HOST" 'sudo bash -s' <<'REMOTE'
set -euo pipefail

mkdir -p /srv/apps/llm /srv/secrets/runtime /srv/data/llm/postgres
tar -xzf /tmp/llm-deploy.tgz -C /srv
chmod 600 /srv/secrets/runtime/llm.env
chmod +x /srv/apps/llm/litellm/render-litellm-config.py
chmod +x /srv/apps/llm/sync-langfuse-prompts.py
chmod +x /srv/apps/llm/llm-postgres/init/*.sh
ln -sfn /srv/secrets/runtime/llm.env /srv/apps/llm/.env
docker network inspect infra_shared_backend >/dev/null 2>&1 || docker network create infra_shared_backend

cd /srv/apps/llm
/srv/apps/llm/litellm/render-litellm-config.py --env-file /srv/secrets/runtime/llm.env /srv/apps/llm/litellm/config.yaml
docker compose --env-file /srv/secrets/runtime/llm.env -f compose.yml -f compose.prod.yml up -d --remove-orphans
/srv/apps/llm/sync-langfuse-prompts.py --env-file /srv/secrets/runtime/llm.env --manifest /srv/apps/llm/prompts/langfuse-prompts.json
rm -f /tmp/llm-deploy.tgz
REMOTE
