#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v ansible-playbook >/dev/null 2>&1 || {
  echo "Missing ansible-playbook in PATH" >&2
  exit 1
}

"$ROOT_DIR/tests/ansible/syntax-check.sh"
"$ROOT_DIR/tests/ansible/runtime-syntax-check.sh"
"$ROOT_DIR/tests/ansible/deploy-syntax-check.sh"
"$ROOT_DIR/tests/ansible/deploy-personal-syntax-check.sh"
"$ROOT_DIR/tests/ansible/deploy-observability-syntax-check.sh"

echo "Ansible integrity checks OK"
