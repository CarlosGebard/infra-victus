---
id: victus-infra-data-storage-architecture
title: Data Storage Architecture
status: active
updated_at: 2026-05-30
owners:
  - CarlosGebard/victus-infra
related_docs:
  - ../100-ARCHITECTURE.md
  - ../300-CONTRACTS.md
tags:
  - storage
  - postgres
  - seaweedfs
  - redis
---

# Data Storage Architecture

## Overview

Persistent infrastructure state is kept in stack-owned data paths and backed by
Docker volumes or host bind mounts.

## Core Storage

```text
SeaweedFS   S3-compatible object storage
Postgres    durable registry database
Redis       durable event stream
etcd        CoreDNS backend state
```

Production paths:

```text
/srv/data/postgres/victus-registry
/srv/data/redis
/srv/data/etcd/core-dns
```

## Observability Storage

```text
Prometheus   metrics TSDB
Loki         log store
```

Production paths:

```text
/srv/data/observability/prometheus
/srv/data/observability/loki
```

## LLM Storage

The `llm` stack uses one Postgres container with separate databases:

```text
litellm    virtual keys, spend, gateway metadata
langfuse   traces, costs, audit data, app state
```

Production path:

```text
/srv/data/llm/postgres
```

Provider API keys are managed through the LiteLLM UI and persisted in the
LiteLLM database. They are not stored in git.
