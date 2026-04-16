#!/usr/bin/env bash
#
# Validate syntax of deploy-all.yml playbook
# Used by GitHub Actions workflow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ANSIBLE_DIR="${REPO_ROOT}/ansible"

echo "=== Validating deploy-all.yml syntax ==="
cd "${ANSIBLE_DIR}"

if ! ansible-playbook --syntax-check playbooks/deploy-all.yml; then
    echo "✗ Syntax check failed"
    exit 1
fi

echo "✓ Syntax check passed"
exit 0
