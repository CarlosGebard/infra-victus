# Victus Infra

Infraestructura reproducible para el runtime privado de Victus.

Este repo no contiene la app. Provee la base compartida usada por otros repositorios Victus:

- objetos y artefactos en SeaweedFS S3
- estado durable de papers en Postgres
- eventos live en Redis
- DNS privado con CoreDNS
- edge privado con NGINX
- observabilidad con Grafana, Prometheus y Loki
- deploy con Ansible y GitHub Actions

[Read in English](../README.md)

## Vista Rápida

```text
compose/        Docker Compose source of truth
ansible/        deploy al VPS
ops/            scripts y bridge reusable
docs/           documentación esencial
tests/          validaciones Ansible
```

Stacks:

```text
core            nginx, seaweedfs, postgres, redis, etcd, coredns
observability   grafana, prometheus, loki
```

## Uso Local

Validar:

```bash
make ansible-check
make compose-validate
```

Levantar `core`:

```bash
make core-up
```

Esto también aplica buckets S3 locales de forma idempotente.

Ver logs:

```bash
make core-logs
```

Bajar:

```bash
make core-down
```

## Bridge Reusable

El SDK/CLI común vive en:

```text
ops/bridge
```

Ejemplo:

```bash
cd ops/bridge
uv run victus-ingest --help
```

El bridge solo comunica con infraestructura común. No implementa Docling, claims, embeddings, Qdrant ni lógica interna de otros repos.

## Deploy

El deploy productivo ocurre desde:

```text
.github/workflows/deploy-all.yml
```

Los secretos vienen desde Infisical vía GitHub OIDC.

## Documentación

- [Docs](README.md)
- [Setup](setup.md)
- [Arquitectura](architecture.md)
- [Contratos](contracts.md)
- [Operación](operations.md)
- [Seguridad](security.md)
- [Roadmap](roadmap.md)

