# Chapter 8 — Troubleshooting: What to Do When Things Go Wrong

---

## The reality of production MLOps

At some point, something will break.

A deployment will hang. A model will fail its health check. ArgoCD will show `OutOfSync` on a Monday morning with no obvious cause. Your fraud detection service will stop responding and an alert will wake you up.

This is not a sign that you did something wrong. It is the normal operating condition of any production system. What separates a confident MLOps engineer from a nervous one is not whether things break — it is knowing exactly where to look and what to do.

This chapter is a practical reference. We will go through the most common failure patterns you will encounter with ArgoCD and Kubernetes-based inference services, and give you a concrete diagnostic approach for each one.

---

## The mental model: every failure has a layer

When something goes wrong, think in layers:

```
Layer 1: ArgoCD itself         → Is ArgoCD aware of the problem?
Layer 2: Kubernetes objects    → Did the manifests apply correctly?
Layer 3: Pod / container       → Is the container running?
Layer 4: Application           → Is the model responding?
```

Always start at Layer 1 and move down. Jumping to Layer 3 while Layer 2 has a misconfigured manifest wastes time.

---

## The first commands to run

When something is wrong, these four commands give you the full picture in under two minutes:

```bash
# 1. What does ArgoCD think is happening?
argocd app get fraud-detection-production

# 2. What objects are in a bad state in Kubernetes?
kubectl get pods -n fraud-detection-production

# 3. Why is a pod not running?
kubectl describe pod <pod-name> -n fraud-detection-production

# 4. What is the container actually logging?
kubectl logs <pod-name> -n fraud-detection-production --tail=100
```

Run these in order. Do not skip ahead.

---

## Failure pattern 1: Application stuck in `OutOfSync`

**What you see in the ArgoCD UI:** The application shows `OutOfSync` and does not self-heal even after a manual sync.

**What it usually means:** There is a difference between what is in Git and what is running in the cluster — but ArgoCD is either not able to apply the change, or a resource is being managed outside of Git.

### Diagnose it

```bash
argocd app diff fraud-detection-production
```

This command shows you the exact diff between Git and the live cluster — like `git diff` but for Kubernetes state. Read it carefully. The diff will usually point you directly to the problem.

Common causes you will see in the diff:

| What you see | What it means |
|---|---|
| `image: my-registry/fraud-model:v3.2` in cluster vs `v3.3` in Git | Someone updated the image manually (`kubectl set image`) — ArgoCD drift |
| An entire resource missing from Git | The resource was created directly in the cluster without a manifest |
| A `resourceVersion` mismatch | Usually harmless — ArgoCD will resolve this on next sync |

### Fix it

If the drift was intentional (a hotfix applied manually during an incident), bring Git in sync with the cluster first, then let ArgoCD manage it going forward.

If the drift was accidental, sync and let ArgoCD overwrite:

```bash
argocd app sync fraud-detection-production --force
```

> `--force` tells ArgoCD to overwrite any conflicting live state with what is in Git. Use this when you are confident Git is the source of truth.

---

## Failure pattern 2: Pods stuck in `Pending`

**What you see:** `kubectl get pods` shows one or more pods in `Pending` state. They never start.

**What it means:** Kubernetes accepted the pod specification but cannot schedule the pod anywhere. It is waiting for resources.

### Diagnose it

```bash
kubectl describe pod <pod-name> -n fraud-detection-production
```

Scroll to the `Events` section at the bottom of the output. The message will tell you exactly why:

```
Events:
  Warning  FailedScheduling  30s   default-scheduler
    0/3 nodes are available: 3 Insufficient memory.
```

This means no node in your cluster has enough memory to place this pod.

### Common causes for inference workloads

- **Model too large.** A fraud detection model loaded into memory might require 8–16 GB. If your nodes only have 4 GB allocatable memory, the pod cannot start.
- **Resource requests too high.** Check your manifest:

```yaml
resources:
  requests:
    memory: "16Gi"   # ← is this realistic for your node size?
    cpu: "4"
```

- **Node selector or affinity rules blocking placement.** If you added GPU node selectors (`nvidia.com/gpu: "1"`) and no GPU node exists, the pod will stay pending.

### Fix it

Adjust your resource requests to match what your nodes can actually provide, or scale up your cluster. Do not remove resource requests entirely — they exist to protect other workloads on the same node.

