#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["aiohttp>=3.12,<4"]
# ///
"""A LAN-only Lemonade / custom llama.cpp reverse proxy, in one file.

    uv run lemonade_router.py --help
    uv run lemonade_router.py --check-config
    uv run lemonade_router.py --ensure-service
    uv run lemonade_router.py

SETUP
  1. On the Fedora machine, move Lemonade from 8080 to 13305 and bind it to
     loopback. Current releases: `lemonade config set port=13305 host=127.0.0.1`.
     Alternatively configure/restart lemond using its installed version's CLI.
     Keep Lemonade's bundled backend settings; this script never changes them.
  2. Edit CONFIG below. Enable/copy the example custom model, supplying real
     executable/model paths. Commands are argv lists, NOT shell commands.
     A launcher may `exec llama-server ...` OR stay alive and wait for it as a
     subprocess. Foreground Bash/Python wrappers, including `command & wait`,
     are supported; `exec` is optional. The router stops the whole process group.
     Keep children in that group/session: no `setsid`, `setpgid`, Bash job control
     (`set -m`), daemonization, or handing the server off to an external service.
  3. Run this script on THAT machine as your normal user, not root. Open TCP 8080
     in the LAN firewall. Use http://strixhalo.local:8080 in browsers/mobile,
     or http://strixhalo.local:8080/v1 in OpenAI clients. Both /v1 and /api/v1 work.
     Set an explicit URL in clients: UDP auto-discovery is NOT proxied. Disable
     Lemonade's broadcast if you don't want it advertising the private port.
  4. Open http://strixhalo.local:8080/_router for status and update offers.

SYSTEMD / BOOT
  Run `uv run lemonade_router.py --ensure-service` as your NORMAL user. It uses
  sudo to install /etc/systemd/system/lemonade-router.service, reload systemd,
  and enable the service at boot (no login/lingering needed). It does NOT start
  or restart the service, so running it again cannot interrupt active work.

    sudo systemctl start lemonade-router.service
    sudo systemctl status lemonade-router.service
    journalctl -u lemonade-router.service -f

  Stop any manually running router before starting the service. Installation
  copies THIS script (including CONFIG) to ~/.local/share/lemonade-router/, so
  keeping your source in /tmp does not break boot. Edit CONFIG in that installed
  copy, or rerun --ensure-service from your edited source, then restart the
  service when idle. Reinstallation preserves the environment file and refuses
  to overwrite an unrelated unit. On SELinux-enforcing Fedora hosts, the unit
  uses Fedora's unconfined_service_t domain so it can execute uv and the PEP
  723 Python environment from the user's home directory. The selected uv binary
  is also refreshed as /usr/local/bin/lemonade-router-uv, giving systemd a
  system-labelled executable for the initial process launch.

  The unit runs as your user, with HOME set, a minimal PATH, and available
  render/video groups for boot-time GPU access. It uses an absolute uv path to
  resolve the PEP 723 environment, not a temporary Python virtualenv. Shell
  startup files are NOT sourced. Set additional variables/command search paths
  in ~/.config/lemonade-router/service.env (systemd KEY=value syntax). On FIRST
  installation only, existing Lemonade API keys and GITHUB_TOKEN are saved there
  with mode 0600; other shell variables are not copied. Use absolute launcher and
  CLI paths in CONFIG if their binaries aren't on the service's PATH. The
  service still runs with the invoking user's Unix UID/GID.

  The local lemond service is softly requested/ordered before the router, but
  stopping it for an RPM update does not stop the router. Graceful stop allows
  up to two hours for an in-progress maintenance transaction to finish. Service
  installation does NOT grant passwordless sudo for the optional RPM updater.
  To remove: `sudo systemctl disable --now lemonade-router.service`, remove the
  unit file above, and run `sudo systemctl daemon-reload`.

BEHAVIOR / LIMITS
  * Custom inference routing is ONLY for POST /chat/completions, /completions,
    and /responses (under /v1 or /api/v1, including legacy /v0 prefixes). Images
    pasted into coding agents remain part of these JSON requests and pass through
    unchanged; the custom model/launcher must itself support vision.
  * All other inference paths go unchanged to Lemonade: embeddings, image
    generation/editing, audio, reranking, and all WebSocket traffic. The router
    does not inspect their model fields or multipart bodies. GPU-using traffic
    still stops custom launchers first; passive log WebSockets are exempt.
    Unknown paths, including the web UI/assets, also go to Lemonade. Model lists/
    details, health, and custom load/unload management are still intercepted.
    Custom IDs override colliding Lemonade IDs. Capabilities are configured,
    not discovered by loading.
  * One GPU-work request at a time, including the ENTIRE response stream or
    realtime-audio WebSocket session. Other work queues; UI health/assets/listing
    remain responsive. An open realtime session must close before switching to
    another model. Log WebSockets don't reserve the GPU. Custom models stay loaded
    until a switch, explicit unload, or router shutdown (SIGINT/SIGTERM).
  * Unknown mutating requests conservatively stop custom launchers before going
    to Lemonade, so its management APIs cannot load over a custom model. Async
    Lemonade jobs are checked before switching/maintenance. All inference and
    management clients must use this router: direct access bypasses arbitration.
    This is not an Ollama/Anthropic-to-OpenAI protocol translator for custom models.
  * Custom launch arguments are fixed in CONFIG, not editable from Lemonade UI.
    Pull/delete/options writes for custom models are rejected; downloads/settings
    for Lemonade models still pass through. Other inference endpoints are NOT
    translated for custom models, even if a request names a custom model ID.
  * No HTTPS/WSS proxying, TLS termination, or certificate configuration. The
    optional updater DOES use HTTPS to fetch official GitHub release metadata/RPMs.
  * This is Linux/POSIX software (process-group cleanup and flock). Wrapper
    subprocesses are fine; the launcher must remain alive and supervise them.
    Do not run multiple router workers, daemonizing launchers, or container launch
    commands whose lifetime isn't governed by the launcher's process group. A hard crash
    or SIGKILL cannot run cleanup; orphaned listener ports are refused on restart.

UPDATES
  Weekly checks persist across restarts. RPM updates default to NOTIFY; backend
  updates default to automatic when idle. Change either policy to 'off', 'notify',
  or 'auto_when_idle'. No custom builds or model weights are ever updated.
  Backend states come from /system-info; only update_required/update_available
  trigger `lemonade backends install recipe:backend`. No switching to 'latest'.
  RPM updates select the official stable release asset matching the local Fedora
  version/architecture, check SHA256 against GitHub's asset digest, use RPM version
  comparison, then stop/install/start lemond. Restart is attempted even on failure.
  DNF keeps its normal signature policy; this script never adds --nogpgcheck.
  For unattended RPM installation, configure noninteractive authorization as
  described under SUDOERS below. Failed automatic maintenance is NOT retried
  repeatedly; the dashboard offers retry.
  A restart never deliberately interrupts a generation, job, download, or realtime
  session. Log viewers may reconnect after a restart. Background work outside the
  router cannot be made race-free; bind Lemonade to loopback and don't bypass it.

SUDOERS FOR FEDORA RPM AUTO-UPDATES
  The default commands need permission to stop/start ONLY lemond.service and
  install a downloaded RPM. Apply the rules to the ROUTER'S user (the account
  shown by --ensure-service), not the separate lemonade daemon account.

  IMPORTANT: passwordless DNF installation of a user-writable RPM is effectively
  FULL ROOT ACCESS for that user/process: RPMs can contain root-run scriptlets.
  The router's SHA256 check is useful integrity protection, NOT a privilege
  boundary, because an attacker controlling the user can bypass the router or
  replace its cached RPM. A filename/path restriction does not fix this; sudoers
  argument wildcards can also match spaces/extra arguments. The convenience
  rules below are ONLY for an account you fully trust with root privileges.
  Do not grant `NOPASSWD: ALL`, unrestricted `dnf *`, or `systemctl *`.

  Convenience setup for a fully trusted account:
    1. Check `command -v systemctl dnf`; Fedora normally uses /usr/bin for both.
       Substitute actual executable paths if different. Replace alice and
       /home/alice below with your router user and its ABSOLUTE home directory.
       If CONFIG['state_dir'] is customized, adjust the downloads path too.
       Sudoers does not substitute $HOME or CONFIG values for you.
    2. Run `sudo visudo -f /etc/sudoers.d/lemonade-router` and add:

       alice ALL=(root) NOPASSWD: /usr/bin/systemctl stop lemond.service
       alice ALL=(root) NOPASSWD: /usr/bin/systemctl start lemond.service
       alice ALL=(root) NOPASSWD: /usr/bin/dnf -y install /home/alice/.local/state/lemonade-router/downloads/lemonade-server-*.rpm

    3. Protect and validate the file (visudo also validates on save):

       sudo chown root:root /etc/sudoers.d/lemonade-router
       sudo chmod 0440 /etc/sudoers.d/lemonade-router
       sudo visudo -cf /etc/sudoers

    4. As the router user, verify the exact commands are allowed without a
       password. These are LISTING checks only; they do NOT stop or install:

       sudo -n -l /usr/bin/systemctl stop lemond.service
       sudo -n -l /usr/bin/systemctl start lemond.service
       sudo -n -l /usr/bin/dnf -y install /home/alice/.local/state/lemonade-router/downloads/lemonade-server-permission-check.rpm

    5. Set CONFIG['updates']['rpm_policy'] = 'auto_when_idle'. If using systemd,
       edit the installed copy, or rerun --ensure-service from your edited
       source, then `sudo systemctl restart lemonade-router.service` when idle.
       Leave the updater's `sudo -n` in place: it must fail rather than wait for
       a password/TTY. No sudoers rule is needed for ordinary backend updates;
       those go through the unprivileged lemonade CLI to the Lemonade service.

  For REAL least privilege, keep rpm_policy='notify' and install RPMs manually,
  or replace install_command with a separate root-owned helper whose exact
  interface is authorized in sudoers. That helper must independently obtain and
  verify the official release/digest, use root-owned staging, constrain the
  package/version/architecture, and install only that verified RPM. It must NOT
  trust a path/digest supplied by the router or merely wrap `dnf install "$1"`.
  This script does not install such a helper or modify sudoers automatically.

References (APIs differ by installed version; /api/v1 is the conservative default):
  https://github.com/lemonade-sdk/lemonade/blob/main/docs/api/lemonade.md
  https://github.com/lemonade-sdk/lemonade/blob/main/docs/guide/cli.md
  https://github.com/lemonade-sdk/lemonade/blob/main/docs/guide/install/fedora.md
  https://github.com/ggml-org/llama.cpp/tree/master/tools/server
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import contextvars
import fcntl
import grp
import hashlib
import hmac
import json
import logging
import os
import platform
import pwd
import re
import shutil
import signal
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

import aiohttp
from aiohttp import web
from multidict import CIMultiDict
from yarl import URL


CONFIG = {
    "host": "0.0.0.0",
    "port": 8080,
    "lemonade_url": "http://127.0.0.1:13305",  # origin, NOT an API base URL
    "lemonade_api_prefix": "/api/v1",
    # Usually leave None: preserve the client's Authorization header. A backend
    # credential, if set, is used for router control calls AND upstream requests.
    "lemonade_api_key": os.environ.get("LEMONADE_API_KEY"),
    "api_key": os.environ.get("LEMONADE_ROUTER_API_KEY", os.environ.get("LEMONADE_API_KEY")),
    "state_dir": "~/.local/state/lemonade-router",
    "max_body_mib": 256,  # routed JSON buffer limit, including pasted image data
    "connect_timeout": 10,
    "read_timeout": 1800,  # maximum silence on HTTP upstreams, not total duration
    "queue_timeout": 900,
    "stop_timeout": 15,
    "unload_timeout": 120,
    "models": {
        "qwen3.8-flash-next": {
            # I use kksoftwareag/strix-halo-qwen-3.8-flash-next.git with a few edits
            # to config.py to set host and port to what i give here and to run.sh
            # to do the exec with
            #   sudo --login -u tim uv run --directory path/to/checkout qwen38 "$@"
            # so it works even when launched under the init  process
            "enabled": True,  # change paths/command, then set True
            "host": "127.0.0.1",
            "port": 8881,  # choose outside Lemonade's backend ports (often 8001+)
            "api_prefix": "/v1",
            "health_path": "/health",  # root-relative; HTTP 200 means ready
            "startup_timeout": 300,
            # A foreground wrapper is also fine, e.g.:
            "command": [
                "/home/tim/StrixSetup/strix-halo-qwen-3.8-flash-next/run.sh",
                "run",
                "--preset",
                "eh-agent",
            ],
            # "command": [
            #     "/home/YOU/llama-special/build/bin/llama-server",
            #     "--model", "/home/YOU/models/special.gguf",
            #     "--host", "{host}", "--port", "{port}",
            #     "--alias", "{model}", "--n-gpu-layers", "99",
            # ],
            "cwd": None,
            "env": {},  # e.g. {"CUDA_VISIBLE_DEVICES": "0"}
            # Optional different name in upstream JSON requests. Prefer --alias
            # matching the public ID; response bodies are otherwise not rewritten.
            # "upstream_model": "different-backend-alias",
            "api_key": None,
            "metadata": {
                "labels": ["chat", "tool-calling", "code", "agent"],
                "recipe": "llamacpp",
                "max_context_window": 163840,
            },
            "load_options": {},  # read-only options to advertise in the UI
        },
    },
    "updates": {
        "interval_days": 7,
        "idle_seconds": 300,
        "poll_seconds": 60,
        "rpm_policy": "auto_when_idle",
        "backend_policy": "auto_when_idle",
        "backend_allowlist": None,  # None = all eligible Lemonade-managed backends
        "package": "lemonade-server",
        "release_api": "https://api.github.com/repos/lemonade-sdk/lemonade/releases/latest",
        "stop_command": ["sudo", "-n", "systemctl", "stop", "lemond.service"],
        # Passwordless local-RPM installation is root-equivalent; see SUDOERS
        # in --help before authorizing this, or use a verifying root-owned helper.
        "install_command": ["sudo", "-n", "dnf", "-y", "install", "{rpm}"],
        "start_command": ["sudo", "-n", "systemctl", "start", "lemond.service"],
        "lemonade_command": ["lemonade"],
        "command_timeout": 1800,
        "restart_timeout": 120,
    },
}

# Coding requests only. Pasted images live inside chat/Responses JSON, not the
# separate image-generation/editing API. Everything else falls through to Lemonade.
INFERENCE_PATHS = {"/chat/completions", "/completions", "/responses"}
PREFIXES = ("/api/v1", "/api/v0", "/v1", "/v0")
HOP_HEADERS = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade",
}
LOG = logging.getLogger("router")
CLIENT_AUTH = contextvars.ContextVar("client_authorization", default=None)
SERVICE_NAME = "lemonade-router.service"
SERVICE_UNIT_DIR = Path("/etc/systemd/system")
# A systemd service must initially execute a system-labelled file. The actual
# uv installation may remain in the user's home directory; this root-owned
# copy is refreshed by --ensure-service and then runs uv's home-local cache.
SERVICE_UV_PATH = Path("/usr/local/bin/lemonade-router-uv")
SERVICE_MARKER = "# Managed by lemonade_router.py --ensure-service"
SERVICE_ENV_KEYS = ("LEMONADE_API_KEY", "LEMONADE_ROUTER_API_KEY", "LEMONADE_ADMIN_API_KEY", "GITHUB_TOKEN")


class RouterError(Exception):
    def __init__(self, status: int, message: str):
        self.status, self.message = status, message
        super().__init__(message)


def api_path(path: str) -> str | None:
    for prefix in PREFIXES:
        if path.startswith(prefix + "/"):
            return path[len(prefix):].rstrip("/") or "/"
    return None


def clean_headers(headers, *, body_changed=False, websocket=False):
    excluded = HOP_HEADERS | {
        item.strip().lower() for item in headers.get("Connection", "").split(",")
    }
    if body_changed:
        excluded |= {"content-length", "content-encoding", "etag", "content-md5"}
    if websocket:
        excluded |= {k.lower() for k in headers if k.lower().startswith("sec-websocket-")}
    return CIMultiDict((k, v) for k, v in headers.items() if k.lower() not in excluded)


def http_origin(value: str) -> URL:
    parsed = URL(value)
    if (parsed.scheme != "http" or not parsed.host or parsed.user is not None
            or parsed.path not in ("", "/") or parsed.query_string or parsed.fragment):
        raise ValueError(f"Expected an HTTP origin without credentials/path: {value!r}")
    return parsed.with_path("")


def client_authorization(request):
    authorization = request.headers.get("Authorization")
    if request.headers.get("Upgrade", "").lower() == "websocket":
        if request.query.get("api_key"):
            authorization = "Bearer " + request.query["api_key"]
        for protocol in request.headers.get("Sec-WebSocket-Protocol", "").split(","):
            if protocol.strip().startswith("bearer."):
                authorization = "Bearer " + protocol.strip()[7:]
    return authorization


def expand_command(command, **values):
    result = []
    for arg in command:
        for key, value in values.items():
            arg = arg.replace("{" + key + "}", str(value))
        result.append(os.path.expanduser(os.path.expandvars(arg)))
    return result


async def finish_on_cancel(coro):
    """Do not release the GPU lock halfway through process/control mutations."""
    task = asyncio.create_task(coro)
    try:
        return await asyncio.shield(task)
    except asyncio.CancelledError:
        # Cleanup must finish before a queued request may start another backend.
        while not task.done():
            try:
                await asyncio.shield(task)
            except asyncio.CancelledError:
                pass
            except Exception:
                break
        if not task.cancelled():
            with contextlib.suppress(Exception):
                task.result()
        raise


@dataclass
class Launcher:
    """The foreground server OR its supervising wrapper; PID is the group ID."""

    model: str
    process: asyncio.subprocess.Process
    log_path: Path


def group_alive(pgid: int) -> bool:
    """Ignore zombies when checking a Linux launcher's whole process group."""
    proc = Path("/proc")
    if proc.is_dir():
        for entry in proc.iterdir():
            if not entry.name.isdigit():
                continue
            try:
                fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
                if int(fields[2]) == pgid and fields[0] != "Z":
                    return True
            except (OSError, ValueError, IndexError):
                continue
        return False
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False


