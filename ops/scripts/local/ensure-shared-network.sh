#!/usr/bin/env bash

set -euo pipefail

NETWORK_NAME="${1:-infra_shared_backend}"

if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  docker network create "$NETWORK_NAME" >/dev/null
fi
