## Goal
Make deploy idempotent but reactive: if deploy changes stack config, mounted secret files, compose file, or env link inputs, Ansible must restart or recreate only affected containers so runtime matches repo state on host.

## Scope
- Inspect current `deploy/shared` and per-stack deploy roles.
- Add explicit per-stack restart/recreate metadata for affected services.
- Detect file changes during deploy for config files and staged secrets.
- Trigger targeted `docker compose restart` for bind-mounted config changes.
- Trigger targeted `docker compose up -d --force-recreate` when compose/env/secret changes require container recreation.
- Keep stack separation: `core`, `personal`, `observability`.
- Update deploy runbook with new behavior and operator expectations.

## Non-goals
- No broad refactor of deploy architecture.
- No change to public compose service names.
- No auto-reload via service-specific APIs unless already needed.
- No new dependency or switch to Ansible Docker modules unless current command-based flow blocks safe impl.

## Assumptions
- Main problem: bind-mounted config file changes do not reload inside containers with plain `docker compose up -d`.
- Some secret changes are file-content changes on host mounts, so they also need service recreation/restart.
- Smallest safe path: explicit metadata in inventory vars, not implicit parsing of compose volumes.
- `docker compose` available on target host, same as current deploy flow.

## Steps
1. Model restart policy per stack in inventory vars.
   - Add metadata near each stack in `ansible/inventories/production/group_vars/deploy.yml`.
   - Define which services need `restart` on config file change.
   - Define which services need `force_recreate` on staged secret, compose, or env-driven change.
   - Validation:
     - `ansible-playbook -i inventories/production/syntax-check.yml --syntax-check playbooks/deploy.yml`

2. Capture changed deploy artifacts in shared role.
   - Update `ansible/roles/deploy/shared/tasks/main.yml`.
   - Register results from `copy` of config files and staged secret files.
   - Derive normalized lists/facts like `deploy_changed_config_targets`, `deploy_changed_secret_targets`.
   - Keep logic generic so stack roles consume facts, not duplicate detection.
   - Validation:
     - `ansible-playbook -i inventories/production/syntax-check.yml --syntax-check playbooks/deploy.yml`
     - `ansible-playbook --syntax-check playbooks/deploy-all.yml`

3. Apply targeted restart/recreate in each stack role after compose validation.
   - Update:
     - `ansible/roles/deploy/core/tasks/main.yml`
     - `ansible/roles/deploy/personal/tasks/main.yml`
     - `ansible/roles/deploy/observability/tasks/main.yml`
   - Register compose/env-link changes.
   - Run normal `docker compose up -d`.
   - If config-only changes happened, run `docker compose restart <services>` for affected services.
   - If compose/env/secret changes happened, run `docker compose up -d --force-recreate <services>` for affected services.
   - Ensure order prevents restarting before config validation passes.
   - Validation:
     - `./tests/ansible/deploy-syntax-check.sh`
     - `./tests/ansible/deploy-all-syntax-check.sh`

4. Document operator behavior.
   - Update `docs/runbooks/deploy.md`.
   - Explain what kinds of changes trigger restart vs recreate.
   - Add note about secrets/config mounted from host and why extra action exists.
   - Validation:
     - manual doc review for consistency with playbooks

## Risks
- Over-restart: too-broad service mapping may cause avoidable restarts.
- Under-restart: missed file-to-service mapping leaves stale runtime config.
- `--force-recreate` on stateful services must stay scoped to changed services only.
- Core deploy already runs two `up -d` passes for TLS; new logic must not duplicate or fight that flow.
- Observability stack may later gain more provisioned Grafana files; mapping should be easy to extend.

## Likely files
- `PLANS.md`
- `ansible/inventories/production/group_vars/deploy.yml`
- `ansible/roles/deploy/shared/tasks/main.yml`
- `ansible/roles/deploy/core/tasks/main.yml`
- `ansible/roles/deploy/personal/tasks/main.yml`
- `ansible/roles/deploy/observability/tasks/main.yml`
- `docs/runbooks/deploy.md`

## Validation
- `make ansible-check`
- `make compose-validate`
- `./tests/ansible/deploy-syntax-check.sh`
- `./tests/ansible/deploy-all-syntax-check.sh`

## Decision notes
- Prefer explicit restart metadata over parsing compose mounts dynamically.
- Prefer stack-local targeted restart/recreate over global `docker compose down/up`.
- Keep deploy source of truth in repo vars and playbooks, not host-side scripts.

## Ready-to-implement summary
Smallest safe impl: add per-stack service mapping for changed configs/secrets, capture `copy` task change state in `deploy/shared`, then after successful `docker compose config` run targeted `restart` for config-only changes and targeted `up -d --force-recreate` for compose/env/secret changes. Update runbook after behavior lands.
