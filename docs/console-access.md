# Public administration is disabled

The Coolify nginx configuration returns **403** for `/console` and its normalized
path variants. Regular AppFlowy web, API, authentication and sync routes are not
changed. The admin container remains internal; this is containment, not a Node or
Next.js dependency update or proof that every component is vulnerability-free.

## Check access

```bash
bash tests/console-access.sh origin
bash tests/console-access.sh public
```

Both commands must end with `ALL PASS`. They check console denial, including
encoded separators, unchanged root/API/auth statuses and an unrelated sibling
host. Bodies and cookies are discarded; no credentials or stored-data writes are
used. See `--help` for `HOST`, `SIBLING_HOST`, `ORIGIN_IP`, `CONNECT_TO`, `MAX_TIME`
and exit codes. Origin mode pins the hostname to `127.0.0.1` by default and skips
certificate validation only for that direct local routing check. Public mode
uses ordinary DNS and certificate validation.

## Deploy without replacing the stack

Keep the source and Coolify's generated nginx command consistent. Validate nginx
configuration before selectively recreating **only nginx**, with no dependencies
and no image pull. A reload alone is insufficient if a later container restart
would regenerate the previous configuration from its old command.

Check automatic-deployment behavior before publishing the commit. The deployed
Coolify recognizes `[skip ci]` in this maintenance commit and skips its automatic
deployment; leave the auto-deploy setting unchanged. Do not trigger a full-stack
deployment: cached MinIO images use `pull_policy: never` and must be preserved.
Do not expose or copy environment/credential files for this change.

## Rollback

Revert only the console-block change and restore the previous nginx command from
the protected routing-config backup, then selectively recreate nginx. This makes
the public console reachable again; do it only as an explicit rollback decision.
Authenticated desktop login/sync is not covered by these credential-free probes.
