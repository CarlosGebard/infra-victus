# Backstage and external TechDocs migration

## Goal

Serve Backstage at `wiki.victus.fit` with externally generated TechDocs stored
in the existing S3-compatible SeaweedFS service.

## Scope

- Backstage Compose, Ansible deployment, public edge route, database, and runtime secrets.
- Dedicated `victus-techdocs` bucket and TechDocs S3 configuration.
- Central reusable workflow and organization-scoped OIDC identity for TechDocs publication.
- Removal of the legacy documentation synchronization workflow.

## Assumptions

- `wiki.victus.fit` remains the public hostname and DNS already targets this VPS.
- Backstage is built and published as `ghcr.io/victus-fit/victus-backstage` before deployment.
- A self-hosted GitHub Actions runner is registered on the VPS with the `victus-techdocs` label.
- Legacy documentation data is removed only after Backstage and TechDocs verification succeeds.

## Steps

1. Add the Backstage runtime and dedicated SeaweedFS bucket.
2. Deploy Backstage, routing, validation, and runtime secrets.
3. Configure Backstage as an external TechDocs reader and centralize publishing CI in
   `victus-infra`, invoked by `victus-agent` without repository publication secrets.
4. Add an ADR and an operator runbook for the Backstage and TechDocs runtime.
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
