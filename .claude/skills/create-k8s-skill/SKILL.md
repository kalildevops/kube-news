---
name: create-k8s-skill
description: >
  Guides the full containerization and Kubernetes deployment workflow for an application —
  from Dockerfile to docker-compose to Kustomize overlays to Helm charts to live cluster deploy.
  Use this skill whenever the user mentions: Kubernetes, K8s, Helm, Kustomize, kubectl, deploy,
  "criar chart", "criar manifests", "subir no cluster", "fazer deploy", "overlay", "values.yaml",
  "namespace", HPA, LoadBalancer, "cluster DigitalOcean", "cluster EKS", "cluster GKE",
  "estrutura Helm", "estrutura k8s", ou qualquer combinação de container + cloud/orquestrador.
  Trigger even if the user only says "quero colocar isso no Kubernetes" or "como faço deploy disso".
  Prioritize this skill over ad-hoc kubectl/helm answers — it brings a structured, battle-tested workflow.
---

# K8s Deploy Skill

You are guiding the user through the full path from application code to a running Kubernetes deployment. The goal is always a production-ready structure that is maintainable, secure, and works across environments.

## Step 1: Understand the project

Before writing any file, answer these questions by reading the codebase:

- **Runtime and entrypoint**: What language/framework? What command starts the app?
- **Port**: What port does the app listen on?
- **External dependencies**: Database? Cache? Message broker? External APIs?
- **Environment variables**: How does the app get config? (env vars, config files, secrets)
- **Health endpoints**: Does the app expose `/health` and/or `/ready`? (check the source)
- **Target cluster**: Which cloud provider / local? This affects LoadBalancer type, storage, and secrets strategy.

State your assumptions clearly before proceeding.

## Step 2: Decide the output scope

Ask or infer what the user needs. Common combinations:

| User need | What to produce |
|---|---|
| Local dev only | `docker-compose.yml` |
| K8s but simple | Kustomize base + one overlay |
| Multi-environment | Kustomize base + overlays (dev/qa/prod + cloud) |
| Team / reusable | Helm chart |
| Full workflow | Dockerfile + docker-compose + Kustomize + Helm |

When in doubt, produce the Kustomize structure and offer Helm as a follow-up.

## Step 3: Dockerfile

Follow the `docker-skill` principles (if available). Key rules:
- Alpine or slim base, pinned version (`node:22-alpine3.21`, not `node:alpine`)
- Non-root user
- Layer cache: copy dependency manifests → install → copy source
- HEALTHCHECK using the app's health endpoint
- No comments, no LABEL instructions in the file

For Apple Silicon users deploying to Linux clusters, always use multi-platform build:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <image>:<tag> --push .
```
A single-arch image built on arm64 will fail with `no match for platform` on amd64 nodes.

## Step 4: docker-compose

For local development. Always includes:
- The app service with all env vars wired
- Any dependency services (postgres, redis, etc.)
- `depends_on` with `condition: service_healthy` so the app doesn't start before the DB is ready
- A named volume for DB persistence

## Step 5: Kustomize structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   └── networkpolicy.yaml
└── overlays/
    ├── dev/
    ├── qa/
    ├── prod/
    └── <cloud>/          ← per cloud provider or environment
```

**Base principles:**
- `Service` type `LoadBalancer` in base — overlays adjust annotations per cloud
- Secrets come from `ExternalSecret` in AWS-based clusters; use plain `Secret` for others
- `automountServiceAccountToken: false` and `runAsNonRoot: true` in every Deployment
- `NetworkPolicy` restricts egress to DNS + specific backends only

**Overlay responsibilities:**
- Image tag (set by CI: `kustomize edit set image`)
- Replica count and resource sizing
- Secret source (ExternalSecret params, or plain Secret for non-AWS)
- Service annotations per cloud (AWS NLB vs DO LB vs GKE)

**Removing AWS-specific resources for non-AWS overlays:**
Use `$patch: delete` in the kustomization patches to remove `ExternalSecret` and `ClusterSecretStore`:
```yaml
patches:
  - target:
      group: external-secrets.io
      version: v1beta1
      kind: ExternalSecret
      name: <name>
    patch: |
      $patch: delete
      apiVersion: external-secrets.io/v1beta1
      kind: ExternalSecret
      metadata:
        name: <name>
```

