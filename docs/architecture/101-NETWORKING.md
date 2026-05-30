---
id: victus-infra-networking-architecture
title: Networking Architecture
status: active
updated_at: 2026-05-30
owners:
  - CarlosGebard/victus-infra
related_docs:
  - ../100-ARCHITECTURE.md
  - ../operations/202-DEPLOYMENT.md
tags:
  - networking
  - docker-compose
  - tailscale
  - coredns
---

# Networking Architecture

## Overview

Networking is split between Docker-internal networks, Tailscale private access,
and CoreDNS private service naming.

## Docker Networks

Each stack owns an internal backend network:

```text
core_backend            core service traffic
observability_backend   observability service traffic
llm_backend             LiteLLM, Langfuse, and LLM Postgres traffic
```

Cross-stack service discovery uses:

```text
infra_shared_backend
```

This shared network is external and must exist before stack startup.

## Private Access

Production private access is through Tailscale.

LLM HTTP services are reached through private NGINX:

```text
LiteLLM    http://litellm.victus.io
Langfuse   http://langfuse.victus.io
```

Production does not publish LiteLLM or Langfuse service ports directly. NGINX
binds to the configured Tailscale IP and proxies to the services over
`infra_shared_backend`.

## DNS

CoreDNS owns private DNS for the `victus.io` zone.

The core stack provides DNS-backed service names for private infrastructure
consumers. DNS target IP is derived from runtime configuration.

LLM private names:

```text
litellm.victus.io    <TAILSCALE_IPV4>
langfuse.victus.io   <TAILSCALE_IPV4>
```

## Boundaries

- Postgres and Redis are private infrastructure services.
- LLM Postgres is internal to the `llm` stack.
- Public exposure must go through explicit edge routing.
