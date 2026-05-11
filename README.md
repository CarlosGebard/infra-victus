# Victus Infra

Reproducible infrastructure for the Victus VPS and private RAG data platform.

This repository manages the application infrastructure layer. Host bootstrap is intentionally handled by the sibling `server-bootstrap` repository.

[Leer en español](docs/README.es.md)

## Purpose

`infra-victus` provides a small, explicit, Docker Compose based runtime for:

- private object storage for RAG data
- private DNS over Tailscale
- edge routing through NGINX
- observability with Grafana, Prometheus, and Loki
- repeatable deploys through Ansible and GitHub Actions

The RAG application itself is still in development. The storage foundation is implemented: SeaweedFS S3, private virtual-host routing, declarative buckets, and RAG data prefixes.

Next major infrastructure addition: Qdrant for vector storage.

## Architecture


Operational automation:

```text
ansible/
ops/
.github/workflows/
```

## Services

### Core

- `nginx`
  - private edge router
  - S3 virtual-host routing
  - internal routes for SeaweedFS and observability
- `seaweedfs`
  - S3-compatible object storage
  - stores RAG raw data, normalized documents, extraction outputs, embeddings inputs, and backups
- `etcd`
  - backing store for private DNS records
  - internal only, not exposed to the host
- `coredns`
  - private authoritative DNS for `victus.io`
  - serves `s3.victus.io` and `*.s3.victus.io`

### Observability

- `grafana`
- `prometheus`
- `loki`

## RAG Storage Contract

Declarative S3 bucket contract:

```text
compose/configs/seaweedfs/buckets.json
```

Managed buckets:

```text
victus-rag
victus-backups
victus-tmp
```

Managed prefixes under `victus-rag`:

```text
pipeline/01_metadata/
pipeline/02_normalized_pdfs/
pipeline/03_docling_heuristics/
pipeline/04_claims/
rag/experiments/
rag/embeddings/
rag/retrieval/
```

The deploy applies this contract idempotently. It creates missing buckets and `.keep` objects for missing prefixes. It does not delete existing data.

## Local Development

Validate configuration:

```bash
make compose-validate
make ansible-check
```

Run core locally:

```bash
make core-up
```

Run core locally and expose DNS/NGINX on the local Tailscale IP:

```bash
make core-up-tailscale
# or:
./ops/scripts/local/up-core.sh --tailscale
```

## Deploy Model

Rollout order:

```text
observability -> core
```

Deploy is handled by:

```text
.github/workflows/deploy-all.yml
```

Validation is handled by:

```text
.github/workflows/validate-infra.yml
```

Secrets are fetched through Infisical using GitHub OIDC.

## Documentation

- [Docs overview](docs/README.md)
- [Deploy runbook](docs/runbooks/deploy.md)
- [Private DNS contract](docs/private-dns-contract.md)
- [Secrets and variables](docs/secrets-and-variables.md)
- [ADR: structure decisions](docs/adr/0001-structure-decisions.md)
- [ADR: private DNS with CoreDNS and etcd](docs/adr/0002-core-private-dns-with-coredns-etcd.md)

## Status

Completed:

- Docker Compose runtime split into `core` and `observability`
- CouchDB removed from infrastructure
- SeaweedFS S3 storage
- private DNS with CoreDNS
- S3 virtual-host routing
- declarative RAG buckets and prefixes
- deployment automation through Ansible/GitHub Actions

In progress / next:

- Qdrant service for vector search
- Grafana dashboard and datasource provisioning
- RAG application workloads