---

## Failure pattern 3: Pods in `CrashLoopBackOff`

**What you see:** A pod starts, crashes, Kubernetes restarts it, it crashes again. Kubernetes increases the wait time between restarts exponentially. The status shows `CrashLoopBackOff`.

**What it means:** The container starts successfully (the image pulled correctly), but the process inside crashes immediately after launch.

### Diagnose it

```bash
kubectl logs <pod-name> -n fraud-detection-production --previous
```

`--previous` is critical here. It shows you the logs from the *previous* run of the container — the one that crashed. Without it, you see the logs from the current (also crashing) run, which may be nearly empty.

### Common causes for MLOps inference services

- **Model file not found.** The container starts, tries to load the model from a path like `/models/fraud-model-v3.3.pkl`, but the file is not there. Check your volume mounts and your model artifact paths.
- **Wrong environment variable.** Many inference servers read configuration from environment variables (`MODEL_PATH`, `PORT`, `WORKERS`). A missing or misconfigured env var crashes startup.
- **Dependency mismatch.** The container image was built with Python 3.9, but the model was serialized with Python 3.11. Or the `scikit-learn` version changed between training and serving.
- **Out of memory during model loading.** The model is too large for the container's memory limit. The OS kills the process (OOM Kill). Check:

```bash
kubectl describe pod <pod-name> -n fraud-detection-production | grep -A5 "Last State"
```

If you see `Reason: OOMKilled`, the container ran out of memory.

### Fix it

Read the crash logs carefully. The error message in the logs is almost always the direct cause. Fix the underlying issue (model path, env var, image dependency), update your manifest or Docker image, commit to Git, and let ArgoCD sync.

---

## Failure pattern 4: ArgoCD shows `Degraded` health

**What you see:** The application health shows `Degraded` — not `Synced` and not `Healthy`.

**What it means:** ArgoCD applied the manifests successfully, but one or more Kubernetes resources report an unhealthy state. Most commonly, a Deployment reports that its pods are not all ready.

### Diagnose it

```bash
argocd app get fraud-detection-production
```

Look at the resource list in the output. One of the resources will show `Degraded`. Note its kind and name, then investigate directly:

```bash
kubectl rollout status deployment/fraud-detection-api -n fraud-detection-production
```

If the rollout is stuck:

```bash
kubectl describe deployment fraud-detection-api -n fraud-detection-production
```

The `Conditions` section will tell you what is blocking the rollout — usually a failed readiness probe or unavailable replicas.

### The readiness probe connection

ArgoCD uses the **readiness probe** to determine health. If your inference server takes 60 seconds to load a model but your readiness probe starts checking after 10 seconds, every pod will fail its probe and ArgoCD will report `Degraded`.

Fix: match your `initialDelaySeconds` to your actual model loading time:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 60    # give the model time to load
  periodSeconds: 10
  failureThreshold: 3
```

---

## Failure pattern 5: Sync succeeds but the model is wrong

**What you see:** ArgoCD shows `Synced` and `Healthy`. Pods are running. But predictions are wrong, or you are getting unexpected responses.

**What it means:** The infrastructure is fine. The problem is at the application layer — the model itself, its configuration, or the data it is receiving.

This is the trickiest category because ArgoCD will not catch it. The system looks healthy to every infrastructure tool.

### Diagnose it

Start by confirming which version is actually running:

```bash
kubectl get pods -n fraud-detection-production -o jsonpath='{.items[*].spec.containers[*].image}'
```

This prints the actual image tag running in your pods. Compare it to what you expect from Git.

Then probe the model directly:

```bash
# Port-forward to the pod for local testing
kubectl port-forward pod/<pod-name> 8080:8080 -n fraud-detection-production

