# Victus Infra

Reproducible infrastructure for the private Victus runtime.

This repository does not contain the application. It provides the shared runtime used by other Victus repositories:

- object storage and artifacts in SeaweedFS S3
- durable paper state in Postgres
- live events in Redis
- private DNS with CoreDNS
- private edge routing with NGINX
- observability with Grafana, Prometheus, and Loki
- deployment with Ansible and GitHub Actions

[Leer en español](docs/README.es.md)

## Quick View

```text
compose/        Docker Compose source of truth
ansible/        VPS deployment
ops/            scripts and reusable bridge
docs/           essential documentation
tests/          Ansible validation
```

Stacks:

```text
core            nginx, seaweedfs, postgres, redis, etcd, coredns
observability   grafana, prometheus, loki
llm             LiteLLM, Langfuse, Postgres
```

## Local Use

Validate:

```bash
make ansible-check
make compose-validate
```

Start `core`:

```bash
make core-up
```

This also applies local S3 buckets idempotently.

Logs:

```bash
make core-logs
```

Stop:

```bash
make core-down
```

## Reusable Bridge

The shared SDK/CLI lives in:

```text
ops/bridge
```

Example:

```bash
cd ops/bridge
uv run victus-ingest --help
```

The bridge only talks to shared infrastructure. It does not implement Docling, claims, embeddings, Qdrant, or app-specific logic.

## Deployment

Production deploy runs through:

```text
.github/workflows/deploy-all.yml
```

Secrets come from Infisical through GitHub OIDC.

## Documentation

- [Documentation Index](docs/README.md)
- [System Context](docs/000-SYSTEM-CONTEXT.md)
- [Architecture](docs/100-ARCHITECTURE.md)
- [Operations](docs/200-OPERATIONS.md)
- [Contracts](docs/300-CONTRACTS.md)
- [Local Runtime](docs/operations/local-runtime.md)
- [Deployment](docs/operations/deployment.md)
- [Security Operations](docs/operations/security.md)
- [Troubleshooting](docs/operations/troubleshooting.md)