class Router:
    def __init__(self, config):
        self.cfg = config
        self.lemonade = http_origin(config["lemonade_url"])
        self.models = {k: v for k, v in config["models"].items() if v.get("enabled", True)}
        self.directory = Path(config["state_dir"]).expanduser()
        self.gpu = asyncio.Lock()
        self.launchers: dict[str, Launcher] = {}
        self.last_work = time.monotonic()
        self.active_model: str | None = None
        self.active_requests = 0
        self.maintenance = False
        self.fault: str | None = None  # failed service restart: don't launch over an unknown state
        self.session: aiohttp.ClientSession | None = None
        self.lock_file = None
        self.updater: Updater | None = None
        self.validate()

    def validate(self):
        if os.name != "posix":
            raise ValueError("This router requires POSIX process groups and flock (Fedora/Linux).")
        if not 1 <= self.cfg["port"] <= 65535:
            raise ValueError("Invalid router port")
        if self.lemonade.port == self.cfg["port"]:
            raise ValueError("Lemonade and the router must use different ports")
        if self.cfg["lemonade_api_prefix"] not in PREFIXES:
            raise ValueError("lemonade_api_prefix must be /api/v1, /v1, /api/v0 or /v0")
        ports = {self.lemonade.port, self.cfg["port"]}
        for name, model in self.models.items():
            if not name or not isinstance(name, str):
                raise ValueError("Model IDs must be nonempty strings")
            port = model["port"]
            if not isinstance(port, int) or not 1 <= port <= 65535 or port in ports:
                raise ValueError(f"Duplicate or invalid port for {name!r}: {port}")
            ports.add(port)
            if model.get("host", "127.0.0.1") not in {"127.0.0.1", "localhost", "::1"}:
                raise ValueError(f"Custom launcher {name}: use a loopback host")
            self.model_origin(name)
            cmd = model.get("command")
            if not isinstance(cmd, list) or not cmd or not all(isinstance(a, str) for a in cmd):
                raise ValueError(f"Custom launcher {name}: command must be a nonempty argv list")
            for key in ("api_prefix", "health_path"):
                path = model.get(key, "/v1" if key == "api_prefix" else "/health")
                if not path.startswith("/") or path.startswith("//") or "?" in path or "#" in path:
                    raise ValueError(f"Invalid {key} for {name}")
        updates = self.cfg["updates"]
        for name in ("rpm_policy", "backend_policy"):
            if updates[name] not in {"off", "notify", "auto_when_idle"}:
                raise ValueError(f"Invalid {name}")
        if updates["interval_days"] <= 0 or updates["poll_seconds"] <= 0:
            raise ValueError("Update intervals must be positive")
        if (updates["rpm_policy"] != "off"
                and self.lemonade.host not in {"127.0.0.1", "localhost", "::1"}):
            raise ValueError("RPM maintenance must target a local Lemonade service; use rpm_policy='off' for remote")

    def model_origin(self, model):
        spec = self.models[model]
        return URL.build(scheme="http", host=spec.get("host", "127.0.0.1"), port=spec["port"])

    def model_info(self, model):
        return {
            "object": "model", "created": 0, "owned_by": "custom-router",
            "recipe": "llamacpp", "labels": ["chat"],
            **self.models[model].get("metadata", {}),
            "id": model, "downloaded": True, "router_managed": True,
        }

    def control_url(self, path):
        return str(self.lemonade) + self.cfg["lemonade_api_prefix"] + path

    def control_headers(self):
        key = self.cfg.get("lemonade_api_key")
        authorization = f"Bearer {key}" if key else CLIENT_AUTH.get()
        return {"Authorization": authorization} if authorization else {}

    async def start(self, app):
        self.directory.mkdir(parents=True, exist_ok=True)
        self.lock_file = (self.directory / "router.lock").open("a")
        try:
            fcntl.flock(self.lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            self.lock_file.close()
            raise RuntimeError(f"Another router is using {self.directory}") from None
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=None, sock_connect=self.cfg["connect_timeout"],
                                          sock_read=self.cfg["read_timeout"]),
            connector=aiohttp.TCPConnector(limit=100), auto_decompress=False,
            skip_auto_headers={"Accept-Encoding"}, trust_env=False,
        )
        self.updater = Updater(self)
        self.updater.start()
        LOG.info("Lemonade upstream: %s; enabled custom models: %s", self.lemonade, ", ".join(self.models) or "none")
        LOG.info("Update offers/status: http://<this-host>:%s/_router", self.cfg["port"])

    async def stop(self, app):
        if self.updater:
            await self.updater.close()
        # web.run_app has drained/cancelled requests before this cleanup hook.
        async with self.gpu:
            await finish_on_cancel(self.stop_custom())
        if self.session:
            await self.session.close()
        if self.lock_file:
            self.lock_file.close()

    async def control(self, path, *, method="GET", payload=None, timeout=20):
        assert self.session
        async with self.session.request(
            method, self.control_url(path), json=payload,
            headers={**self.control_headers(), "Accept-Encoding": "identity"},
            timeout=aiohttp.ClientTimeout(total=timeout), allow_redirects=False,
        ) as response:
            if response.status == 404:
                raise RouterError(404, f"Lemonade does not expose {path}")
            if response.status >= 300:
                text = (await response.text())[:1000]
                raise RouterError(502, f"Lemonade {path}: HTTP {response.status}: {text}")
            try:
                return await response.json(content_type=None)
            except (ValueError, UnicodeError):
                raise RouterError(502, f"Lemonade {path} returned invalid JSON") from None

    async def optional_control(self, path):
        try:
            return await self.control(path)
        except RouterError as error:
            if error.status == 404:
                return None
            raise

    @staticmethod
    def rows(data, *keys):
        if data is None:  # endpoint absent on an older Lemonade
            return []
        if isinstance(data, list):
            rows = data
        elif isinstance(data, dict):
            rows = next((data[key] for key in keys if isinstance(data.get(key), list)), None)
        else:
            rows = None
        if rows is None or not all(isinstance(row, dict) for row in rows):
            raise RouterError(503, "Unrecognized Lemonade job/download state; refusing to assume it is idle")
        return rows

    async def lemonade_idle(self, *, maintenance=False):
        health = await self.control("/health")
        if not isinstance(health, dict) or not isinstance(health.get("all_models_loaded"), list):
            raise RouterError(503, "Cannot establish Lemonade's loaded/busy state from /health")
        for model in health["all_models_loaded"]:
            if not isinstance(model, dict):
                return False
            if (model.get("is_busy") or model.get("is_streaming")
                    or model.get("backend_health") == "busy"
                    or model.get("status") in {"loading", "in_use", "evicting", "downsizing"}):
                return False
            if maintenance and "is_busy" not in model:
                # Old servers with no busy indicator are unsafe to restart automatically.
                return False
        jobs = await self.optional_control("/jobs")
        if any(row.get("status") in {"queued", "running", "in_progress"}
               for row in self.rows(jobs, "jobs", "data") if isinstance(row, dict)):
            return False
        if maintenance:
            downloads = await self.optional_control("/downloads")
            if any(row.get("running") or row.get("status") in {"downloading", "running", "queued"}
                   for row in self.rows(downloads, "downloads", "data") if isinstance(row, dict)):
                return False
        return True

    async def unload_lemonade(self):
        if not await self.lemonade_idle():
            raise RouterError(409, "Lemonade has active/background work; try again after it finishes")
        await self.control("/unload", method="POST", payload={}, timeout=self.cfg["unload_timeout"])
        health = await self.control("/health")
        if not isinstance(health, dict) or health.get("all_models_loaded") != []:
            raise RouterError(503, "Lemonade did not confirm that all models were unloaded; refusing custom startup")

    async def port_open(self, model):
        spec = self.models[model]
        try:
            _, writer = await asyncio.wait_for(
                asyncio.open_connection(spec.get("host", "127.0.0.1"), spec["port"]), timeout=1)
        except (OSError, asyncio.TimeoutError):
            return False
        writer.close()
        await writer.wait_closed()
        return True

    async def stop_custom(self):
        """Stop each launcher and its entire group, including wrapper children."""
        for name, launcher in list(self.launchers.items()):
            LOG.info("Stopping custom model %s (process group %s)", name, launcher.process.pid)
            pgid = launcher.process.pid
            with contextlib.suppress(ProcessLookupError):
                os.killpg(pgid, signal.SIGTERM)
            deadline = time.monotonic() + self.cfg["stop_timeout"]
            while group_alive(pgid) and time.monotonic() < deadline:
                await asyncio.sleep(0.1)
            if group_alive(pgid):
                LOG.warning("Force-killing launcher group %s", pgid)
                with contextlib.suppress(ProcessLookupError):
                    os.killpg(pgid, signal.SIGKILL)
            try:
                await asyncio.wait_for(launcher.process.wait(), timeout=5)
            except asyncio.TimeoutError:
                raise RouterError(503, f"Cannot stop {name}; refusing to load another model") from None
            deadline = time.monotonic() + 5
            while group_alive(pgid) and time.monotonic() < deadline:
                await asyncio.sleep(0.1)
            if group_alive(pgid) or await self.port_open(name):
                raise RouterError(503, f"{name} still has live processes/an open port; refusing to load another model")
            del self.launchers[name]

    async def custom_ready(self, model):
        assert self.session
        spec = self.models[model]
        url = str(self.model_origin(model)) + spec.get("health_path", "/health")
        key = spec.get("api_key")
        try:
            async with self.session.get(url, headers={"Authorization": f"Bearer {key}"} if key else {},
                                        timeout=aiohttp.ClientTimeout(total=2), allow_redirects=False) as response:
                return response.status == 200
        except (aiohttp.ClientError, asyncio.TimeoutError):
            return False

    async def assert_custom_ports_free(self):
        for name, spec in self.models.items():
            if await self.port_open(name):
                raise RouterError(503, f"Custom port {spec['port']} ({name}) is occupied by an unowned server; "
                                       "stop it manually before loading another model")

    async def ensure_backend(self, model: str | None):
        if self.fault:
            raise RouterError(503, self.fault + "; check /_router and restore Lemonade, then retry maintenance")
        if model not in self.models:
            await self.stop_custom()
            await self.assert_custom_ports_free()
            return  # Lemonade will load its own model on demand.
        launcher = self.launchers.get(model)
        if launcher and launcher.process.returncode is None and await self.custom_ready(model):
            return
        await self.stop_custom()
        await self.assert_custom_ports_free()
        await self.unload_lemonade()  # Fail CLOSED; never ignore an unload/auth/network failure.
        spec = self.models[model]
        name_hash = hashlib.sha256(model.encode()).hexdigest()[:12]
        log_path = self.directory / f"launcher-{name_hash}.log"
        command = expand_command(spec["command"], model=model,
                                 host=spec.get("host", "127.0.0.1"), port=spec["port"])
        LOG.info("Starting custom model %s; log: %s", model, log_path)
        # The launcher leads a new process group. Ordinary child processes inherit
        # it, so a wrapper need not exec the server for shutdown to reach it.
        with log_path.open("ab", buffering=0) as output:
            process = await asyncio.create_subprocess_exec(
                *command, cwd=os.path.expanduser(spec["cwd"]) if spec.get("cwd") else None,
                env={**os.environ, **{k: os.path.expandvars(str(v)) for k, v in spec.get("env", {}).items()}},
                stdin=asyncio.subprocess.DEVNULL, stdout=output, stderr=asyncio.subprocess.STDOUT,
                start_new_session=True,
            )
        self.launchers[model] = Launcher(model, process, log_path)
        try:
            deadline = time.monotonic() + spec.get("startup_timeout", 300)
            while time.monotonic() < deadline:
                if process.returncode is not None:
                    raise RouterError(502, f"Launcher {model} exited ({process.returncode}); see {log_path}")
                if await self.custom_ready(model):
                    LOG.info("Custom model %s is ready", model)
                    return
                await asyncio.sleep(0.25)
            raise RouterError(504, f"Launcher {model} startup timed out; see {log_path}")
        except BaseException:
            await self.stop_custom()
            raise

    @contextlib.asynccontextmanager
    async def work(self, model=None):
        if self.maintenance:
            raise RouterError(503, "Lemonade maintenance in progress; retry shortly")
        acquired = False
        try:
            try:
                async with asyncio.timeout(self.cfg["queue_timeout"]):
                    await self.gpu.acquire()
                    acquired = True
            except TimeoutError:
                raise RouterError(503, "Timed out waiting for the active model/stream/session") from None
            if self.maintenance:
                raise RouterError(503, "Lemonade maintenance in progress; retry shortly")
            self.active_requests += 1
            self.active_model = model
            await finish_on_cancel(self.ensure_backend(model))
            yield
        finally:
            if acquired:
                self.active_requests = 0
                self.active_model = None
                self.last_work = time.monotonic()
                self.gpu.release()

    async def payload(self, request):
        if request.headers.get("Content-Encoding", "identity").lower() != "identity":
            raise RouterError(415, "Compressed request bodies are not supported on model-routed endpoints")
        body = await request.read()
        content_type = request.content_type
        if body and content_type != "application/json" and not content_type.endswith("+json"):
            raise RouterError(415, "Model-routed requests need application/json")
        try:
            data = json.loads(body) if body else {}
        except (ValueError, UnicodeError):
            raise RouterError(400, "Invalid JSON request body") from None
        if data is None:
            data = {}  # older Lemonade CLIs send null to /unload
        if not isinstance(data, dict):
            raise RouterError(400, "Expected a JSON object")
        return body, data, data.get("model") or data.get("model_name")

    def upstream_headers(self, request, *, model=None, changed=False, websocket=False):
        headers = clean_headers(request.headers, body_changed=changed, websocket=websocket)
        # Preserve Host: the browser UI uses its public origin; Lemonade's origin
        # checks must see that same host rather than a private upstream host.
        key = self.models[model].get("api_key") if model in self.models else self.cfg.get("lemonade_api_key")
        if key:
            headers["Authorization"] = f"Bearer {key}"
        return headers

    def target(self, request, *, model=None, path=None):
        if model in self.models:
            base = self.model_origin(model)
            route = self.models[model].get("api_prefix", "/v1").rstrip("/") + (path or "")
            raw = quote(route, safe="/:%@!$&'()*+,;=-._~")
        else:
            base = self.lemonade
            # Preserve raw path escapes/query; don't resolve // paths as new hosts.
            raw = request.raw_path.split("?", 1)[0]
        query = request.rel_url.raw_query_string
        return URL(str(base) + raw + ("?" + query if query else ""), encoded=True)

    async def proxy_http(self, request, *, model=None, path=None, body=None, changed=False):
        assert self.session
        url = self.target(request, model=model, path=path)
        headers = self.upstream_headers(request, model=model, changed=changed)
        if body is None:
            body = request.content.iter_chunked(64 * 1024) if request.can_read_body else None
        try:
            async with self.session.request(request.method, url, headers=headers, data=body,
                                            allow_redirects=False) as upstream:
                out_headers = clean_headers(upstream.headers)
                # Keep absolute redirects inside the router, not on the private port.
                location = out_headers.get("Location")
                if location and location.startswith(str(self.lemonade) + "/"):
                    out_headers["Location"] = location[len(str(self.lemonade)):]
                response = web.StreamResponse(status=upstream.status, headers=out_headers)
                await response.prepare(request)
                try:
                    async for chunk in upstream.content.iter_any():
                        await response.write(chunk)
                    await response.write_eof()
                except (aiohttp.ClientError, asyncio.TimeoutError, ConnectionError):
                    # Cannot replace an already committed SSE/binary response with JSON.
                    # Abort, don't turn a truncated generation into successful EOF.
                    if request.transport:
                        request.transport.abort()
                    raise
                return response
        except (aiohttp.ClientError, asyncio.TimeoutError) as error:
            raise RouterError(502, f"Upstream HTTP request failed: {error}") from error

    async def models_response(self, request):
        assert self.session
        url = self.target(request)
        headers = self.upstream_headers(request)
        headers["Accept-Encoding"] = "identity"
        async with self.session.get(url, headers=headers, allow_redirects=False) as upstream:
            data = await upstream.read()
            if upstream.status != 200:
                return web.Response(status=upstream.status, body=data, headers=clean_headers(upstream.headers))
            try:
                result = json.loads(data)
                rows = result["data"]
                if not isinstance(rows, list):
                    raise ValueError()
            except (ValueError, KeyError, TypeError):
                raise RouterError(502, "Lemonade /models returned an unexpected shape") from None
        merged = {item["id"]: item for item in rows if isinstance(item, dict) and "id" in item}
        merged.update({name: self.model_info(name) for name in self.models})
        return web.json_response({**result, "data": list(merged.values())})

    async def health_response(self, request):
        health = await self.control("/health")
        health["websocket_port"] = self.cfg["port"]
        loaded = list(health.get("all_models_loaded", []))
        for name, launcher in self.launchers.items():
            if launcher.process.returncode is not None:
                continue
            info = self.model_info(name)
            loaded.append({
                "model_name": name, "checkpoint": info.get("checkpoint", ""),
                "type": "llm", "device": "gpu", "recipe": info.get("recipe", "llamacpp"),
                "recipe_options": self.models[name].get("load_options", {}),
                "labels": info.get("labels", []), "pinned": False,
                "pid": launcher.process.pid, "backend_url": str(self.model_origin(name)),
                "last_use": int(self.last_work * 1000), "router_managed": True,
                "is_busy": self.active_model == name, "is_streaming": self.active_model == name,
                "status": "in_use" if self.active_model == name else "ready",
            })
            health["model_loaded"] = name
        health["all_models_loaded"] = loaded
        health["router"] = {"maintenance": self.maintenance, "active_requests": self.active_requests,
                            "fault": self.fault, "status_url": "/_router"}
        return web.json_response(health)

    async def handle(self, request):
        path = api_path(request.path)
        method = request.method
        needs_auth = (path is not None or request.path.startswith("/_router/")
                      or method not in {"GET", "HEAD", "OPTIONS"}
                      or request.headers.get("Upgrade", "").lower() == "websocket")
        if self.cfg.get("api_key") and method != "OPTIONS" and needs_auth:
            provided = (client_authorization(request) or "").removeprefix("Bearer ")
            if not hmac.compare_digest(provided.encode(), self.cfg["api_key"].encode()):
                return web.json_response({"error": {"message": "Invalid or missing router API key"}}, status=401)
        if request.path.rstrip("/") == "/_router" or request.path.startswith("/_router/"):
            assert self.updater
            return await self.updater.handle(request)
        if request.headers.get("Upgrade", "").lower() == "websocket":
            realtime = path == "/realtime" or request.path.rstrip("/") == "/realtime"
            logs = path == "/logs/stream" or request.path.rstrip("/") == "/logs/stream"
            if logs:
                return await self.proxy_ws(request, logs=True)
            # All WebSockets belong to Lemonade; never launch a custom model
            # based on their query parameters or message contents.
            async with self.work(None):
                return await self.proxy_ws(request, realtime=realtime)
        if method in {"GET", "HEAD"}:
            if path == "/models":
                return await self.models_response(request)
            if path == "/health":
                return await self.health_response(request)
            if path and path.startswith("/models/"):
                name = path[len("/models/"):]
                if name in self.models:
                    return web.json_response(self.model_info(name))
                for suffix in ("/options", "/files"):
                    name = path[len("/models/"):].removesuffix(suffix)
                    if path.endswith(suffix) and name in self.models:
                        if suffix == "/files":
                            return web.json_response({"model_id": name, "files": []})
                        spec = self.models[name]
                        options = spec.get("load_options", {})
                        return web.json_response({"model_name": name, "recipe": "llamacpp", "saved": options,
                                                  "effective": options, "defaults": options,
                                                  "resolved_ctx_size": options.get("ctx_size", 0),
                                                  "load_command": "Configured in lemonade_router.py (read-only)"})
            return await self.proxy_http(request)
        if method == "OPTIONS":
            return await self.proxy_http(request)  # preserve Lemonade's origin/CORS policy
        if method == "POST" and path in INFERENCE_PATHS | {"/load", "/unload", "/delete", "/pull"}:
            body, data, model = await self.payload(request)
            if model is not None and (not isinstance(model, str) or not model):
                raise RouterError(400, "model must be a nonempty string")
            if path in INFERENCE_PATHS and not model:
                raise RouterError(400, "An explicit model is required for inference routing")
            if model in self.models and path in {"/delete", "/pull"}:
                raise RouterError(409, "Custom models are managed in CONFIG, not by Lemonade pull/delete")
            if model in self.models and path == "/load" and data and data.get("save_options"):
                raise RouterError(409, "Custom launch options are fixed in CONFIG; cannot save UI options")
            if path == "/unload":
                # Do not start a custom model just to unload it.
                async with self.work(None):
                    if model in self.models:
                        return web.json_response({"status": "success", "message": "Custom launcher stopped", "model_name": model})
                    return await self.proxy_http(request, body=body)
            async with self.work(model):
                if model in self.models:
                    if path == "/load":
                        return web.json_response({"status": "success", "message": "Custom launcher ready; using CONFIG arguments", "model_name": model})
                    upstream_model = self.models[model].get("upstream_model", model)
                    changed = False
                    if upstream_model != model:
                        data["model"] = upstream_model
                        body = json.dumps(data).encode()
                        changed = True
                    return await self.proxy_http(request, model=model, path=path, body=body, changed=changed)
                return await self.proxy_http(request, body=body)
        if path and path.startswith("/models/") and any(
                path[len("/models/"):] == name or path[len("/models/"):].startswith(name + "/")
                for name in self.models):
            raise RouterError(409, "Custom model metadata/options are read-only; edit CONFIG")
        # Catch-all, including future Lemonade APIs. Mutations may load/use GPUs.
        async with self.work(None):
            return await self.proxy_http(request)

    async def proxy_ws(self, request, *, realtime=False, logs=False):
        assert self.session
        url = self.target(request)
        key = self.cfg.get("lemonade_api_key")
        if key:
            url = url.update_query(api_key=key)
        protocols = [p.strip() for p in request.headers.get("Sec-WebSocket-Protocol", "").split(",") if p.strip()]
        headers = self.upstream_headers(request, websocket=True)
        upstream = None
        try:
            upstream = await asyncio.wait_for(
                self.session.ws_connect(url.with_scheme("ws"), headers=headers, protocols=protocols,
                                        heartbeat=30, max_msg_size=64 * 1024 * 1024),
                timeout=self.cfg["connect_timeout"],
            )
        except aiohttp.WSServerHandshakeError:
            if not (logs or realtime):
                raise
            # Older Lemonade versions serve WebSockets ONLY on the health port.
            health = await self.control("/health")
            port = health.get("websocket_port")
            if not isinstance(port, int) or not 1 <= port <= 65535:
                raise RouterError(502, "Lemonade WebSocket upgrade failed and no legacy port was advertised") from None
            legacy_path = "/logs/stream" if logs else "/realtime"
            url = self.lemonade.with_scheme("ws").with_port(port).with_path(legacy_path).with_query(url.query)
            upstream = await asyncio.wait_for(
                self.session.ws_connect(url, headers=headers, protocols=protocols,
                                        heartbeat=30, max_msg_size=64 * 1024 * 1024),
                timeout=self.cfg["connect_timeout"],
            )
        try:
            downstream = web.WebSocketResponse(protocols=[upstream.protocol] if upstream.protocol else (),
                                                heartbeat=30, max_msg_size=64 * 1024 * 1024)
            await downstream.prepare(request)

            async def pump(source, destination):
                async for message in source:
                    if message.type == aiohttp.WSMsgType.TEXT:
                        await destination.send_str(message.data)
                    elif message.type == aiohttp.WSMsgType.BINARY:
                        await destination.send_bytes(message.data)
                    elif message.type == aiohttp.WSMsgType.ERROR:
                        break

            tasks = [asyncio.create_task(pump(downstream, upstream)),
                     asyncio.create_task(pump(upstream, downstream))]
            try:
                done, _pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
                for task in done:
                    task.result()
            finally:
                for task in tasks:
                    task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)
                code = upstream.close_code or 1000
                await downstream.close(code=code if code not in {1005, 1006, 1015} else 1001)
            return downstream
        finally:
            await upstream.close()


