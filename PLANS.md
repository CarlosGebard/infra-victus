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

## Follow-up: simple TechDocs onboarding

### Goal

Publish documentation whenever a supported Victus repository changes its
documentation on `main`, and make each repository discoverable in Backstage.

### Current findings

- Backstage currently loads only `victus-agent` from
  `victus-agent/main/catalog-info.yaml`; that file is not yet on `main`.
- SeaweedFS is attached to the `core_backend` Docker network, while Backstage
  is attached to `infra_shared_backend`; the `seaweedfs` hostname is therefore
  not resolvable from Backstage.
- `victus-processing`, `victus-rag`, and `victus-fullstack` already contain
  `docs/`, but do not yet contain a TechDocs catalog entity, MkDocs config, or
  publish workflow.

### Steps

1. Make the Backstage service join the existing external Core backend network,
   so its S3 client can reach SeaweedFS at `http://seaweedfs:8333`.
2. Keep TechDocs in external-builder mode: CI builds MkDocs and publishes to
   the private `victus-techdocs` bucket; Backstage only reads it.
3. Onboard one repository at a time, starting with `victus-agent`: merge its
   existing catalog, MkDocs, and reusable publish workflow to `main`, then
   verify its Docs page.
4. Repeat the same small three-file addition for `victus-processing`,
   `victus-rag`, and `victus-fullstack`; add their catalog URLs in Backstage.
5. Resolve the guest-session 401 only after the catalog entity and S3 network
   path work, by explicitly configuring a guest sign-in experience or choosing
   a real identity provider.

### Validation

- From the Backstage container, resolve `seaweedfs` and list the
  `victus-techdocs` bucket with the configured S3 endpoint.
- Change a Markdown file on `main` in an onboarded repository and confirm its
  Publish TechDocs workflow succeeds.
- Confirm the component appears in the catalog and its Docs page renders at
  `https://wiki.victus.fit`.
