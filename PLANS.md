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

---

## Goal
Harden SeaweedFS deploy and local validation so invalid S3 auth config fails early, and document the current operational status of bucket provisioning.

## Scope
- Validate local `compose/configs/seaweedfs/s3.json.example` during compose checks.
- Validate remote `/srv/secrets/runtime/seaweed-s3.json` before `core` deploy runs `docker compose up`.
- Document that deploy configures SeaweedFS S3 credentials, but does not create buckets automatically.

## Assumptions
- Current repo wiring for SeaweedFS runtime is correct enough to boot with a valid S3 config.
- Main preventable failure mode is malformed or incomplete `seaweed-s3.json`.
- Buckets are currently expected to be created manually or lazily by clients, not by Ansible or Compose.

## Steps
1. Add local SeaweedFS S3 JSON validation in `compose/scripts/validate-compose.sh`.
2. Add remote SeaweedFS S3 JSON validation in `ansible/roles/deploy/core/tasks/main.yml`.
3. Update deploy runbook with bucket-status note and troubleshooting guidance.

## Validation
- `make compose-validate`
- `./tests/ansible/deploy-syntax-check.sh`

## Risks
- Validation may reject legacy but technically accepted SeaweedFS configs if assertions are too strict.
- Documentation may drift later if bucket automation is added and runbook is not updated.

---

## Goal
Stop SeaweedFS restart loop caused by unreadable mounted S3 config on host.

## Scope
- Enforce `/srv/secrets/runtime/seaweed-s3.json` ownership `1000:1000`.
- Enforce mode `0400` before `core` stack start.
- Fail early if final file metadata differs from expected.
- Recreate `seaweedfs` when permission fix changes mounted secret metadata.
- Update runbook with new operational contract.

## Assumptions
- SeaweedFS process inside container runs as uid/gid `1000`.
- Restart loop root cause is host bind-mounted secret unreadable by container user.
- Smallest safe fix belongs in `core` deploy role, not generic secret staging.

## Steps
1. Add file ownership/mode enforcement task in `ansible/roles/deploy/core/tasks/main.yml`.
2. Add stat/assert guard for uid, gid, mode before `docker compose up`.
3. Extend recreate derivation so permission drift on `seaweed-s3.json` recreates `seaweedfs`.
4. Update `docs/runbooks/deploy.md` with permission contract and troubleshooting note.

## Validation
- `./tests/ansible/deploy-syntax-check.sh`
- Manual host check: `stat -c '%u %g %a %n' /srv/secrets/runtime/seaweed-s3.json`

## Risks
- Wrong assumed container uid/gid would break access again.
- Future secret staging refactor could overwrite metadata after enforcement if task order changes.

---

## Goal
Move Seaweed S3 access from path-based proxy to dedicated `s3` virtual host while keeping other private services path-based.

## Scope
- Remove `/seaweed/s3/` from local static NGINX config.
- Ensure `s3.{{ BASE_DOMAIN }}` server block proxies root `/` directly to `seaweedfs:8333`.
- Preserve private access controls for Seaweed master, filer, Grafana, Prometheus, Loki.
- Preserve `seaweed` and `filer` dedicated server blocks.

## Assumptions
- S3 clients expect root-based bucket/object paths, not path prefix `/seaweed/s3/`.
- Dedicated `s3` domain already exists in deploy template domain list.
- Smallest safe change is NGINX-only; no Compose or Ansible role logic changes needed.

## Steps
1. Remove path-based S3 location from local `compose/configs/nginx/conf.d/core.conf`.
2. Update deploy template `ansible/roles/deploy/core/templates/nginx-core.conf.j2` so `s3` vhost proxies `/` with correct `Host` header.
3. Validate rendered config with `make compose-validate`.

## Validation
- `make compose-validate`

## Risks
- Missing `Host` forwarding would break S3 virtual-host style behavior or signature validation in some clients.
- Operators using old `/seaweed/s3/` path will need to switch to `s3.<domain>`.
