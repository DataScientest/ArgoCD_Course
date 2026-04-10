# Chapter 2 — Core Concepts: The Language of ArgoCD

---

## Why we learn the vocabulary first

When you start using ArgoCD, you will encounter words like *Application*, *sync*, *source*, *destination*, and *health*. These words have very specific meanings in ArgoCD.

If we understand them before touching anything, everything else will click much faster. So let's go through them one by one, always anchoring each concept to what we know as MLOps engineers.

---

## Concept 1: The Application

In ArgoCD, an **Application** is the central object. It is a configuration that answers two questions:

1. **Where is my desired state?** — the Git repository that holds your config files
2. **Where should it be deployed?** — the Kubernetes cluster and namespace

Think of it like a deployment contract:
> "Take the inference service configuration from this Git folder and run it in this Kubernetes namespace."

In our MLOps world, you will typically have one Application per model or per service — for example, `fraud-detection-app`, `recommendation-app`, `feature-store-app`.

---

## Concept 2: Source and Destination

Every ArgoCD Application has a **source** and a **destination**.

- **Source** = your Git repository. This is where you store the files that describe *how* your app should be deployed: which Docker image to use, how many replicas, resource limits, environment variables, etc.
- **Destination** = your Kubernetes cluster and the **namespace** where the app will live.

> **Namespace?** Think of it as a folder inside Kubernetes. It groups related workloads together so they don't interfere with each other. We'll typically have namespaces like `fraud-detection-dev`, `fraud-detection-prod`, etc.

```
Git Repo (source)                     Kubernetes Cluster (destination)
┌──────────────────────────┐          ┌──────────────────────────────────┐
│ models/fraud-detection/  │  ──▶    │ namespace: fraud-detection-prod  │
│   deployment.yaml        │         │   running: fraud-model:v3.2      │
│   service.yaml           │         └──────────────────────────────────┘
└──────────────────────────┘
```

---

## Concept 3: Desired state vs. Live state

This is the heart of how ArgoCD thinks — and it maps directly to how we think about model versioning.

- **Desired state** = what your Git repo says should be running. For us, this is "model v3.2 with 3 replicas and 2GB memory."
- **Live state** = what is actually running in the cluster right now. Maybe it's still model v3.1.

ArgoCD constantly compares these two. If they match — great. If they don't — ArgoCD can fix it automatically.

This is exactly the same mental model as: *"the experiment I want to run"* vs. *"the experiment currently running."*

---

## Concept 4: Sync

**Syncing** is the act of making the live state match the desired state.

When your CI pipeline updates the Docker image tag in Git — say from `fraud-model:v3.1` to `fraud-model:v3.2` — the desired state changes. ArgoCD detects this and can **sync**: it applies the new config to the cluster, pulling the new image and restarting the inference pods.

You can trigger a sync manually, or let ArgoCD do it automatically on every Git push. We'll configure this in Chapter 5.

---

## Concept 5: Health

ArgoCD doesn't just deploy — it also watches whether your app is **healthy** after deploying.

For an ML inference service, this matters a lot. A successful deployment doesn't mean your model is responding correctly. ArgoCD checks:
- Did the containers start?
- Are all expected pods running?
- Is the service responding to readiness probes?

ArgoCD gives your app one of these statuses:

| Status | What it means in MLOps context |
|---|---|
| `Healthy` | Your inference service is up and responding |
| `Progressing` | Pods are starting — new model image is being pulled |
| `Degraded` | Something is wrong — pods crashing, OOM, bad startup |
| `Missing` | The resource doesn't exist in the cluster yet |
| `Unknown` | ArgoCD can't reach the cluster to check |

---

## Putting it all together — the MLOps deployment loop

Here is the full picture of what happens when we push a new model version:

```
CI trains fraud-model:v3.2 and pushes to Docker registry
        │
        ▼
CI updates deployment.yaml in Git: image tag → v3.2
        │
        ▼
ArgoCD detects the Git change (desired state updated)
        │
        ▼
ArgoCD compares desired state ↔ live state
        │
        ▼
Difference found → ArgoCD syncs (applies deployment.yaml to Kubernetes)
        │
        ▼
Kubernetes pulls fraud-model:v3.2 and restarts inference pods
        │
        ▼
ArgoCD monitors health — are the new pods healthy?
```

---

## Common misconceptions

- **"Sync" is not "build."** Syncing does not retrain or rebuild your model. It only applies already-built config to Kubernetes.
- **The Git repo does not store model weights or Docker images.** It stores *configuration files* that reference images by tag. The images live in your container registry (ECR, Docker Hub, GCR…). The model weights live in your model registry (MLflow, S3, etc.).

---

## Summary

- An **Application** links a Git source to a Kubernetes destination.
- ArgoCD compares **desired state** (Git) to **live state** (cluster).
- **Syncing** applies the Git state to the cluster.
- **Health** tells us if our inference service is actually running correctly after a sync.

---

## What's next

Now that we speak ArgoCD's language, it's time to install it. In the next chapter, we will set up ArgoCD on a local Kubernetes cluster so you can start experimenting hands-on.
