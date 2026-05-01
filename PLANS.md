## Goal
Expose SeaweedFS S3 through private NGINX path on MagicDNS hostname so small Tailscale-only setup can use path-style S3 without extra DNS or hardcoded `100.x` IPs.

## Scope
- Add private `/seaweed/s3/` reverse proxy path in rendered core NGINX config.
- Keep existing direct `s3.*` host-based routing untouched for backward compatibility.
- Update checked-in local NGINX config parity and deploy runbook.

## Assumptions
- Private access happens through Tailscale hostname such as `infra-victus-vps.tail116b62.ts.net`.
- HTTP over tailnet acceptable for this private path-style endpoint.
- Clients will use path-style S3 addressing.

## Steps
1. Add `/seaweed/s3/` location in Ansible NGINX template with `private-access.conf`, upstream `seaweedfs:8333`, and trailing-slash proxy behavior to strip prefix.
2. Mirror same route in checked-in local NGINX config for repo parity.
3. Update runbook to document MagicDNS + path-style private S3 endpoint.

## Validation
- `make compose-validate`
- `make ansible-check`
- Manual curl after deploy:
  - `curl http://<magicdns-host>/seaweed/master/`
  - `curl http://<magicdns-host>/seaweed/filer/`
  - `curl http://<magicdns-host>/seaweed/s3/`

## Risks
- Path-style endpoint less universal than dedicated S3 hostname for advanced clients and presigned URLs.
- Validation in this environment may stop on missing Docker socket or missing `ansible-playbook`.