class Updater:
    def __init__(self, router):
        self.router = router
        self.cfg = router.cfg["updates"]
        self.file = router.directory / "updates.json"
        try:
            self.state = json.loads(self.file.read_text())
            if not isinstance(self.state, dict):
                raise ValueError()
        except (OSError, ValueError):
            self.state = {}
        self.checking = False
        self.task = None
        self.actions: set[asyncio.Task] = set()

    def save(self):
        self.router.directory.mkdir(parents=True, exist_ok=True)
        fd, path = tempfile.mkstemp(prefix="updates-", dir=self.router.directory)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(self.state, stream, indent=2)
            os.replace(path, self.file)
        finally:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(path)

    def start(self):
        self.task = asyncio.create_task(self.loop(), name="weekly-update-checks")

    async def close(self):
        if self.task:
            self.task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.task
        # Do not leave dnf/systemctl running while shutdown proceeds. An already
        # started transaction/restart is shielded and must finish before exit.
        if self.actions:
            await asyncio.gather(*self.actions, return_exceptions=True)

    async def command(self, argv, *, timeout=None, env=None):
        argv = expand_command(argv)
        process = await asyncio.create_subprocess_exec(
            *argv, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
            stdin=asyncio.subprocess.DEVNULL, start_new_session=True, env=env,
        )
        try:
            output, _ = await asyncio.wait_for(process.communicate(), timeout=timeout or self.cfg["command_timeout"])
        except BaseException:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGKILL)
            await process.wait()
            raise
        text = output.decode("utf-8", "replace").strip()
        if process.returncode:
            raise RuntimeError(f"{Path(argv[0]).name} exited {process.returncode}: {text[-3000:]}")
        return text

    async def rpm_newer(self, installed, candidate):
        # rpm.vercmp handles RPM's ~ / ^ / release ordering; no shell or Lua input
        # is accepted outside this strict version alphabet.
        if not all(re.fullmatch(r"[A-Za-z0-9._+~^:-]+", value) for value in (installed, candidate)):
            raise ValueError("Unexpected RPM version syntax")
        result = await self.command(["rpm", "--eval", '%{lua:print(rpm.vercmp("' + installed + '","' + candidate + '"))}'], timeout=10)
        return int(result) < 0

    async def check_rpm(self):
        if self.cfg["rpm_policy"] == "off":
            return None
        release = platform.freedesktop_os_release()
        if release.get("ID") != "fedora" or not release.get("VERSION_ID", "").isdigit():
            raise RuntimeError("RPM update checking requires Fedora (or set rpm_policy='off')")
        package = self.cfg["package"]
        installed = await self.command(["rpm", "-q", "--qf", "%{VERSION}", package], timeout=10)
        assert self.router.session
        headers = {"Accept": "application/vnd.github+json", "User-Agent": "lemonade-router"}
        token = os.environ.get("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
        async with self.router.session.get(self.cfg["release_api"], headers=headers,
                                          timeout=aiohttp.ClientTimeout(total=30)) as response:
            response.raise_for_status()
            latest = await response.json()
        if latest.get("draft") or latest.get("prerelease"):
            return None
        version = latest["tag_name"].removeprefix("v")
        if not await self.rpm_newer(installed, version):
            return None
        expected = f"{package}-{version}-fc{release['VERSION_ID']}.{platform.machine()}.rpm"
        asset = next((a for a in latest["assets"] if a["name"] == expected), None)
        if not asset:
            raise RuntimeError(f"Release {version} has no asset {expected}")
        digest = asset.get("digest", "")
        if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
            raise RuntimeError("Release RPM has no SHA256 digest; refusing automatic installation")
        url = asset["browser_download_url"]
        if not url.startswith("https://github.com/lemonade-sdk/lemonade/releases/download/"):
            raise RuntimeError("Unexpected RPM download origin")
        return {"installed": installed, "version": version, "name": expected,
                "url": url, "digest": digest, "arch": platform.machine()}

    async def check_backends(self):
        if self.cfg["backend_policy"] == "off":
            return []
        data = await self.router.control("/system-info", timeout=60)
        recipes = data.get("recipes") if isinstance(data, dict) else None
        if not isinstance(recipes, dict):
            raise RuntimeError("This Lemonade version has no recognizable /system-info recipes")
        updates = []
        for recipe, info in recipes.items():
            for backend, entry in info.get("backends", {}).items():
                spec = f"{recipe}:{backend}"
                allowlist = self.cfg["backend_allowlist"]
                if allowlist is not None and spec not in allowlist:
                    continue
                if entry.get("state") in {"update_available", "update_required"}:
                    if not re.fullmatch(r"[A-Za-z0-9_-]+:[A-Za-z0-9_-]+", spec) or backend == "system":
                        continue
                    updates.append({"spec": spec, "state": entry["state"], "version": entry.get("version")})
        return updates

    async def check(self):
        if self.checking or self.router.maintenance:
            raise RouterError(409, "An update check/maintenance operation is already in progress")
        self.checking = True
        try:
            errors = []
            for key, operation in (("rpm", self.check_rpm), ("backends", self.check_backends)):
                try:
                    result = await operation()
                    self.state[key] = result
                except Exception as error:
                    errors.append(f"{key}: {error}")
                    # Don't automatically execute stale offers after a failed check.
                    self.state.pop(key, None)
            self.state.update(last_check=time.time(), errors=errors, auto_attempted=False)
            self.save()
            if self.state.get("rpm") or self.state.get("backends"):
                LOG.warning("Update offer: RPM=%s, backends=%s; see /_router", self.state.get("rpm"), self.state.get("backends"))
            for error in errors:
                LOG.warning("Update check: %s", error)
        finally:
            self.checking = False

    async def download_rpm(self, offer):
        assert self.router.session
        cache = self.router.directory / "downloads"
        cache.mkdir(exist_ok=True)
        destination = cache / offer["name"]
        if destination.name != offer["name"] or not destination.name.endswith(".rpm"):
            raise RuntimeError("Unsafe RPM asset filename")
        fd, temporary = tempfile.mkstemp(prefix="rpm-", dir=cache)
        try:
            digest = hashlib.sha256()
            async with self.router.session.get(offer["url"], timeout=aiohttp.ClientTimeout(total=1800)) as response:
                response.raise_for_status()
                with os.fdopen(fd, "wb") as stream:
                    fd = -1
                    async for chunk in response.content.iter_chunked(1024 * 1024):
                        digest.update(chunk)
                        stream.write(chunk)
            if "sha256:" + digest.hexdigest() != offer["digest"].lower():
                raise RuntimeError("Downloaded RPM SHA256 does not match GitHub's asset digest")
            os.replace(temporary, destination)
            metadata = (await self.command(["rpm", "-qp", "--qf", "%{NAME}\n%{VERSION}\n%{ARCH}", str(destination)], timeout=20)).splitlines()
            if metadata != [self.cfg["package"], offer["version"], offer["arch"]]:
                raise RuntimeError("Downloaded RPM package/version/architecture mismatch")
            return destination
        finally:
            if fd != -1:
                os.close(fd)
            with contextlib.suppress(FileNotFoundError):
                os.unlink(temporary)

    async def wait_ready(self):
        deadline = time.monotonic() + self.cfg["restart_timeout"]
        while time.monotonic() < deadline:
            try:
                health = await self.router.control("/health", timeout=3)
                if health.get("status") == "ok":
                    return
            except (RouterError, aiohttp.ClientError, asyncio.TimeoutError):
                pass
            await asyncio.sleep(1)
        raise RuntimeError("Lemonade did not become healthy after restart")

    async def install_rpm(self, destination):
        # Even a failed stop or dnf must be followed by a start attempt.
        try:
            LOG.warning("Stopping lemond and installing %s", destination.name)
            await self.command(self.cfg["stop_command"], timeout=120)
            output = await self.command(expand_command(self.cfg["install_command"], rpm=destination))
            LOG.info("RPM installation: %s", output[-3000:])
        finally:
            start_error = None
            try:
                await self.command(self.cfg["start_command"], timeout=120)
            except Exception as error:
                # A permission-denied stop/start may leave the original service
                # healthy. Don't permanently block inference solely on CLI failure.
                start_error = error
            try:
                await self.wait_ready()
                self.router.fault = None
            except Exception as error:
                self.router.fault = f"Lemonade restart failed: {error}"
                raise
            if start_error:
                raise start_error

    async def install_backends(self, offers):
        url = self.router.lemonade
        command = self.cfg["lemonade_command"] + ["--host", url.host, "--port", str(url.port)]
        # Explicit target avoids UDP discovery accidentally finding the router.
        env = os.environ.copy()
        key = self.router.cfg.get("lemonade_api_key")
        if key:
            env["LEMONADE_API_KEY"] = key
        for offer in offers:
            LOG.warning("Updating Lemonade backend %s", offer["spec"])
            output = await self.command(command + ["backends", "install", offer["spec"]], env=env)
            LOG.info("Backend installer: %s", output[-3000:])

    async def apply(self, *, automatic=False):
        router = self.router
        if self.checking or router.maintenance or router.gpu.locked():
            raise RouterError(409, "Router is busy; update deferred")
        if time.monotonic() - router.last_work < self.cfg["idle_seconds"]:
            raise RouterError(409, f"Wait for {self.cfg['idle_seconds']} seconds without GPU work before updating")
        if self.state.get("auto_attempted") and automatic:
            return
        rpm = self.state.get("rpm") if self.cfg["rpm_policy"] != "off" else None
        backends = self.state.get("backends", []) if self.cfg["backend_policy"] != "off" else []
        if automatic:
            if self.cfg["rpm_policy"] != "auto_when_idle":
                rpm = None
            if self.cfg["backend_policy"] != "auto_when_idle":
                backends = []
        if not rpm and not backends:
            return
        # Set the admission flag BEFORE awaiting: no new GPU work can sneak in.
        router.maintenance = True
        try:
            async with router.gpu:
                if not await router.lemonade_idle(maintenance=True):
                    raise RouterError(409, "Lemonade has active jobs/models/downloads; update deferred")
                self.state.update(auto_attempted=True, maintenance_error=None, maintenance_started=time.time())
                self.save()
                await finish_on_cancel(self.transaction(rpm, backends))
        finally:
            router.maintenance = False

    async def transaction(self, rpm, backends):
        try:
            # Re-fetch offers and verify before stopping anything. Downloading an
            # RPM is safe while other clients only read metadata/UI through us.
            destination = None
            if rpm:
                fresh = await self.check_rpm()
                if fresh:
                    destination = await self.download_rpm(fresh)
            # The RPM download can take minutes. Recheck immediately before any
            # interruption, including downloads that started since the first check.
            if not await self.router.lemonade_idle(maintenance=True):
                raise RouterError(409, "Lemonade became busy during update preparation; nothing was stopped")
            await self.router.stop_custom()
            await self.router.assert_custom_ports_free()
            await self.router.unload_lemonade()
            if destination:
                await self.install_rpm(destination)
                self.state["rpm"] = None
            # A new RPM may change the supported/pinned backend versions. Recheck.
            if backends or destination and self.cfg["backend_policy"] == "auto_when_idle":
                offers = await self.check_backends()
                await self.install_backends(offers)
                self.state["backends"] = await self.check_backends()
            self.state["maintenance_finished"] = time.time()
            self.router.fault = None
            LOG.info("Maintenance completed")
        except Exception as error:
            self.state["maintenance_error"] = str(error)
            LOG.exception("Maintenance failed (no automatic retry until next weekly check)")
        finally:
            self.save()

    async def loop(self):
        while True:
            try:
                enabled = any(self.cfg[key] != "off" for key in ("rpm_policy", "backend_policy"))
                due = time.time() - self.state.get("last_check", 0) >= self.cfg["interval_days"] * 86400
                if enabled and due:
                    await self.check()
                if enabled:
                    await self.apply(automatic=True)
            except RouterError as error:
                if error.status != 409:
                    LOG.warning("Weekly maintenance: %s", error)
            except Exception:
                LOG.exception("Weekly update worker failed")
            await asyncio.sleep(self.cfg["poll_seconds"])

    def background(self, coro):
        async def run():
            try:
                await coro
            except Exception as error:
                LOG.warning("Update action: %s", error)
                self.state["action_error"] = str(error)
                self.save()
        task = asyncio.create_task(run())
        self.actions.add(task)
        task.add_done_callback(self.actions.discard)

    async def handle(self, request):
        path = request.path.rstrip("/")
        if path == "/_router/status" and request.method in {"GET", "HEAD"}:
            return web.json_response({
                "custom_models": list(self.router.models), "active_model": self.router.active_model,
                "launchers": {name: {"pid": item.process.pid, "exit_code": item.process.returncode,
                                      "log": str(item.log_path)} for name, item in self.router.launchers.items()},
                "maintenance": self.router.maintenance, "fault": self.router.fault,
                "checking": self.checking, "updates": self.state,
                "policies": {k: self.cfg[k] for k in ("rpm_policy", "backend_policy", "idle_seconds")},
            })
        if path == "/_router/updates/check" and request.method == "POST":
            if self.checking or self.router.maintenance:
                raise RouterError(409, "An update operation is already in progress")
            self.background(self.check())
            return web.json_response({"status": "scheduled"}, status=202)
        if path == "/_router/updates/apply" and request.method == "POST":
            # Preflight produces a useful response instead of silently queuing a
            # privileged operation behind a generation. apply() checks again.
            if self.checking or self.router.maintenance or self.router.gpu.locked():
                raise RouterError(409, "Router is busy; try again when idle")
            if time.monotonic() - self.router.last_work < self.cfg["idle_seconds"]:
                raise RouterError(409, "Router has not reached the configured idle period")
            self.background(self.apply())
            return web.json_response({"status": "scheduled; progress in /_router/status"}, status=202)
        if path == "/_router" and request.method in {"GET", "HEAD"}:
            return web.Response(text=DASHBOARD, content_type="text/html")
        raise RouterError(404, "Unknown router endpoint")


DASHBOARD = """<!doctype html><meta charset="utf-8"><title>Lemonade router</title>
<style>body{font:16px system-ui;max-width:1000px;margin:2em auto;padding:1em}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#eee;padding:1em}
button{margin:1em .5em 0 0;padding:.5em}</style>
<h1>Lemonade router</h1><p><a href="/">Lemonade UI</a> · Custom launchers are configured in the Python script.</p>
<p>Updates apply only when idle. RPM installation requires configured noninteractive privileges.</p>
<label>Router API key (if configured): <input id="key" type="password" autocomplete="off"></label><br>
<button onclick="load()">Refresh</button><button onclick="action('check')">Check updates</button>
<button onclick="if(confirm('Apply offered updates? This may restart Lemonade.'))action('apply')">Apply offered updates</button>
<p id="message"></p><pre id="status">Loading…</pre><script>
const headers=()=>key.value?{'Authorization':'Bearer '+key.value}:{};
async function load(){try{const r=await fetch('/_router/status',{headers:headers()});
statusBox.textContent=JSON.stringify(await r.json(),null,2)}catch(e){message.textContent=e}}
const statusBox=document.getElementById('status');
async function action(op){const r=await fetch('/_router/updates/'+op,{method:'POST',headers:headers()});
message.textContent=await r.text();await load()}
load();setInterval(load,10000);
</script>"""


@web.middleware
async def errors(request, handler):
    token = CLIENT_AUTH.set(client_authorization(request))
    try:
        return await handler(request)
    except RouterError as error:
        headers = {"Retry-After": "30"} if error.status == 503 else {}
        return web.json_response({"error": {"message": error.message, "type": "router_error"}},
                                 status=error.status, headers=headers)
    except web.HTTPException:
        raise
    except (aiohttp.ClientError, asyncio.TimeoutError, OSError) as error:
        LOG.warning("Request %s %s failed: %s", request.method, request.path, error)
        return web.json_response({"error": {"message": str(error), "type": "upstream_error"}}, status=502)
    except Exception:
        LOG.exception("Unhandled request failure: %s %s", request.method, request.path)
        return web.json_response({"error": {"message": "Internal router error; see router log"}}, status=500)
    finally:
        CLIENT_AUTH.reset(token)


def create_app(config=None):
    config = config or CONFIG
    router = Router(config)
    app = web.Application(client_max_size=config["max_body_mib"] * 1024 * 1024,
                          middlewares=[errors], handler_args={"auto_decompress": False})
    app.router.add_route("*", "/{path:.*}", router.handle)
    app.on_startup.append(router.start)
    app.on_cleanup.append(router.stop)
    return app


def systemd_quote(value, *, specifiers=True):
    """Quote a unit token, or an EnvironmentFile value (no specifier expansion)."""
    value = str(value)
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError("Systemd paths/environment values must not contain control characters")
    value = value.replace("\\", "\\\\").replace('"', '\\"')
    if specifiers:
        value = value.replace("%", "%%")
    return '"' + value + '"'


def systemd_path(value):
    # WorkingDirectory/EnvironmentFile take a single literal path, NOT a quoted
    # argv token. Quotes there would become part of the filename in systemd.
    value = str(value)
    if not value.startswith("/") or any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError("Systemd paths must be absolute and contain no control characters")
    return value.replace("%", "%%")


def service_unit(user, uv, script, environment_file, *, log_level="INFO", local_lemonade=True,
                gpu_groups=(), selinux_context=None):
    home = Path(user.pw_dir)
    selinux_line = f"SELinuxContext={selinux_context}\n" if selinux_context else ""
    path = ":".join(str(p) for p in (
        uv.parent, home / ".local/bin", home / "bin", Path("/usr/local/sbin"),
        Path("/usr/local/bin"), Path("/usr/sbin"), Path("/usr/bin"), Path("/sbin"), Path("/bin"),
    ))
    dependencies = "network-online.target" + (" lemond.service" if local_lemonade else "")
    command = " ".join(systemd_quote(arg) for arg in (
        uv, "run", "--no-project", "--script", script, "--log-level", log_level,
    ))
    groups = "SupplementaryGroups=" + " ".join(gpu_groups) + "\n" if gpu_groups else ""
    # Only Wants/After, never PartOf/BindsTo: the updater must be able to stop
    # lemond without systemd also stopping this router (or its update transaction).
    return f"""{SERVICE_MARKER}
# Router service owner UID: {user.pw_uid}
[Unit]
Description=Lemonade and custom llama.cpp router
Wants={dependencies}
After={dependencies}
RequiresMountsFor={systemd_quote(script.parent)}
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User={user.pw_uid}
Group={user.pw_gid}
{groups}WorkingDirectory={systemd_path(script.parent)}
Environment={systemd_quote('HOME=' + str(home))} "PYTHONUNBUFFERED=1" "UV_NO_PROGRESS=1" {systemd_quote('PATH=' + path)}
EnvironmentFile=-{systemd_path(environment_file)}
{selinux_line}# ':' disables $ expansion in ExecStart; '%' is escaped separately above.
ExecStart=:{command}
Restart=on-failure
RestartSec=5
KillMode=mixed
TimeoutStopSec=2h
UMask=0077
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lemonade-router

[Install]
WantedBy=multi-user.target
"""


def private_file(path, data, *, replace=True):
    """Atomic, user-owned installation; leave an existing environment file alone."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise RuntimeError(f"Refusing to overwrite a symlink: {path}")
    if path.exists() and (not replace or path.read_bytes() == data):
        path.chmod(0o600)
        return False
    fd, temporary = tempfile.mkstemp(prefix=".install-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.replace(temporary, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temporary)
    return True


def ensure_service(config, *, log_level="INFO"):
    """Install a boot-enabled system unit that runs as the invoking normal user."""
    if platform.system() != "Linux" or not Path("/run/systemd/system").is_dir():
        raise RuntimeError("--ensure-service requires a Linux host running systemd")
    if os.getuid() == 0 or os.geteuid() == 0:
        raise RuntimeError("Run --ensure-service as your normal user, without sudo; it invokes sudo only for systemd installation")
    user = pwd.getpwuid(os.getuid())
    home = Path(user.pw_dir)
    if not home.is_absolute():
        raise RuntimeError("The invoking account must have an absolute home directory")
    router = Router(config)  # validate without opening ports, checking updates, or launching models
    uv_path = os.environ.get("UV") or shutil.which("uv")
    if not uv_path:
        raise RuntimeError("uv was not found; run this command with uv run")
    uv = Path(uv_path).resolve(strict=True)
    if not os.access(uv, os.X_OK):
        raise RuntimeError(f"uv is not executable: {uv}")
    tools = {name: shutil.which(name) for name in ("sudo", "systemctl", "install")}
    if not all(tools.values()):
        raise RuntimeError("--ensure-service requires sudo, systemctl, and install on PATH")
    unit_path = SERVICE_UNIT_DIR / SERVICE_NAME
    if unit_path.is_symlink():
        raise RuntimeError(f"Refusing to replace a symlink/masked service: {unit_path}")
    previous = unit_path.read_text() if unit_path.exists() else None
    if previous is not None and (
        SERVICE_MARKER not in previous.splitlines()
        or f"# Router service owner UID: {user.pw_uid}" not in previous.splitlines()
    ):
        raise RuntimeError(f"Refusing to overwrite an unrelated/another user's unit: {unit_path}")
    script = home / ".local/share/lemonade-router/lemonade_router.py"
    environment_file = home / ".config/lemonade-router/service.env"
    gpu_groups = []
    for name in ("render", "video"):
        try:
            grp.getgrnam(name)
        except KeyError:
            continue
        gpu_groups.append(name)
    # A system service starts in SELinux's init_t domain. Fedora does not
    # permit that domain to execute a binary labelled data_home_t, which is the
    # label normally assigned to uv installations under /home. Use Fedora's
    # unconfined_service_t domain for the service while retaining its explicit
    # Unix UID/GID. This is only needed when SELinux is enforcing.
    selinux_context = None
    if shutil.which("getenforce") and subprocess.run(
        ["getenforce"], capture_output=True, text=True, check=False
    ).stdout.strip() == "Enforcing":
        selinux_context = "system_u:system_r:unconfined_service_t:s0"
    service_uv = SERVICE_UV_PATH
    unit = service_unit(user, service_uv, script, environment_file, log_level=log_level,
                        local_lemonade=router.lemonade.host in {"127.0.0.1", "localhost", "::1"},
                        gpu_groups=gpu_groups, selinux_context=selinux_context)
    # Validate quoting/environment BEFORE doing any writes or requesting sudo.
    environment = "# Optional environment for lemonade-router.service (not a shell script).\n"
    for key in SERVICE_ENV_KEYS:
        if key in os.environ:
            environment += key + "=" + systemd_quote(os.environ[key], specifiers=False) + "\n"
    environment += "# Add other variables here, e.g. PATH=/home/YOU/bin:/usr/local/bin:/usr/bin:/bin\n"
    private_file(script, Path(__file__).resolve().read_bytes())
    env_created = private_file(environment_file, environment.encode(), replace=False)
    if unit != previous or not service_uv.is_file() or service_uv.read_bytes() != uv.read_bytes():
        subprocess.run([tools["sudo"], tools["install"], "-o", "root", "-g", "root", "-m", "0755",
                        str(uv), str(service_uv)], check=True)
        subprocess.run([tools["sudo"], "restorecon", "-v", str(service_uv)], check=True)
    if unit != previous:
        fd, temporary = tempfile.mkstemp(prefix="lemonade-router-", suffix=".service")
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(unit)
            subprocess.run([tools["sudo"], tools["install"], "-o", "root", "-g", "root", "-m", "0644",
                            temporary, str(unit_path)], check=True)
        finally:
            with contextlib.suppress(FileNotFoundError):
                os.unlink(temporary)
    subprocess.run([tools["sudo"], tools["systemctl"], "daemon-reload"], check=True)
    subprocess.run([tools["sudo"], tools["systemctl"], "enable", SERVICE_NAME], check=True)
    print(f"Installed/enabled {SERVICE_NAME} for boot, running as {user.pw_name} (UID {user.pw_uid}).")
    print(f"Installed script/CONFIG: {script}")
    print(f"Environment: {environment_file} ({'created with current API keys/token, if set' if env_created else 'preserved'}, mode 0600)")
    print("No running service was started or restarted. Stop a manual router first, then:")
    print(f"  sudo systemctl start {SERVICE_NAME}    # or restart, when idle, to apply changes")
    print(f"  journalctl -u {SERVICE_NAME} -f")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--check-config", action="store_true", help="validate CONFIG without connecting or launching anything")
    actions.add_argument("--ensure-service", action="store_true", help="install/update and enable a boot-time systemd service as your normal user (uses sudo; does not start/restart)")
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="INFO")
    args = parser.parse_args()
    logging.basicConfig(level=args.log_level, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    if args.ensure_service:
        try:
            ensure_service(CONFIG, log_level=args.log_level)
        except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
            parser.exit(1, f"Service installation failed: {error}\n")
        return
    if args.check_config:
        router = Router(CONFIG)
        print(f"CONFIG valid: HTTP {CONFIG['host']}:{CONFIG['port']}, Lemonade {router.lemonade}, {len(router.models)} custom model(s)")
        return
    web.run_app(create_app(), host=CONFIG["host"], port=CONFIG["port"],
                handler_cancellation=True, shutdown_timeout=30, access_log=None)


if __name__ == "__main__":
    main()