# Send a test inference request
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"transaction_amount": 4500, "merchant_category": "online", "hour_of_day": 3}'
```

Check the response. If the prediction is wrong, the issue is in the model or the feature preprocessing, not in the infrastructure.

### Useful diagnostic endpoints to build into every inference service

| Endpoint | What it should return |
|---|---|
| `GET /health` | `{"status": "ok"}` — used by readiness probes |
| `GET /version` | `{"model": "fraud-model", "version": "v3.3", "trained_at": "2026-01-15"}` |
| `GET /metrics` | Prometheus metrics — prediction count, latency histograms, error rate |

If you have a `/version` endpoint, you can always confirm exactly which model artifact is serving.

---

## Failure pattern 6: ArgoCD itself is not working

**What you see:** You cannot reach the ArgoCD UI, or `argocd` CLI commands time out.

### Check the ArgoCD components

```bash
kubectl get pods -n argocd
```

All pods should be in `Running` state. The key components are:

```
argocd-server             ← UI and API
argocd-application-controller  ← watches Git and cluster
argocd-repo-server        ← clones Git repos and renders manifests
argocd-redis              ← caching layer
```

If any of these pods are in `CrashLoopBackOff` or `Pending`, diagnose them the same way you would any other pod — `describe` and `logs`.

### Check ArgoCD logs for sync errors

```bash
kubectl logs deployment/argocd-application-controller \
  -n argocd \
  --tail=50
```

This is where you will find errors like Git authentication failures, Helm rendering errors, or network timeouts when reaching your registry.

---

## The ArgoCD sync operation log

Every sync operation in ArgoCD is logged. When a sync fails, this is the first place to look:

```bash
argocd app sync-windows fraud-detection-production
```

Or in the UI: Application → Sync Status → click on the failed sync → read the operation log.

The operation log will tell you exactly which resource failed to apply and why — usually a validation error in your YAML or a missing namespace.

---

## Quick reference: diagnostic commands

```bash
# ArgoCD application state
argocd app get <app-name>
argocd app diff <app-name>
argocd app history <app-name>

# Force sync from Git
argocd app sync <app-name> --force

# Kubernetes pod state
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=100
kubectl logs <pod-name> -n <namespace> --previous   # logs from crashed container

# Kubernetes deployment state
kubectl rollout status deployment/<name> -n <namespace>
kubectl rollout history deployment/<name> -n <namespace>

# Emergency rollback (Kubernetes-level, bypasses ArgoCD)
kubectl rollout undo deployment/<name> -n <namespace>

# Argo Rollouts state (if using canary/blue-green)
kubectl argo-rollouts get rollout <name> -n <namespace> --watch
kubectl argo-rollouts abort <name> -n <namespace>
kubectl argo-rollouts promote <name> -n <namespace>
```

> **Important:** `kubectl rollout undo` is an emergency measure. It bypasses Git and creates drift. After using it, immediately update your Git manifest to reflect the reverted state so ArgoCD can take over again.

---

## Common mistakes at this stage

- **Reading logs from the current container instead of `--previous`.** If a container is in `CrashLoopBackOff`, the current container just started and its logs are nearly empty. Always use `--previous` to see the crash.
- **Ignoring the `Events` section in `kubectl describe`.** This section contains the most useful diagnostic information Kubernetes provides. It is at the bottom of the output and easy to miss.
- **Fixing the symptom instead of the cause.** If ArgoCD reports `OutOfSync` because someone manually patched the cluster, the fix is not to disable drift detection — it is to put the correct manifest in Git.
- **Using `--force` on `argocd app sync` habitually.** This flag discards live state and replaces it with Git. Used carelessly, it can wipe legitimate configuration. Reserve it for when you are certain Git is correct.
- **Not setting `initialDelaySeconds` for model loading.** ML models take time to deserialize from disk. Without an appropriate delay, the readiness probe will fail every time and your deployment will never reach `Healthy`.

---

## Summary

- Think in layers: ArgoCD → Kubernetes → Pod → Application. Diagnose from top to bottom.
- `argocd app diff` shows you exactly what is different between Git and the cluster.
- `kubectl describe pod` and `kubectl logs --previous` are your most important pod-level tools.
- `Degraded` health usually means a readiness probe failure — match your probe timing to your model loading time.
- ArgoCD does not catch application-level failures. Always build `/health`, `/version`, and `/metrics` endpoints into your inference services.

---

## What's next

You now have a complete ArgoCD toolkit for MLOps: from first principles, through installing and configuring ArgoCD, deploying across multiple environments, implementing production-grade deployment strategies, and recovering confidently when things go wrong.

The next step is to apply this to your own infrastructure — define your Git repository structure, write your first Application manifest, and deploy a real model. The patterns in this course give you everything you need to start.
