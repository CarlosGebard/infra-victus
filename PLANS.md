# Plans

## Langfuse Prompt Sync

Goal: move the current production Markdown prompts into a versioned repository
location and provide a repeatable Langfuse sync path.

Scope:
- `prompts/`
- `ops/scripts/runtime/sync-langfuse-prompts.py`
- `.github/scripts/deploy-llm-fast.sh`
- `docs/operations/206-LANGFUSE-PROMPTS.md`
- operations documentation index links

Assumptions:
- All provided Markdown files are currently production prompts.
- All prompts should be created as Langfuse chat prompts with a single `system`
  message.
- Temperature is `0` for all prompts.

Steps:
1. Move root Markdown prompts into `prompts/`.
2. Add a manifest with Langfuse names, prompt files, labels, and config.
3. Add a dependency-free sync script that calls the Langfuse public API.
4. Add a minimal operations runbook.
5. Validate dry-run output and Python syntax.
6. Reuse the existing Infisical-backed `llm.env` in deploy to publish prompts.

Validation:
- `python3 ops/scripts/runtime/sync-langfuse-prompts.py --dry-run`
- `python3 -m py_compile ops/scripts/runtime/sync-langfuse-prompts.py`

Risks:
- Prompt names may need app-specific prefixes if existing Langfuse names differ.
- Direct `production` labeling updates production immediately in the target
  Langfuse project.
