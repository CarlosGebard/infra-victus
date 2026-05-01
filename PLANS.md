## Goal
Refactor `compose/projects` so each stack has one environment-agnostic base Compose file plus explicit `development` and `production` overlays, reducing drift between local and server runtime definitions.

## Scope
- Keep one base Compose file per stack as source of truth for shared service definitions.
- Move env-specific differences into overlay files only.
- Update local scripts, validation scripts, and Ansible deploy references to use base + overlay composition.
- Preserve current stack split: `core`, `personal`, `observability`.

## Non-goals
- No service renames.
- No topology change between stacks.
- No image or version changes unless required by Compose merge behavior.
- No workflow or Ansible architecture rewrite beyond file path/reference updates needed for overlay usage.

## Likely files
- `compose/projects/core/*`
- `compose/projects/personal/*`
- `compose/projects/observability/*`
- `compose/scripts/up-local.sh`
- `compose/scripts/up-core.sh`
- `compose/scripts/validate-compose.sh`
- `ansible/inventories/production/group_vars/deploy.yml`
- deploy docs that reference `docker-compose.local.yml` or single-file prod compose

## Milestones
1. Define file layout and merge contract.
   Outcome:
   - Decide canonical names, likely:
     - `compose.yml` or `docker-compose.yml` as base
     - `compose.dev.yml`
     - `compose.prod.yml`
   - Base keeps images, commands, healthchecks, networks, env keys, service relationships.
   - Overlays keep only volumes, ports, bind paths, maybe prod-only TLS mounts.
   Validation:
   - Manual review of current diffs between local and prod files per stack.
   Rollback:
   - None. Planning only.

2. Refactor one stack first, preferably `personal`.
   Outcome:
   - Smallest stack proves merge model with minimal risk.
   - Confirm local/prod differences can live cleanly in overlays.
   Files:
   - `compose/projects/personal/*`
   - scripts/validation references
   Validation:
   - `docker compose -f base -f dev config`
   - `docker compose -f base -f prod config`
   Risks:
   - If merge semantics around `volumes`, `ports`, or `environment` surprise, catch it on smallest stack first.

3. Apply same pattern to `observability` and `core`.
   Outcome:
   - `observability`: mostly path overlay refactor.
   - `core`: more complex because local/prod differ in TLS mounts and exposed ports.
   Validation:
   - render merged config for both envs on each stack
   - preserve current service count and mount intent
   Risks:
   - `core` may need careful split for `/etc/letsencrypt`, ACME dir, and local-only missing HTTPS port mapping.

4. Update scripts and Ansible to use merged files explicitly.
   Outcome:
   - local scripts call base + dev overlay
   - Ansible deploy copies base + prod overlay or already-rendered merged files, depending chosen model
   Validation:
   - `bash compose/scripts/validate-compose.sh`
   - Ansible syntax checks
   Risks:
   - Deploy vars currently assume one compose path per stack; need minimal contract change.

5. Update docs and operator contract.
   Outcome:
   - repo explains:
     - base compose = source of truth
     - overlays = env-specific deltas
   Validation:
   - doc review against scripts and playbooks

## Validation
- `docker compose -f <base> -f <dev> config`
- `docker compose -f <base> -f <prod> config`
- `bash compose/scripts/validate-compose.sh`
- `bash tests/ansible/check.sh`

## Risks
- Compose merge semantics can duplicate or replace lists in ways that are not obvious, especially `ports`, `volumes`, `command`, and `healthcheck`.
- `core` has meaningful local/prod divergence beyond plain paths, especially TLS/certbot mounts and published ports.
- Ansible deploy contract currently points to one prod compose file per stack; overlay support must stay explicit and simple.
- If base file accidentally keeps host-specific paths, drift problem remains under a different name.

## Decision notes
- Best target shape:
  - base file contains runtime identity
  - dev/prod overlays contain host/path/exposure deltas
- Start with `personal` first because easiest proof.
- Prefer explicit `docker compose -f base -f overlay ...` over `extends`; file overlay merging is simpler and more standard.
