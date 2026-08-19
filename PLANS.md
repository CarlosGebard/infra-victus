# Backstage and external TechDocs migration

## Goal

Replace Wiki.js at `wiki.victus.fit` with Backstage and externally generated
TechDocs stored in the existing S3-compatible SeaweedFS service.

## Scope

- Backstage Compose, Ansible deployment, public edge route, database, and runtime secrets.
- Dedicated `victus-techdocs` bucket and TechDocs S3 configuration.
- Central reusable workflow and organization-scoped OIDC identity for TechDocs publication.
- Removal of Wiki.js definitions and an explicit post-validation cleanup command for its database.

## Assumptions

- `wiki.victus.fit` remains the public hostname and DNS already targets this VPS.
- Backstage is built and published as `ghcr.io/victus-fit/victus-backstage` before deployment.
- A self-hosted GitHub Actions runner is registered on the VPS with the `victus-techdocs` label.
- Wiki.js data is deleted only after Backstage and TechDocs verification succeeds.

## Steps

1. Add the Backstage runtime and dedicated SeaweedFS bucket.
2. Replace Wiki.js deployment, routing, validation, and secret references with Backstage.
3. Configure Backstage as an external TechDocs reader and centralize publishing CI in
   `victus-infra`, invoked by `victus-agent` without repository publication secrets.
4. Add an ADR and an operator runbook, including the irreversible Wiki.js database cleanup.
5. Validate Compose, Ansible syntax, Backstage configuration, and TechDocs source navigation.

## Validation

- `make compose-validate`
- `make ansible-check`
- `yarn backstage-cli config:check --config app-config.yaml --config app-config.production.yaml`
- Confirm `https://wiki.victus.fit` serves Backstage and the `victus-agent` TechDocs page.

## Risks

- The Backstage image must exist in GHCR and be readable by the VPS.
- The self-hosted runner must reach the private SeaweedFS endpoint.
- Removing `/srv/data/wiki/postgres` is irreversible.
