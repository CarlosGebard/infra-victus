---
id: techdocs-publication
title: TechDocs publication
status: active
updated_at: 2026-08-19
owners: victus-fit
---

## Operation

`victus-infra/.github/workflows/publish-techdocs.yml` runs on the `victus-techdocs` VPS runner. It generates the caller repository's `mkdocs.yml` site and writes it to the private `victus-techdocs` SeaweedFS bucket through `127.0.0.1:8333`.

## Required configuration

Set these GitHub **organization Actions variables** and make them available to repositories that publish TechDocs:

- `INFISICAL_TECHDOCS_PUBLISHER_ID`: Infisical OIDC identity ID.
- `INFISICAL_PROJECT_SLUG`: Infisical project slug.
- `INFISICAL_ENV_SLUG`: Infisical environment slug that contains the publisher path.

`INFISICAL_DEPLOY_ID` is a separate organization variable used only by the
`victus-infra` deployment workflow. Do not reuse it as the TechDocs publisher
identity.

The identity must read `/Hetzner-Server/wiki`, which contains `TECHDOCS_S3_ACCESS_KEY` and `TECHDOCS_S3_SECRET_KEY`. The same SeaweedFS identity is used by Backstage and the publisher, so it requires `Read`, `Write`, and `List` permissions.

## Verify

Trigger the caller workflow, confirm the `Generate and publish TechDocs` step succeeds, then open the entity's Docs tab in Backstage.

## Recovery

If publishing cannot reach S3, verify `seaweedfs` exposes port `8333` only on loopback and that the runner is on the same VPS. Re-run the caller workflow after restoring the service.
