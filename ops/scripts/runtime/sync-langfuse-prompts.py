#!/usr/bin/env python3
"""Sync repository-owned prompt files to Langfuse prompt management."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_MANIFEST = REPO_ROOT / "prompts" / "langfuse-prompts.json"


def load_manifest(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    prompts = data.get("prompts")
    if not isinstance(prompts, list):
        raise ValueError(f"{path} must contain a prompts list")

    return prompts


def load_env_file(path: Path) -> None:
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue

            name, value = line.split("=", 1)
            os.environ.setdefault(name, value)


def build_payload(manifest_path: Path, item: dict) -> dict:
    prompt_type = item.get("type", "chat")
    prompt_path = manifest_path.parent / item["path"]
    content = prompt_path.read_text(encoding="utf-8")

    if prompt_type == "chat":
        prompt = [{"role": item.get("role", "system"), "content": content}]
    elif prompt_type == "text":
        prompt = content
    else:
        raise ValueError(f"Unsupported prompt type for {item['name']}: {prompt_type}")

    payload = {
        "name": item["name"],
        "type": prompt_type,
        "prompt": prompt,
        "labels": item.get("labels", []),
    }

    config = item.get("config")
    if config is not None:
        payload["config"] = config

    return payload


def post_prompt(
    base_url: str,
    public_key: str,
    secret_key: str,
    payload: dict,
    retries: int,
    retry_interval: int,
) -> None:
    auth = base64.b64encode(f"{public_key}:{secret_key}".encode("utf-8")).decode("ascii")
    request = urllib.request.Request(
        url=f"{base_url.rstrip('/')}/api/public/v2/prompts",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                if response.status >= 300:
                    raise RuntimeError(f"Langfuse returned HTTP {response.status}")
            return
        except urllib.error.HTTPError:
            raise
        except Exception:
            if attempt == retries:
                raise
            time.sleep(retry_interval)


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} is required")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Prompt manifest path.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print prompt names that would be synced without calling Langfuse.",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=None,
        help="Optional env file containing LANGFUSE_BASE_URL/HOST and API keys.",
    )
    parser.add_argument("--retries", type=int, default=12)
    parser.add_argument("--retry-interval", type=int, default=5)
    args = parser.parse_args()

    if args.env_file is not None:
        load_env_file(args.env_file)

    manifest_path = args.manifest.resolve()
    prompts = load_manifest(manifest_path)
    payloads = [build_payload(manifest_path, item) for item in prompts]

    if args.dry_run:
        for payload in payloads:
            labels = ",".join(payload.get("labels", [])) or "-"
            config = payload.get("config", {})
            print(
                f"{payload['name']} type={payload['type']} labels={labels} "
                f"temperature={config.get('temperature', '-')}"
            )
        return 0

    base_url = (
        os.environ.get("LANGFUSE_BASE_URL")
        or os.environ.get("LANGFUSE_NEXTAUTH_URL")
        or os.environ.get("LANGFUSE_HOST")
    )
    if not base_url:
        raise RuntimeError("LANGFUSE_BASE_URL, LANGFUSE_NEXTAUTH_URL, or LANGFUSE_HOST is required")
    public_key = require_env("LANGFUSE_PUBLIC_KEY")
    secret_key = require_env("LANGFUSE_SECRET_KEY")

    for payload in payloads:
        try:
            post_prompt(
                base_url,
                public_key,
                secret_key,
                payload,
                args.retries,
                args.retry_interval,
            )
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            print(f"failed: {payload['name']}: HTTP {error.code}: {detail}", file=sys.stderr)
            return 1
        except Exception as error:
            print(f"failed: {payload['name']}: {error}", file=sys.stderr)
            return 1
        print(f"synced: {payload['name']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
