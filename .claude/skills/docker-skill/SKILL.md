---
name: docker-skill
description: >
  Creates, validates, and improves Dockerfiles following modern best practices — lean base images,
  security hardening, and maintainability. Use this skill whenever the user mentions Docker, Dockerfile,
  container image, "criar imagem", "criar Dockerfile", "validar Dockerfile", "build docker", "imagem docker",
  "container", "docker build", "docker run", "otimizar imagem", or anything related to packaging an
  application into a container. Trigger even if the user just says "como faço pra dockerizar isso?" or
  "quero colocar em container". Prioritize this skill for any Docker-related task — creation, review,
  optimization, or troubleshooting.
---

# Docker Skill

You are helping the user work with Docker — creating, validating, or improving Dockerfiles and container images.

Your north star is: **lean, secure, and maintainable images**. Every decision should serve at least one of these goals.

## Understanding the request

Before writing anything, figure out:
- **What runtime** is the app? (Node.js, Python, Java, Go, Rust, etc.)
- **What stage** of development? (dev, staging, production) — this affects caching strategy, debug tools, and image size
- **Any constraints?** (specific OS requirements, compliance needs, existing base image mandates)

If the user didn't specify, make a reasonable assumption, state it clearly, and explain your choice.

## Base image selection

Prefer lean images in this order:
1. **`<runtime>:<version>-alpine`** — best for most cases (musl libc, small attack surface)
2. **`gcr.io/distroless/...`** — ideal for compiled languages (Go, Rust, Java) going to production
3. **`<runtime>:<version>-slim`** — when Alpine causes musl/glibc compatibility issues
4. **`ubuntu:<lts>`** — only when absolutely necessary (e.g., complex system dependencies)

Always pin to a specific version (e.g., `node:20-alpine3.19`, not `node:alpine`). This prevents surprise breakage when a new minor comes out and keeps builds reproducible.

## Security principles

These aren't bureaucratic rules — they exist because Docker containers run with more privilege than people expect, and each of these closes a real attack vector:

**Run as non-root.** The default Docker user is root inside the container, which maps directly to root on the host if containment fails. Create a dedicated user:
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

**Minimize the attack surface.** Don't install tools you don't need at runtime (curl, wget, bash, git). If you need them to build, use multi-stage builds so they don't end up in the final image.

**Never embed secrets.** ARGs and ENVs with sensitive values end up in image history. Use Docker secrets (BuildKit) or pass secrets at runtime via environment variables, never at build time. Never commit `.env` files or any file containing passwords, tokens, or keys to git — once in history they are permanently exposed.

**Use .dockerignore.** Always suggest creating `.dockerignore` to prevent accidentally copying `.git`, `node_modules`, `.env`, credentials, or large test fixtures into the image.

**Scan for vulnerabilities.** After building, remind the user they can run `docker scout cves <image>` or `trivy image <image>` to check for known CVEs.

## Multi-stage builds

Use multi-stage builds whenever the build toolchain is heavier than the runtime (which is almost always). The pattern:

```dockerfile
# Stage 1: build
FROM node:20-alpine3.19 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: runtime (only what's needed to run)
FROM node:20-alpine3.19
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
```

The final image only contains what the second stage has — the build tools, source maps, test files, and dev dependencies stay behind.

## Layer caching

Order matters for build speed. Docker caches each layer; a change invalidates that layer and everything after it. Put things that change rarely at the top, things that change often at the bottom:

```dockerfile
# Good: package files change rarely, source code changes often
COPY package*.json ./
RUN npm ci
COPY . .  # source code last
```

## Healthchecks

For services that run long-lived, add a HEALTHCHECK. This lets orchestrators (Kubernetes, ECS, Swarm) know if the container is actually ready:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

## Output format

When creating a Dockerfile, always produce:

1. **The Dockerfile** — no comments, no LABEL instructions. Keep it clean and minimal.
2. **A `.dockerignore`** — tailored to the project type
3. **Build & run commands** — the exact `docker build` and `docker run` commands to get started
4. **Brief rationale** — 3-5 bullet points explaining the key choices (base image, stages, user, etc.) in the chat, not inside the file

When validating an existing Dockerfile, produce:

1. **Issues found** — grouped by severity (critical, warning, suggestion)
2. **Improved Dockerfile** — with fixes applied and brief inline comments explaining changes
3. **What changed and why** — so the user learns, not just gets a fixed file

## Language-specific references

For deep-dives into specific runtimes, see:
- `references/node.md` — Node.js specifics (npm ci vs install, node_modules caching, .npmrc)
- `references/python.md` — Python specifics (pip, poetry, uv, virtual envs, __pycache__)
- `references/java.md` — Java/JVM specifics (Maven/Gradle layers, distroless JRE, memory flags)
- `references/go.md` — Go specifics (static binaries, scratch/distroless, CGO)

Read the relevant reference file if the user's language is covered there.
