# Chapter 5 — Sync Strategies and Application Health

---

## The problem with manual syncs

In the previous chapter, we triggered every sync manually. That's fine for learning, but it breaks the core promise of MLOps automation.

Think about this: your team retrains the fraud detection model every night. The CI pipeline runs, pushes a new Docker image, updates the tag in Git. Then... nothing. Because someone has to click "Sync" in the morning.

That's not a pipeline — that's a reminder. Let's fix it.

---

## Manual sync vs. automatic sync

ArgoCD gives you two modes:

### Manual sync
You control every deployment. ArgoCD detects drift and shows **OutOfSync**, but waits for a human to act.

**When to use it in MLOps:**
- Production model deployments where a human must approve before going live
- When you want to validate metrics on staging before pushing to prod
- During incidents — you want to freeze deployments while investigating

### Automatic sync
ArgoCD watches your Git repo and syncs automatically on every detected change.

**When to use it in MLOps:**
- Dev and staging environments — you want your team to see the latest model immediately
- Nightly retraining pipelines — new model trained, CI updates Git tag, ArgoCD deploys, no human needed
- Feature stores and data pipelines where freshness matters

---

## Enabling automatic sync

### Via CLI

```bash
argocd app set fraud-detection --sync-policy automated
```

ArgoCD will now poll your Git repo every 3 minutes by default. When it sees a new commit (e.g., an updated image tag), it syncs automatically.

### Via a manifest file (recommended)

Defining sync policy in YAML is better because it's stored in Git — the policy itself is versioned.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fraud-detection
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/ml-platform
    targetRevision: HEAD
    path: models/fraud-detection
  destination:
    server: https://kubernetes.default.svc
    namespace: fraud-detection-dev
  syncPolicy:
    automated:
      prune: true       # remove resources deleted from Git
      selfHeal: true    # revert manual cluster changes
    syncOptions:
      - CreateNamespace=true   # create the namespace if it doesn't exist
```

---

## Two critical options: `prune` and `selfHeal`

### `prune: true`

In MLOps, we often update our deployment configurations — removing old environment variables, dropping unused services. Without `prune`, deleted files in Git leave orphaned resources running in the cluster.

With `prune: true`, if you remove `configmap.yaml` from Git (because you moved config to a secrets manager), ArgoCD will also remove that ConfigMap from the cluster.

> Only enable `prune` when your Git repo is a complete and accurate picture of everything you want running. Never enable it on a half-migrated setup.

### `selfHeal: true`

Imagine a teammate manually patches the fraud detection deployment in the cluster — maybe they bump memory limits to debug an OOM issue. Without `selfHeal`, that manual change persists and your cluster silently diverges from Git.

With `selfHeal: true`, ArgoCD detects the drift and reverts the cluster back to the Git state within minutes.

> This is the strict GitOps guarantee: **no change reaches production unless it goes through Git.** This is exactly what audit teams and compliance frameworks love.

---

## Understanding health in an ML context

After syncing, ArgoCD evaluates **health**. For an ML inference service, health matters beyond just "is it running?"

| Status | What it means for our fraud detection service |
|---|---|
| `Healthy` | All inference pods are up, passing readiness probes, accepting requests |
| `Progressing` | New model image is being pulled, pods are restarting — this is normal during a model update |
| `Degraded` | Pods are crashing — possible causes: OOM (model too large for memory limit), bad startup, model file not found |
| `Missing` | The deployment was deleted — ArgoCD with `selfHeal` will recreate it |
| `Unknown` | Cluster connectivity issue |

---

## Setting up readiness and liveness probes

A truly healthy inference service is not just "running" — it should be *ready to serve predictions*. Let's add proper probes to our deployment:

```yaml
containers:
- name: inference-server
  image: my-registry/fraud-model:v3.2
  readinessProbe:
    httpGet:
      path: /health     # your inference API should expose this endpoint
      port: 8080
    initialDelaySeconds: 30    # give the model time to load
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 60    # longer delay — model loading can be slow
    periodSeconds: 30
```

> **Why this matters in MLOps:** Large models (transformers, LLMs) can take 30–120 seconds to load into memory. Without a proper `initialDelaySeconds`, Kubernetes will kill and restart the pod repeatedly before the model even has a chance to load. We see this constantly in the field.

ArgoCD's health status will be `Progressing` until the readiness probe passes — which is the correct behavior.

---

## Simulating the full automated loop

Let's see what the complete automated MLOps deployment loop looks like:

```
1. CI retrains fraud-model, pushes fraud-model:v3.3 to registry
2. CI updates deployment.yaml in Git: image tag → v3.3
3. ArgoCD detects Git change within 3 minutes
4. ArgoCD syncs: tells Kubernetes to roll out fraud-model:v3.3
5. Kubernetes starts new pods with v3.3, waits for readiness probe
6. Once probe passes, old v3.2 pods are terminated
7. ArgoCD reports Healthy
```

No human needed after step 1 and 2. That's the power of this setup.

---

## Common mistakes at this stage

- **Enabling auto-sync on production without approval gates.** In MLOps, you often want a human to validate A/B metrics before promoting to 100% traffic. Use manual sync on prod, auto-sync on dev/staging.
- **Forgetting `initialDelaySeconds` for model loading.** Large models need time to load into memory. Without this, Kubernetes will crash-loop your pods.
- **Enabling `prune` before your Git repo is complete.** If your repo only has some of your resources, `prune` will delete the ones that aren't there.

---

## Summary

- **Manual sync** gives you deployment control — good for production.
- **Auto sync** automates the full MLOps loop — good for dev and staging.
- `prune` enforces Git as the complete truth. `selfHeal` prevents manual drift.
- Proper **readiness probes** are critical for ML services — models need time to load.

---

## What's next

You know how to deploy and auto-sync a single model. In the next chapter, we'll structure a real MLOps platform with multiple environments — dev, staging, and production — each running different versions of our models, all managed from one Git repo.
