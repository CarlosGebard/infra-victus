---
id: wikijs-operation
title: Wiki.js operation
status: active
---

# Wiki.js operation

Wiki.js is the source of truth for Victus documentation at
`https://wiki.victus.fit`. Edit pages in its browser UI; no repository push is
needed to publish a page change.

Before the first restored deployment, verify on the VPS:

```bash
sudo test -s /srv/secrets/runtime/wiki.env
sudo test -d /srv/data/wiki/postgres
```

Inspect the running stack:

```bash
sudo docker compose --env-file /srv/secrets/runtime/wiki.env \
  -f /srv/apps/wiki/compose.yml -f /srv/apps/wiki/compose.prod.yml ps
sudo docker logs --tail 100 wiki
```

Do not delete `/srv/data/wiki/postgres` or `/srv/secrets/runtime/wiki.env`.
