#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

up_stack() {
  local stack="$1"
  local env_file="$ROOT_DIR/compose/projects/$stack/.env"
  local compose_file="$ROOT_DIR/compose/projects/$stack/docker-compose.local.yml"

  echo "==> Starting $stack"
  docker compose --env-file "$env_file" -f "$compose_file" up -d
}

up_stack personal
up_stack core
up_stack observability

echo "Local stacks started"
