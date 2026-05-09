# Private DNS Contract

## Scope

Private DNS is served by CoreDNS inside the `core` stack.

This DNS is intended for Tailscale/private-network clients only. It is not public DNS.

## Zone

Authoritative private zone:

```text
victus.io
```

## Current Records

S3 endpoint:

```text
s3.victus.io
```

S3 bucket virtual hosts:

```text
*.s3.victus.io
```

Examples:

```text
photos.s3.victus.io
avatars.s3.victus.io
backups.s3.victus.io
```

All `*.s3.victus.io` names resolve to the Tailscale IP where NGINX is running.

## Routing

NGINX owns S3 HTTP routing.

S3 uses virtual-host style only:

```text
http://<bucket>.s3.victus.io
```

Path-style S3 is intentionally disabled:

```text
/seaweed/s3/
```

## CoreDNS Data Model

CoreDNS serves:

- `s3.victus.io` from SkyDNS data under etcd
- `*.s3.victus.io` from a CoreDNS `template` rule

The runtime sync script writes base SkyDNS data:

```text
/skydns/io/victus/s3/x1
```

Example value:

```json
{"host":"100.x.y.z","ttl":30}
```

Wildcard records are not stored per bucket while the CoreDNS template is enabled.

## Runtime Sync

Script:

```text
ops/scripts/runtime/sync-core-dns.sh
```

On the VPS it is copied to:

```text
/srv/apps/core/scripts/sync-core-dns.sh
```

The script:

- detects the IPv4 address on `tailscale0`
- updates `core.env`
- recreates `coredns`
- writes the base S3 DNS record into etcd

## Client Resolver Contract

Clients must send `victus.io` DNS queries to the CoreDNS server.

Recommended production setup:

```text
Tailscale split DNS:
victus.io -> <tailscale-ip-of-victus-main-server>
```

Manual test from any Tailscale node:

```bash
dig @<tailscale-ip-of-dns-server> s3.victus.io
dig @<tailscale-ip-of-dns-server> test.s3.victus.io
```

Local test mode on a developer machine:

```bash
make core-up-tailscale
# or:
./ops/scripts/local/up-core.sh --tailscale
```

This publishes:

```text
CoreDNS -> <local-tailscale-ip>:53
NGINX   -> <local-tailscale-ip>:8080
```

Then test from another Tailscale node:

```bash
dig @<local-tailscale-ip> test.s3.victus.io
curl -I -H 'Host: test.s3.victus.io' http://<local-tailscale-ip>:8080/
```

## Ports

CoreDNS:

```text
53/udp
53/tcp
```

NGINX:

```text
80/tcp
443/tcp
```

These ports should be reachable over `tailscale0`, not exposed as public DNS.

## Naming Rules

Reserved:

```text
s3.victus.io
*.s3.victus.io
```

Future service names should use one label under `victus.io`:

```text
api.victus.io
grafana.victus.io
prometheus.victus.io
```

Do not place non-S3 services under:

```text
*.s3.victus.io
```

That namespace belongs to S3 buckets.

## Managed S3 Buckets

Declarative bucket contract:

```text
compose/configs/seaweedfs/buckets.json
```

Current buckets:

```text
victus-rag
victus-backups
victus-tmp
```

Current `victus-rag` prefixes:

```text
pipeline/01_metadata/
pipeline/02_normalized_pdfs/
pipeline/03_docling_heuristics/
pipeline/04_claims/
rag/experiments/
rag/embeddings/
rag/retrieval/
```

Runtime apply script:

```text
ops/scripts/runtime/apply-s3-buckets.py
```

The script is idempotent. It creates missing buckets and `.keep` objects for missing prefixes. It does not delete buckets, prefixes, or objects.
