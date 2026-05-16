# Cloud Provider Reference

## DigitalOcean (DOKS)

**LoadBalancer Service annotations:**
```yaml
annotations:
  service.beta.kubernetes.io/do-loadbalancer-name: "<name>"
  service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
```

**Storage class**: `do-block-storage` (default quando nenhum storageClassName é especificado)

**Block storage caveat**: volumes vêm pré-formatados com `lost+found` na raiz — sempre definir `PGDATA` apontando para um subdiretório:
```yaml
- name: PGDATA
  value: /var/lib/postgresql/data/pgdata
```

**kubeconfig**: baixar no console da DO ou via `doctl kubernetes cluster kubeconfig save <cluster-id>`.

**Multi-platform build**: nodes DOKS rodam em `amd64`. Se desenvolvendo em Apple Silicon (arm64), sempre buildar com:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <image>:<tag> --push .
```

---

## AWS (EKS)

**LoadBalancer Service annotations (NLB):**
```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "external"
  service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
  service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
```

**Secrets**: usar `ExternalSecret` com `ClusterSecretStore` apontando para:
- Secrets Manager (prod/qa): `service: SecretsManager`
- Parameter Store (dev, tier gratuito): `service: ParameterStore`

**Storage class**: `gp2` (padrão) ou `gp3` (melhor performance e custo menor).

**Remoção de recursos AWS em overlays não-AWS**: usar `$patch: delete` no kustomization para remover `ExternalSecret` e `ClusterSecretStore` e substituir por `Secret` simples.

---

## GKE (Google Kubernetes Engine)

**LoadBalancer Service**: funciona sem anotações para LB externo.

**LB interno:**
```yaml
annotations:
  cloud.google.com/load-balancer-type: "Internal"
```

**Storage class**: `standard` (HDD) ou `premium-rwo` (SSD).

---

## Azure (AKS)

**LoadBalancer Service annotations:**
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-resource-group: "<rg>"
```

**Storage class**: `managed-premium` (SSD) ou `managed` (HDD).

---

## minikube (local)

**LoadBalancer**: fica em `<pending>` sem `minikube tunnel`. Alternativas:
- Rodar `minikube tunnel` em outro terminal (cria rota para o IP do LB)
- Mudar o Service para `NodePort` e usar `minikube service <name>`

**Storage**: usa provisioner `hostpath` — sem `lost+found`, não precisa do fix de `PGDATA`.

**Registry**: usar `eval $(minikube docker-env)` para buildar a imagem direto no daemon do minikube, sem precisar de push para registry externo.
```bash
eval $(minikube docker-env)
docker build -t <image>:<tag> .
# usar imagePullPolicy: Never no Deployment
```
