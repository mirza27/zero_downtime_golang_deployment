# Zero-Downtime Hotfix Deployment for Go in Containers

[![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go)](https://golang.org)
[![Docker](https://img.shields.io/badge/Docker-Multi--stage-2496ED?style=flat&logo=docker)](https://www.docker.com)
[![Alpine](https://img.shields.io/badge/Runtime-Alpine_3.22-0D597F?style=flat&logo=alpinelinux)](https://alpinelinux.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An in-place binary swap pattern for Go services running in Docker. Achieves zero-downtime hotfixes without container restarts, port rebinding, or dropped requests.

---

## Overview

- **Application Name**: `technical-test-simple-server`
- **Docker Hub Repository**: [mirzarama27/technical-test-simple-server](https://hub.docker.com/r/mirzarama27/technical-test-simple-server)
- **Port Exposed**: `8080` (HTTP)

### Code Structure

Starter code refactored into dedicated packages under `internal/`:
- `internal/config/config.go`: handles port config and environment variable loading (`PORT`, default `8080`).
- `internal/server/server.go`: encapsulates routing and HTTP server lifecycle.
- `cmd/app/main.go`: minimal entrypoint initializing config and running the server.
- `cmd/manager/main.go`: lightweight supervisor running as PID 1 to manage the server process and handle reload signals.

### Versioning Workflow

Version managed centrally via `Makefile`:
- `VERSION`: base semantic version (e.g. `2.1.2`).
- `COMMIT_HASH`: short git hash via `git rev-parse --short HEAD`.
- `IMAGE_TAG`: composite `$(VERSION)-$(COMMIT_HASH)` (e.g. `2.1.2-2a491c7`) injected during build.

> **Note**: Unit tests validate response strings (`internal/server/server_test.go`). Bumping `VERSION` in `Makefile` must match `server_test.go`, otherwise `make test` halts the pipeline before build.

---

## Architecture & Container Build

### Architecture Overview

```
Host Filesystem                                Container Filesystem
+-------------------------------+              +-------------------------------------+
| ./releases/                   |              | /releases/ (Bind Mount)             |
|   ├── 1.0.1/server            |              |   ├── 1.0.1/server                  |
|   └── 1.0.2/server (New Patch)|              |   └── 1.0.2/server                  |
+---------------+---------------+              +------------------+------------------+
                |                                                 |
                | (docker volume bind)                            | (Atomic Symlink)
                +------------------------------------------------>|
                                                                  v
                                                       /app/server (Symlink)
                                                                  ^
                                                                  |
                                              SIGUSR1             | Spawns / Manages
+------------------------------------+   ----------------> +------+------+
| CI / CD Pipeline                   |                     |  /tool/     | (PID 1)
| (Jenkins / GitHub Actions / Local) |                     |  manager    |
+------------------------------------+                     +------+------+
                                                                  |
                                                                  | Child Process
                                                                  v
                                                           /app/server [Active]
                                                           (Port 8080 Listener)
```

### Multi-Stage Dockerfile

Two-stage build keeps runtime image minimal:
- **Stage 1 (Builder - `golang:1.26-alpine`)**:
  - Compiles static Go binary (`CGO_ENABLED=0 GOOS=linux GOARCH=amd64`).
  - Injects version via `-ldflags="-X main.version=${APP_VERSION}"`.
  - Compiles both `/app/server` (`./cmd/app`) and supervisor `/tool/manager` (`./cmd/manager`).
- **Stage 2 (Runtime - `alpine:3.22`)**:
  - Copies compiled binaries `/app/server` and `/tool/manager`.
  - Sets `/tool/manager` as container `ENTRYPOINT`.
  - Final image size: **~19.6 MB**.

`alpine:3.22` chosen over `scratch` because the hotfix swap mechanism requires standard Linux shell utilities (`ln`, `mv`, `sh`) inside the running container.

---

## How the Binary Swap Works

Instead of recreating the container, the deploy process uses a supervisor pattern with atomic symlink swaps:

1. **Supervisor Pattern**:
   Container runs `/tool/manager` (`cmd/manager/main.go`) as PID 1. It spawns `/app/server` as a child process and handles incoming OS signals.
2. **Generating the Patch Binary**:
   Running `make release` starts a temporary container from the newly built image, copies out the patched `/app/server` binary into host `./releases/${VERSION}/server`, and destroys the temporary container:
   ```bash
   make release
   ```
3. **Atomic Symlink Swap (`ETXTBSY` Avoidance)**:
   On Linux systems, attempting to overwrite an actively executing binary via standard write operations (`cp` or direct stream write) triggers the kernel error:
   ```text
   cp: cannot create regular file '/app/server': Text file busy (ETXTBSY)
   ```
   To eliminate this constraint, the deployment engine uses POSIX atomic filesystem operations:
   ```bash
   ln -s "/releases/${NEW_VERSION}/server" /app/server.next
   mv -Tf /app/server.next /app/server
   ```
   Because `rename(2)` (`mv -Tf`) is atomic at the VFS layer, open file descriptors held by the running process remain valid while the filesystem namespace immediately points to the newly patched binary.

   Running `make update` triggers `scripts/update.sh`:
   - Links the new binary atomically via the steps above.
   - Sends `SIGUSR1` to container:
     ```bash
     docker kill --signal=USR1 technical-test-simple-server
     ```
   - Supervisor receives `SIGUSR1`, sends `SIGTERM` to current child process, waits for exit, and immediately spawns new binary.
   - Saves previous version to `./state/previous.txt` and new version to `./state/current.txt`.

### Rollback Mechanism

If a deployed binary fails health checks, `make rollback` (`scripts/rollback.sh`) reverses the symlink swap using `./state/previous.txt` and signals supervisor to reload previous working binary.

---

## Project Structure

```text
.
├── cmd/
│   ├── app/                # Main application HTTP service entrypoint
│   │   └── main.go
│   └── manager/            # PID 1 supervisor managing signals & child lifecycle
│       └── main.go
├── internal/
│   ├── config/             # Environment & port configuration
│   │   └── config.go
│   └── server/             # HTTP routing & handlers with unit tests
│       ├── server.go
│       └── server_test.go
├── docs/                   # Benchmark logs and pipeline execution evidence
│   ├── test.log
│   ├── success-pipeline.png
│   ├── failed-pipeline.png
│   └── rollback-pipeline.png
├── scripts/                # Hotfix automation scripts
│   ├── health-check.sh     # Target endpoint verification
│   ├── rollback.sh         # Symlink reversal & reload trigger
│   ├── test.sh             # High-frequency HTTP polling benchmark
│   └── update.sh           # Atomic symlink swap & signal dispatcher
├── Dockerfile              # Multi-stage static build definition
├── Jenkinsfile             # Declarative CI/CD pipeline definition
└── Makefile                # Centralized release and lifecycle commands
```

---

## Verification & Benchmark

Traffic polled every 250ms during live swap via `scripts/test.sh`:

```text
========================================
[2026-10-18 21:13:14.261] Request: http://localhost:8080/
Hello, DevOps! version=1.0.1
HTTP Status: 200
Response Time: 0.000439s

========================================
[2026-10-18 21:13:14.517] Request: http://localhost:8080/
Hello, DevOps! version=1.0.2
HTTP Status: 200
Response Time: 0.000487s
========================================
```

- Version switch completed in **< 256ms**.
- 0 dropped packets / continuous HTTP 200 responses.

---

## Local Reproduction Quickstart

```bash
# 1. Run unit tests and start baseline container
make test
make build VERSION=1.0.1
make run

# 2. In another terminal: start traffic polling
make test-reload

# 3. Patch and deploy without stopping container
make build VERSION=1.0.2
make release VERSION=1.0.2
make update VERSION=1.0.2
make health

# 4. Rollback if needed
make rollback
```

---

## CI/CD Pipeline (Jenkins)

Pipeline stages defined in `Jenkinsfile`:
1. **Unit Test**: Runs `make test`. Halts pipeline on test failure.
2. **Checkout**: Checks out target branch.
3. **Check Version**: Extracts version string from `Makefile`.
4. **Build & Push**: Builds image and pushes to Docker Hub via credentials binding (`docker-hub-pat`).
5. **Deploy & Integration Test**:
   - Connects to target host via SSH (`deploy-ssh`).
   - Syncs repo on host.
   - Extracts patch binary (`make release`).
   - Swaps binary live (`make update`).
   - Runs `make health`.
   - **Automated Rollback**: Triggers `make rollback` on host if health check returns non-200.

---

## Pipeline Evidence & Logs

### 1. Successful Pipeline Run (All Stages Green)

Build completed with all stages passed, image pushed to Docker Hub, and live swap deployed.

![Successful Pipeline Run](docs/success-pipeline.png)

### 2. Failed Pipeline Run (Unit Test Failure)

Pipeline halts at **Unit Test** stage on test failure, preventing broken code from building or deploying.

![Failed Pipeline Run](docs/failed-pipeline.png)

### 3. Automated Rollback on Failed Health Check

When health check fails after `make update`, pipeline immediately invokes `scripts/rollback.sh` to restore prior binary.

![Rollback Pipeline Run](docs/rollback-pipeline.png)

---

## Tradeoffs & Limitations

> **Important Disclaimer**: This binary swap pattern is designed specifically for single-host standalone Docker environments where container restart overhead must be avoided for small logic patches.

It is **not** suitable for all production environments:
- **No Database Migrations**: Cannot handle schema alterations or state changes that break backward compatibility.
- **Not for Kubernetes**: In Kubernetes or clustered environments, native rolling updates, blue/green deployments, or canary rollouts with multiple replicas are preferred and handle traffic shifting cleanly at ingress/service level.
- **Compiled Binaries Only**: Relies on single static binary replacements; changes to OS libraries, dependencies, or container configuration still require standard container rebuilds.

---

## Makefile Shortcut Cheatsheet

| Command | Description |
|---|---|
| `make test` | Runs Go unit tests (`go test -v ./...`) |
| `make build` | Builds Docker image with injected version |
| `make push` | Pushes image to Docker Hub |
| `make run` | Starts container with volume mount (`./releases:/releases`) |
| `make release` | Extracts `/app/server` from image into `./releases/${VERSION}/server` |
| `make update` | Re-links binary inside running container and sends `SIGUSR1` reload signal |
| `make health` | Runs HTTP health check on target endpoint |
| `make rollback` | Restores previous binary version and sends `SIGUSR1` reload signal |
| `make test-reload` | Runs polling test script (`test.sh`) to observe zero-downtime swap |
| `make down` | Stops and removes container |
| `make logs` | Streams container logs |
