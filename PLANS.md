# Plans

## Wiki.js Public Stack Integration

Goal: integrate Wiki.js into the repository-owned infra runtime and publish it
through the existing public NGINX edge.

Scope:
- `compose/projects/wiki/`
- `compose/env/wiki.env.example`
- Ansible deploy inventory, playbook, and role for the `wiki` stack
- public vhost routing in production networking vars
- local validation and minimal docs

Assumptions:
- `nginx-public` is the public edge and should proxy to Wiki.js.
- Wiki.js should run as its own deployable stack.
- Production secrets are staged outside git through `WIKI_RUNTIME_ENV_SOURCE_FILE`.
- The existing production database can be preserved with
  `WIKIJS_DB_DATA_LOCATION=/srv/data/media/wiki/postgres`.

Steps:
1. Add Wiki.js Compose files using repository stack layout.
2. Connect Wiki.js to `infra_shared_backend` for public edge routing.
3. Add Ansible deployment support for the `wiki` stack.
4. Add a public Wiki.js vhost in production networking vars.
5. Extend validation and documentation.

Validation:
- `make compose-validate`
- `make ansible-check`

Risks:
- Public DNS must point the selected docs hostname at the VPS before TLS issue.
- If preserving old data, the runtime env must keep the old database path until
  a planned migration copies it.

## Langfuse Prompt Sync

Goal: move the current production Markdown prompts into a versioned repository
location and provide a repeatable Langfuse sync path.

Scope:
- `prompts/`
- `ops/scripts/runtime/sync-langfuse-prompts.py`
- `.github/scripts/deploy-llm-fast.sh`
- `docs/operations/206-LANGFUSE-PROMPTS.md`
- operations documentation index links

Assumptions:
- All provided Markdown files are currently production prompts.
- All prompts should be created as Langfuse chat prompts with a single `system`
  message.
- Temperature is `0` for all prompts.

Steps:
1. Move root Markdown prompts into `prompts/`.
2. Add a manifest with Langfuse names, prompt files, labels, and config.
3. Add a dependency-free sync script that calls the Langfuse public API.
4. Add a minimal operations runbook.
5. Validate dry-run output and Python syntax.
6. Reuse the existing Infisical-backed `llm.env` in deploy to publish prompts.

Validation:
- `python3 ops/scripts/runtime/sync-langfuse-prompts.py --dry-run`
- `python3 -m py_compile ops/scripts/runtime/sync-langfuse-prompts.py`

Risks:
- Prompt names may need app-specific prefixes if existing Langfuse names differ.
- Direct `production` labeling updates production immediately in the target
  Langfuse project.
