---
id: victus-infra-langfuse-prompts
title: Langfuse Prompts
status: active
updated_at: 2026-06-01
owners:
  - CarlosGebard/victus-infra
related_services:
  - llm
  - langfuse
related_docs:
  - ../200-OPERATIONS.md
tags:
  - operations
  - langfuse
  - prompts
---

# Langfuse Prompts

Repository-owned prompts live in `prompts/`.

The source manifest is:

```text
prompts/langfuse-prompts.json
```

Each manifest entry defines the Langfuse prompt name, prompt file, prompt type,
deployment labels, and model config. The current prompts are chat prompts with a
single `system` message, `temperature: 0`, and the `production` label.

## Dry Run

```bash
python3 ops/scripts/runtime/sync-langfuse-prompts.py --dry-run
```

## Sync To Langfuse

In production, the `llm` deployment reads Langfuse API credentials from
Infisical, materializes them into `/srv/secrets/runtime/llm.env`, and syncs
prompts after the Langfuse service is started. The sync uses
`LANGFUSE_NEXTAUTH_URL` from that env file as the host-reachable Langfuse base
URL.

For manual sync on a host that already has the runtime env file:

```bash
python3 ops/scripts/runtime/sync-langfuse-prompts.py \
  --env-file /srv/secrets/runtime/llm.env
```

For local testing against a separate Langfuse project, provide the same
variables through the environment:

```bash
export LANGFUSE_BASE_URL="https://example.langfuse.local"
export LANGFUSE_PUBLIC_KEY="pk-lf-..."
export LANGFUSE_SECRET_KEY="sk-lf-..."
```

Langfuse creates a new version when a prompt with the same name already exists.
Because these prompts are currently used in production, the sync assigns the
`production` label directly.

## Change Procedure

1. Edit the prompt Markdown file in `prompts/`.
2. Update `prompts/langfuse-prompts.json` only when name, type, labels, or
   config changes.
3. Run the dry run.
4. Sync to the intended Langfuse project.
5. Verify the new production version in Langfuse before relying on it from
   consuming applications.
