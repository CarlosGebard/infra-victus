# Infra Victus

Infraestructura reproducible para el VPS de Victus y la plataforma privada de datos RAG.

Este repositorio administra la capa de infraestructura de la aplicación. El bootstrap del host vive intencionalmente en el repositorio hermano `server-bootstrap`.

[Read in English](../README.md)

## Propósito

`infra-victus` entrega un runtime pequeño y explícito basado en Docker Compose para:

- almacenamiento privado de objetos para datos RAG
- DNS privado sobre Tailscale
- enrutamiento edge con NGINX
- observabilidad con Grafana, Prometheus y Loki
- despliegues repetibles con Ansible y GitHub Actions

La aplicación RAG todavía está en desarrollo. La base de almacenamiento ya está implementada: SeaweedFS S3, routing privado virtual-host, buckets declarativos y prefixes para datos RAG.

Siguiente gran incorporación de infraestructura: Qdrant para almacenamiento vectorial.

## Arquitectura

Source of truth del runtime:

```text
compose/projects/
  core/
  observability/
```

Automatización operativa:

```text
ansible/
ops/
.github/workflows/
```

Configuración:

```text
compose/configs/
docs/
```

## Servicios

### Core

- `nginx`
  - router privado edge
  - routing S3 virtual-host
  - rutas internas para SeaweedFS y observabilidad
- `seaweedfs`
  - almacenamiento compatible con S3
  - guarda datos crudos RAG, documentos normalizados, salidas de extracción, entradas de embeddings y backups
- `etcd`
  - backing store para registros DNS privados
  - solo interno; no se expone al host
- `coredns`
  - DNS privado autoritativo para `victus.io`
  - sirve `s3.victus.io` y `*.s3.victus.io`

### Observabilidad

- `grafana`
- `prometheus`
- `loki`

### Removido

El antiguo stack `personal` y el servicio CouchDB fueron retirados. No pertenecían al proyecto principal Victus.

## DNS Privado

El DNS privado está pensado para clientes Tailscale.

Contrato actual:

```text
s3.victus.io
*.s3.victus.io
```

Ejemplos:

```text
victus-rag.s3.victus.io
victus-backups.s3.victus.io
victus-tmp.s3.victus.io
```

El wildcard resuelve hacia la IP Tailscale donde corre NGINX.

Ver:

- [Contrato DNS privado](private-dns-contract.md)

## Contrato de Almacenamiento RAG

Contrato declarativo de buckets S3:

```text
compose/configs/seaweedfs/buckets.json
```

Buckets administrados:

```text
victus-rag
victus-backups
victus-tmp
```

Prefixes administrados dentro de `victus-rag`:

```text
pipeline/01_metadata/
pipeline/02_normalized_pdfs/
pipeline/03_docling_heuristics/
pipeline/04_claims/
rag/experiments/
rag/embeddings/
rag/retrieval/
```

El deploy aplica este contrato de forma idempotente. Crea buckets faltantes y objetos `.keep` para prefixes faltantes. No borra datos existentes.

## Desarrollo Local

Validar configuración:

```bash
make compose-validate
make ansible-check
```

Levantar `core` local:

```bash
make core-up
```

Levantar `core` local exponiendo DNS/NGINX en la IP Tailscale local:

```bash
make core-up-tailscale
# o:
./ops/scripts/local/up-core.sh --tailscale
```

Inspeccionar DNS:

```bash
dig @127.0.0.1 -p 1053 s3.victus.io
dig @127.0.0.1 -p 1053 test.s3.victus.io
```

Inspeccionar buckets S3 por red Docker interna:

```bash
docker run --rm --network core_core_backend \
  -e AWS_ACCESS_KEY_ID=change-me \
  -e AWS_SECRET_ACCESS_KEY=change-me \
  amazon/aws-cli:2.17.60 \
  --endpoint-url http://seaweedfs:8333 s3 ls
```

## Modelo de Deploy

Orden de rollout:

```text
observability -> core
```

Deploy:

```text
.github/workflows/deploy-all.yml
```

Validación:

```text
.github/workflows/validate-infra.yml
```

Los secretos se obtienen desde Infisical usando GitHub OIDC.

## Documentación

- [Overview de docs](README.md)
- [Runbook de deploy](runbooks/deploy.md)
- [Contrato DNS privado](private-dns-contract.md)
- [Secrets y variables](secrets-and-variables.md)
- [ADR: decisiones de estructura](adr/0001-structure-decisions.md)
- [ADR: DNS privado con CoreDNS y etcd](adr/0002-core-private-dns-with-coredns-etcd.md)

## Estado

Completado:

- runtime Docker Compose separado en `core` y `observability`
- CouchDB removido de la infraestructura
- almacenamiento SeaweedFS S3
- DNS privado con CoreDNS
- routing S3 virtual-host
- buckets y prefixes RAG declarativos
- automatización de deploy con Ansible/GitHub Actions

En progreso / próximo:

- Qdrant para búsqueda vectorial
- provisioning de dashboards/datasources Grafana
- workloads de aplicación RAG
