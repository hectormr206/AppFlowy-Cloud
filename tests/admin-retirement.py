#!/usr/bin/env python3
"""Regression: the Coolify compose file no longer deploys the unused admin UI.

Reads only the public `docker compose config` output of docker-compose-coolify.yml.
The call is isolated: empty HOME/DOCKER_CONFIG, no .env (--env-file /dev/null), no
interpolation, so no private files or host environment are read. No daemon, image
or network operation is performed.

Usage: python3 tests/admin-retirement.py   (exit 0 = PASS, 1 = FAIL, 2 = UNAVAILABLE)
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

COMPOSE_FILE = Path(__file__).resolve().parent.parent / "docker-compose-coolify.yml"
RETAINED_SERVICES = {
    "nginx", "minio", "postgres", "pgadmin", "redis", "gotrue", "appflowy_cloud",
    "ai", "appflowy_web", "appflowy_worker", "appflowy_search",
}
RETAINED_VOLUMES = {"postgres_data", "minio_data", "keyword_index_data"}


def load_config():
    with tempfile.TemporaryDirectory() as empty:
        env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": empty,
               "DOCKER_CONFIG": empty}
        try:
            proc = subprocess.run(
                ["docker", "compose", "-f", str(COMPOSE_FILE), "--env-file", "/dev/null",
                 "config", "--no-interpolate", "--format", "json"],
                env=env, cwd=empty, capture_output=True, text=True, timeout=20)
        except (OSError, subprocess.TimeoutExpired) as exc:
            print(f"UNAVAILABLE: docker compose could not run: {exc}")
            sys.exit(2)
    if proc.returncode != 0:
        print(f"UNAVAILABLE: compose config exited {proc.returncode}\n{proc.stderr[:500]}")
        sys.exit(2)
    return json.loads(proc.stdout)


def main():
    cfg = load_config()
    services = cfg.get("services", {})
    command = services.get("nginx", {}).get("command") or ""
    nginx_cmd = "\n".join(command) if isinstance(command, list) else command
    nginx_cmd = nginx_cmd.replace("\\$", "$").replace("$$", "$").replace('\\"', '"')
    failures = []

    def location_body(prefix):
        _, marker, tail = nginx_cmd.partition(f"location {prefix} {{")
        return tail.split("location ", 1)[0] if marker else ""

    def check(ok, message):
        if not ok:
            failures.append(message)

    check("admin_frontend" not in services, "admin_frontend service is still deployed")
    check("admin_frontend" not in nginx_cmd, "nginx still references admin_frontend")
    check(not any("admin_frontend" in json.dumps(s.get("depends_on", {}))
                  for s in services.values()), "a service still depends on admin_frontend")
    check(RETAINED_SERVICES.issubset(services),
          f"missing services: {sorted(RETAINED_SERVICES - set(services))}")
    check(RETAINED_VOLUMES.issubset(cfg.get("volumes", {})),
          f"missing volumes: {sorted(RETAINED_VOLUMES - set(cfg.get('volumes', {})))}")
    check("return 403;" in location_body("/console"),
          "nginx /console 403 guard is missing")
    check('set $gotrue_backend "http://gotrue:9999";' in nginx_cmd
          and "proxy_pass $gotrue_backend;" in location_body("/gotrue/"),
          "normal gotrue proxy route changed")
    check('set $appflowy_cloud_backend "http://appflowy_cloud:8000";' in nginx_cmd,
          "normal API upstream changed")
    check(services.get("minio", {}).get("pull_policy") == "never",
          "minio pull_policy is no longer never")

    if failures:
        for message in failures:
            print(f"FAIL: {message}")
        return 1
    print("ALL PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
