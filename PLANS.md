# Wiki.js restoration

## Goal

Restore Wiki.js at `wiki.victus.fit` as the central, browser-managed
documentation site.

## Scope

- Wiki.js Compose stack, Ansible deployment, public route, and validation.
- Reuse the existing `/srv/secrets/runtime/wiki.env` and
  `/srv/data/wiki/postgres` without moving credentials through CI.
- Remove Backstage, TechDocs, S3 publication, and runner dependencies.

## Validation

- `make compose-validate`
- `make ansible-check`
- Confirm Wiki.js starts and `https://wiki.victus.fit` opens after deployment.

## Risk

- The existing `wiki.env` and PostgreSQL data directory must remain in place.
