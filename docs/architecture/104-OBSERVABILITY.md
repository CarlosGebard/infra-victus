---
id: victus-infra-observability-architecture
title: Observability Architecture
status: active
updated_at: 2026-05-30
owners:
  - CarlosGebard/victus-infra
related_docs:
  - ../100-ARCHITECTURE.md
  - ../operations/204-TROUBLESHOOTING.md
tags:
  - observability
  - prometheus
  - loki
  - langfuse
---

# Observability Architecture

## Overview

Victus observability has two layers:

```text
infrastructure observability   Prometheus, Loki
LLM observability              Langfuse via LiteLLM callbacks
```

## Infrastructure Observability

The `observability` stack owns:

```text
prometheus   metrics collection
loki         log storage and querying
```

## LLM Observability

The `llm` stack owns:

```text
litellm    gateway callbacks
langfuse   LLM tracing, cost, and audit surface
```

LiteLLM sends success and failure callbacks to Langfuse.

## Boundaries

- Prometheus and Loki observe infrastructure runtime health.
- Langfuse observes LLM requests, cost, and traces.
- Provider API keys are managed by LiteLLM and persisted in Postgres.
