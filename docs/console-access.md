# Public administration is disabled

The Coolify nginx configuration returns **403** for `/console` and its normalized
path variants. Regular AppFlowy web, API, authentication and sync routes are not
changed. The source no longer deploys the optional `admin_frontend` service
behind `/console`; its old Node/Next runtime was not updated or replaced. This
retires one unused component, not every vulnerability. Changing the source does
not by itself change a running deployment.

## Check the source

```bash
python3 -I tests/admin-retirement.py
```

It reads only `docker compose config` output for `docker-compose-coolify.yml`,
using an empty `HOME`/`DOCKER_CONFIG`, `--env-file /dev/null` and
`--no-interpolate`, so no
private `.env`, credentials or host environment are read, and no daemon, image or
network operation occurs. It must end with `ALL PASS` and checks that
`admin_frontend` and its nginx backend variable are gone, the other services and
data volumes are still defined, the `/console` 403 guard and normal gotrue/API
routes remain, and MinIO still uses `pull_policy: never`. Exit 2 means Docker
Compose was unavailable, not a pass.

## Check access

```bash
bash tests/console-access.sh origin
bash tests/console-access.sh public
```

Both commands must end with `ALL PASS`. They check console denial, including
encoded separators, unchanged root/API/auth statuses and an unrelated sibling
host. Bodies and cookies are discarded; no credentials or stored-data writes are
used. See `--help` for `HOST`, `SIBLING_HOST`, `ORIGIN_IP`, `CONNECT_TO`, `MAX_TIME`
and exit codes. Origin mode ignores configured HTTP(S) proxies (`--noproxy '*'`),
pins the hostname to `127.0.0.1` by default and skips certificate validation only
for that direct local routing check. Public mode uses ordinary DNS, certificate
validation and any configured proxy.

Expected codes pin this deployment: `/` redirects (302), while GoTrue/API health
and the sibling host return 200. This is not a generic 2xx/3xx liveness probe.
`CONNECT_TO` limits each connection phase; `MAX_TIME` limits one curl check,
including its redirects. Neither is a deadline for the complete script.

### Proxy regression

A proxy would otherwise bypass `--resolve` and let a healthy public route mask a
stale origin. This run uses an unusable dummy proxy and must still end with
`ALL PASS`:

```bash
P=http://127.0.0.1:9
env HTTP_PROXY=$P http_proxy=$P HTTPS_PROXY=$P https_proxy=$P ALL_PROXY=$P \
  all_proxy=$P NO_PROXY= no_proxy= bash tests/console-access.sh origin
```

## Deploy without replacing the stack

The console guard is already deployed. Retiring admin requires no nginx reload
or recreation. If changing the guard separately, keep the source and generated
nginx command consistent: a reload alone cannot update the bootstrap command
that a later container restart runs.

Publish the source **before** stopping admin. Verify automatic-deployment skip
behavior first: every new commit in the push must include `[skip ci]` or
`[skip cd]`; leave the auto-deploy setting unchanged. Do not use Coolify's
**Restart** or **Redeploy** for this retirement: they can run a full-stack deploy
for this Git compose application and recreate other services. The generated
compose file is deployment output, not the durable source. Cached MinIO images
use `pull_policy: never` and must be preserved. Do not expose or copy
credential/environment files.

### Retire the running admin container

Deleting the service from the source does not stop an existing container. Retire
only that container, as a separate explicit step: do not run a full-stack
deployment, pull images, recreate other services or touch volumes and data. Keep
the stopped container and its image until the checks below pass, so rollback stays
possible. Cached MinIO and other images are left untouched. After retirement, run
both access probes above (`/console` must still be 403, root/API/auth statuses
unchanged) and have a human confirm desktop login and sync, which these
credential-free probes do not cover.

## Rollback

For an immediate admin-retirement rollback, start only the retained admin
container; leave `/console` blocked and do not recreate other services. Restore
the `admin_frontend` definition from version control only for an intentional
future deployment. A later full-stack deployment may remove the stopped rollback
container, so do not rely on its indefinite retention.

Reverting the console guard is a separate explicit decision: it would make the
public console reachable again and is not required to restore internal admin.
Authenticated desktop login/sync is not covered by these credential-free probes.
