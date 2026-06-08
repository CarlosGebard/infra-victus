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