## Step 6: Helm chart

```
helm/<app-name>/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl       ← name, fullname, namespace, labels, selectorLabels
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── secret.yaml
    ├── hpa.yaml
    ├── networkpolicy.yaml
    └── <dependency>.yaml  ← e.g. postgres.yaml if in-cluster DB
```

**Namespace**: never use `default`. Define a dedicated namespace and set it in every resource via `{{ include "<app>.namespace" . }}`. The namespace name typically matches `{{ .Chart.Name }}`.

**helpers.tpl pattern:**
```
{{- define "<app>.namespace" -}}{{ .Chart.Name }}{{- end }}
{{- define "<app>.labels" -}}
app.kubernetes.io/name: {{ include "<app>.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
...
{{- end }}
```

**values.yaml**: expose image, replicaCount, service type/port, resources, hpa thresholds, and any dependency config (DB image, storage size). Never put credentials in `values.yaml` — use a gitignored `values-secrets.yaml` passed at install time with `-f values-secrets.yaml` or `--set`.

## Step 7: In-cluster databases (for non-managed-DB setups)

When deploying PostgreSQL inside the cluster (dev/POC):

- Use `Deployment` with `replicas: 1` (not StatefulSet for simplicity)
- Set `PGDATA` to a **subdirectory** of the mount path:
  ```yaml
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata
  ```
  Cloud block storage volumes (DigitalOcean, GKE, EKS) are formatted with `lost+found` at the root. PostgreSQL refuses to initialize in a non-empty directory — `PGDATA` pointing to a subdirectory is the fix.
- PVC with `ReadWriteOnce`, sized for the expected data volume

## Step 8: Deploy and verify

```bash
# Kustomize
kubectl apply -k k8s/overlays/<env>/

# Helm
helm install <release> ./helm/<chart>/
helm upgrade <release> ./helm/<chart>/

# Verify
kubectl get pods -n <namespace>
kubectl get svc -n <namespace>
kubectl logs -n <namespace> -l app=<name> --tail=30
```

**Common failure patterns and fixes:**

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff: no match for platform` | Image built for wrong arch (arm64 on amd64 cluster) | Rebuild with `--platform linux/amd64,linux/arm64` |
| `initdb: directory not empty` (postgres) | Cloud volume has `lost+found` at root | Add `PGDATA` env var pointing to subdirectory |
| `ExternalSecretOperatorNotFound` | ESO not installed on cluster | Replace `ExternalSecret` with plain `Secret` |
| `<pending>` on LoadBalancer | Cloud LB annotations wrong or missing CCM | Check cloud-specific annotations in `references/cloud-providers.md` |
| `CrashLoopBackOff` on app after DB fix | App started before DB was ready | App will self-recover once DB is healthy; check `depends_on` in compose |

## Cloud-specific notes

See `references/cloud-providers.md` for LoadBalancer annotations and storage class names per provider.

## Secrets — never commit credentials

Passwords, tokens, and keys must never appear in files that are committed to git. Once in the history, they are compromised permanently even if later removed.

**Kustomize**: never create `secret.yaml` with real values. Use one of:
- `kubectl create secret generic <name> --from-literal=password=xxx -n <ns>` (imperative, no file)
- `secret.yaml.example` with placeholders committed; real `secret.yaml` in `.gitignore`
- ExternalSecret + secrets manager (AWS Secrets Manager, Vault, etc.)
- Sealed Secrets (`kubeseal`) — encrypts the secret; the sealed file is safe to commit

**Helm**: never put credentials in `values.yaml`. Use:
- `helm install <release> ./chart/ --set postgres.credentials.password=xxx`
- A gitignored `values-secrets.yaml`: `helm install <release> ./chart/ -f values-secrets.yaml`
- External secrets injected at runtime via the cluster's secret manager integration

Always add sensitive files to `.gitignore` before creating them:
```
# .gitignore
**/secret.yaml
values-secrets.yaml
*.env
```

## Output conventions

- No inline comments in YAML files unless a non-obvious workaround is present
- No `LABEL` instructions in Dockerfiles
- Explanations go in the conversation, not in the files
- Always validate Helm charts with `helm lint` and `helm template` before deploying
- Always run `kubectl get pods` and `kubectl logs` after deploy to confirm health
