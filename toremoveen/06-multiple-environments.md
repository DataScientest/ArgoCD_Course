# Chapter 6 — Managing Multiple Environments

---

## The real-world MLOps platform

Let's talk about what a real ML platform looks like in production.

You have a fraud detection model. But you don't just have *one* deployment — you have a whole promotion pipeline:

```
dev  →  staging  →  production
```

- In **dev**, data scientists are constantly experimenting. Models are rebuilt several times a day. We want auto-sync, fast iteration, and we don't care about stability.
- In **staging**, we validate the model against a representative sample of production traffic. We run A/B tests and compare metrics to the current production model. We want control — manual sync before promoting.
- In **production**, real money is at stake. A degraded fraud model means missed fraud or false positives. We want human approval, rollback capability, and strict audit trails.

Each environment needs different configuration: different replica counts, different resource limits, different environment variables (staging database vs production database), different thresholds.

How do we manage all of this cleanly in Git without copy-pasting files everywhere?

---

## Approach 1: Folders per environment

The simplest approach. Your repo looks like this:

```
ml-platform/
├── fraud-detection/
│   ├── dev/
│   │   └── deployment.yaml     # 1 replica, 1Gi memory, dev DB
│   ├── staging/
│   │   └── deployment.yaml     # 2 replicas, 2Gi memory, staging DB
│   └── production/
│       └── deployment.yaml     # 5 replicas, 4Gi memory, prod DB
```

One ArgoCD Application per environment:

```bash
argocd app create fraud-detection-dev \
  --repo https://github.com/your-org/ml-platform \
  --path fraud-detection/dev \
  --dest-namespace fraud-detection-dev \
  --sync-policy automated

argocd app create fraud-detection-staging \
  --repo https://github.com/your-org/ml-platform \
  --path fraud-detection/staging \
  --dest-namespace fraud-detection-staging

argocd app create fraud-detection-production \
  --repo https://github.com/your-org/ml-platform \
  --path fraud-detection/production \
  --dest-namespace fraud-detection-production
```

Notice: dev has `--sync-policy automated`, staging and production do not — they require manual sync.

**Pros:** Simple. Easy to understand. Each environment is fully explicit.

**Cons:** A lot of YAML duplication. If you change the model's container port, you update three files. Easy to forget one.

---

## Approach 2: Kustomize — base + overlays (recommended for MLOps)

**Kustomize** is a Kubernetes-native tool that lets you define a base configuration once and apply environment-specific patches on top.

This is the right approach for MLOps platforms because:
- Your models share the same structure across environments
- Only a handful of values differ per environment (image tag, replicas, resources, env vars)
- You want one place to change the model's API port and have it apply everywhere

### Repository structure with Kustomize

```
ml-platform/
├── base/
│   ├── deployment.yaml       # shared config for all envs
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── production/
        └── kustomization.yaml
```

### The base deployment

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraud-detection-api
spec:
  replicas: 1                       # default — will be patched per env
  selector:
    matchLabels:
      app: fraud-detection
  template:
    spec:
      containers:
      - name: inference-server
        image: my-registry/fraud-model:latest   # will be patched by CI per env
        resources:
          requests:
            memory: "1Gi"           # default — patched per env
            cpu: "500m"
        env:
        - name: MODEL_THRESHOLD
          value: "0.5"              # default threshold — patched per env
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
```

```yaml
# base/kustomization.yaml
resources:
  - deployment.yaml
  - service.yaml
```

### The production overlay

```yaml
# overlays/production/kustomization.yaml
bases:
  - ../../base

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 5                    # 5 replicas in production
    target:
      kind: Deployment
      name: fraud-detection-api

  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "4Gi"               # more memory for production load
    target:
      kind: Deployment
      name: fraud-detection-api

images:
  - name: my-registry/fraud-model
    newTag: v3.2                   # CI updates this tag per environment
```

### The dev overlay

```yaml
# overlays/dev/kustomization.yaml
bases:
  - ../../base

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: fraud-detection-api

images:
  - name: my-registry/fraud-model
    newTag: v3.3-dev              # latest unstable build
```

ArgoCD detects Kustomize automatically. Just point each Application to the overlay folder:

```bash
argocd app create fraud-detection-production \
  --repo https://github.com/your-org/ml-platform \
  --path overlays/production \
  --dest-namespace fraud-detection-production
```

---

## The MLOps model promotion workflow

With this structure, promoting a model from staging to production becomes a simple Git operation:

```bash
# In your CI pipeline or manually:
# 1. Staging has been running v3.3 successfully for 24 hours
# 2. Metrics are good: fraud recall 94%, precision 88%
# 3. Promote to production:

# Update production overlay in Git
sed -i 's/newTag: v3.2/newTag: v3.3/' overlays/production/kustomization.yaml
git add overlays/production/kustomization.yaml
git commit -m "chore: promote fraud-model v3.3 to production"
git push

# ArgoCD detects the change and shows OutOfSync on fraud-detection-production
# A human reviews and clicks Sync — or your CI calls:
argocd app sync fraud-detection-production
```

This is fully auditable: every promotion is a commit with a timestamp, an author, and a diff.

---

## Never store secrets in Git

As MLOps engineers, we deal with sensitive values all the time: database credentials, API keys for feature stores, model registry tokens.

**Never put these in Git**, even in a private repo. Use:
- **Sealed Secrets** — encrypts secrets so they can be stored safely in Git
- **External Secrets Operator** — syncs secrets from AWS Secrets Manager, Vault, GCP Secret Manager, etc.
- **Kubernetes Secrets** managed outside Git and referenced by name in your deployments

---

## Common mistakes at this stage

- **Deploying multiple environments to the same namespace.** If dev and staging both deploy to `default`, they will overwrite each other. Always use dedicated namespaces.
- **Forgetting to update all overlays when changing a shared value.** With Kustomize, the base handles this — change once, applies everywhere. With folders, you must update all three manually.
- **Putting secrets in Git to "save time."** This is a serious security risk. The setup cost of proper secrets management is worth it.

---

## Summary

- Each environment gets its own ArgoCD Application pointing to a different path or overlay.
- The **folder approach** is simple but creates duplication.
- **Kustomize** lets you define config once and patch per environment — ideal for ML platforms with multiple models.
- Model promotion = updating a Git tag → ArgoCD detects the diff → sync → deployed.
- Never store secrets in Git.

---

## What's next

We know how to deploy and promote models across environments. In the next chapter, we will go deeper into deployment strategies — canary, blue/green — which are essential in MLOps for safely testing new model versions in production.
