# Chapter 1 — What is Continuous Delivery, and why ArgoCD?

---

## Let's start with a real problem you already know

As MLOps engineers, we spend a lot of time training models, tuning hyperparameters, and evaluating metrics. But here is a question we don't ask often enough:

**Once your model is ready, how does it actually get to production?**

Right now, many teams do it by hand. You SSH into a server, copy the new model artifact, restart the inference service, and hope nothing breaks. That works once. Maybe twice.

But think about what your day looks like at scale:
- You retrain your model every night on fresh data
- You have three environments: dev, staging, and production
- Your team has five data scientists pushing changes simultaneously

Doing deployments by hand at this pace is slow, error-prone, and exhausting. One wrong tag on a Docker image, one missed environment — and suddenly your production model is three versions behind.

That's exactly the problem **Continuous Delivery (CD)** solves.

---

## What is Continuous Delivery?

Let's be precise, because we often see CI and CD used interchangeably — they are not the same.

- **Continuous Integration (CI)** is about automatically building, testing, and packaging your code or model whenever you push a change. Think of it as the "prepare the package" step.
- **Continuous Delivery (CD)** is about automatically and reliably *delivering* that package to a target environment. Think of it as the "ship the package" step.

In MLOps, your CI pipeline might:
1. Run unit tests on your model code
2. Train or retrain the model
3. Evaluate metrics (accuracy, F1, latency)
4. Build and push a Docker image of your inference service

Your CD pipeline — powered by **ArgoCD** — then takes that Docker image and deploys it to Kubernetes automatically.

---

## Why Kubernetes? A quick reminder

You already know Docker. Kubernetes is the next layer.

Think of Docker as "how you package one app." Kubernetes is "how you run and manage dozens of those apps reliably — with health checks, auto-restart, scaling, and rollback."

For MLOps, Kubernetes is a natural fit:
- Run multiple model versions simultaneously (essential for A/B testing and canary deployments)
- Auto-scale your inference service based on incoming traffic
- Roll back instantly if a new model degrades in production

We will introduce Kubernetes concepts progressively throughout this course. You do not need to master it before we start.

---

## Enter ArgoCD — and the GitOps philosophy

ArgoCD is a CD tool built for Kubernetes. But what makes it special is the philosophy it follows: **GitOps**.

Here is what GitOps means in one sentence:

> Your Git repository is the single source of truth. What is in Git is what should run in your cluster. ArgoCD watches your repo and makes sure reality matches what you wrote.

For us as MLOps engineers, this is powerful. Imagine your repo looks like this:

```
ml-platform/
├── models/
│   ├── fraud-detection/
│   │   └── deployment.yaml   ← image: my-registry/fraud-model:v3.1
│   └── recommendation/
│       └── deployment.yaml   ← image: my-registry/reco-model:v1.8
└── ...
```

When your CI pipeline trains a new fraud detection model and pushes `fraud-model:v3.2` to your registry, it also updates `deployment.yaml` in Git. ArgoCD detects that change and deploys `v3.2` automatically — traceable, auditable, and reversible.

---

## What we gain as MLOps engineers

| Without GitOps | With GitOps + ArgoCD |
|---|---|
| "Who deployed this model?" | Every deployment = a Git commit with author and timestamp |
| Rolling back means SSH + manual commands | Rolling back = `git revert` + ArgoCD syncs automatically |
| Environments drift apart silently | ArgoCD continuously reconciles each environment to Git |
| Deployments are stressful | Deployments are boring — which is exactly what we want |

---

## Common misconceptions

- **"ArgoCD will train my model."** No. ArgoCD only handles deployment. Your training pipeline (Kubeflow, MLflow, GitHub Actions…) is a separate concern.
- **"I need to be a Kubernetes expert first."** You do not. We will introduce Kubernetes objects as we need them, step by step.

---

## Summary

- Deploying ML models by hand does not scale — CD tools automate this reliably.
- **CI** builds and packages; **CD** delivers. ArgoCD is the CD layer.
- ArgoCD follows **GitOps**: Git defines what should run, ArgoCD makes it happen.
- Every deployment becomes a traceable, auditable, reversible Git commit.

---

## What's next

In the next chapter, we will go through the core vocabulary of ArgoCD — Applications, sync, health, and more. Understanding these concepts before we touch anything will save you a lot of confusion later.
