---
id: victus-infra-operations-roadmap
title: Operations Roadmap
status: active
updated_at: 2026-05-27
owners:
  - CarlosGebard/victus-infra
---

# Operations Roadmap

## Near-Term Cleanup

- remove any workflow output that could reveal secret material.
- confirm `seaweedfs` shared-network access requirements for consumer repos.
- keep validating with `make ansible-check` and `make compose-validate`.

## Future Infrastructure Work

- automated Postgres and SeaweedFS backups.
- metrics per processing stage.
- Qdrant as a controlled stack if infrastructure ownership is required.
- additional runbooks for backup and restore once automated backups exist.

## Consumer Repository Follow-Up

Expected future consumers:

```text
victus-processing
victus-rag
victus-analytics
```

Consumer-specific implementation plans belong in those repositories, not in
`victus-infra`.

