#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"$ROOT_DIR/ops/scripts/local/ensure-shared-network.sh"

up_stack() {
  local stack="$1"
  local env_file="$ROOT_DIR/compose/projects/$stack/.env"
  local compose_base="$ROOT_DIR/compose/projects/$stack/compose.yml"
  local compose_overlay="$ROOT_DIR/compose/projects/$stack/compose.dev.yml"

  echo "==> Starting $stack"
  docker compose --env-file "$env_file" -f "$compose_base" -f "$compose_overlay" up -d
}

up_stack core
up_stack observability

echo "Local stacks started"
