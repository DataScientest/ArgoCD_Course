# Chapter 4 — Your First ArgoCD Application

---

## What we're building today

By the end of this chapter, you will have a real ML inference service running in Kubernetes — deployed and managed by ArgoCD from a Git repository.

We will simulate a realistic MLOps scenario: a fraud detection model exposed as a REST API, described in Git, and deployed automatically by ArgoCD. The model itself is a placeholder — the goal is to understand the full deployment flow.

---

## The Git repository structure we'll use

For ArgoCD to deploy something, we need a Git repository with Kubernetes configuration files. We'll use the official ArgoCD example apps repo:

```
https://github.com/argoproj/argocd-example-apps
```

We'll work with the `guestbook` app as our stand-in for a fraud detection inference service. In your real MLOps projects, this folder would contain files like:

```
fraud-detection/
├── deployment.yaml    ← which Docker image, how many replicas, resource limits
├── service.yaml       ← how to expose the inference API
└── configmap.yaml     ← environment variables (model path, threshold, etc.)
```

---

## Understanding the files ArgoCD will read

Before deploying, let's understand what `deployment.yaml` does in the context of an ML service:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraud-detection-api
spec:
  replicas: 2                         # run 2 instances for redundancy
  selector:
    matchLabels:
      app: fraud-detection
  template:
    spec:
      containers:
      - name: inference-server
        image: my-registry/fraud-model:v3.2   # ← this is what CI updates
        resources:
          requests:
            memory: "2Gi"             # minimum RAM for our model
            cpu: "500m"
          limits:
            memory: "4Gi"             # model won't exceed this
            cpu: "1"
        ports:
        - containerPort: 8080         # the API listens here
```

ArgoCD reads this file from Git and applies it to Kubernetes. When your CI pipeline changes the image tag from `v3.2` to `v3.3`, ArgoCD detects the diff and re-applies.

---

## Step 1 — Create the Application via the UI

Make sure your port-forward is running:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open **https://localhost:8080** and log in.

1. Click **"+ New App"** (top left)
2. Fill in the form:

| Field | Value |
|---|---|
| Application Name | `fraud-detection` |
| Project | `default` |
| Sync Policy | `Manual` (for now) |

3. Under **Source**:

| Field | Value |
|---|---|
| Repository URL | `https://github.com/argoproj/argocd-example-apps` |
| Revision | `HEAD` |
| Path | `guestbook` |

4. Under **Destination**:

| Field | Value |
|---|---|
| Cluster URL | `https://kubernetes.default.svc` |
| Namespace | `fraud-detection-dev` |

5. Click **"Create"**.

> We're using a dedicated namespace `fraud-detection-dev` — good practice in MLOps to isolate each model and each environment.

First, create the namespace:

```bash
kubectl create namespace fraud-detection-dev
```

---

## Step 2 — Understand the OutOfSync status

After creating, you'll see your app card in the dashboard with status **OutOfSync**.

This is not an error. It means:
- Git says the `fraud-detection` service should exist (desired state)
- The `fraud-detection-dev` namespace is empty (live state)
- They don't match → OutOfSync

This is exactly what we want to see before a first deployment.

---

## Step 3 — Sync the Application

Click on your app card to open the detail view.

Click **"Sync"**, then **"Synchronize"** in the confirmation panel.

ArgoCD will:
1. Read the YAML files from the Git repo
2. Apply them to the `fraud-detection-dev` namespace in Kubernetes
3. Kubernetes will pull the Docker image and start the pods

Watch the app graph update in real time — you'll see deployment, service, and replicaset appear one by one.

After a minute or so, the status changes to **Synced** and **Healthy**.

---

## Step 4 — Do the same thing via the CLI

The CLI is what we'll use in real CI/CD pipelines and scripts. Let's practice it.

Delete the app you just created from the UI, then run:

```bash
# Create the namespace
kubectl create namespace fraud-detection-dev

# Create the ArgoCD Application
argocd app create fraud-detection \
  --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace fraud-detection-dev
```

Each flag maps to a UI field:
- `--repo` → the Git repository URL
- `--path` → the folder inside the repo containing our config files
- `--dest-server` → which Kubernetes cluster to target
- `--dest-namespace` → which namespace inside that cluster

Sync it:
```bash
argocd app sync fraud-detection
```

Check its status:
```bash
argocd app get fraud-detection
```

You should see:
```
Name:               argocd/fraud-detection
Sync Status:        Synced to HEAD
Health Status:      Healthy
```

---

## Step 5 — Simulate a model update

This is the MLOps moment we've been building toward. Let's simulate what happens when your CI pipeline pushes a new model version.

In a real setup, your CI would update the image tag in `deployment.yaml` automatically. Here, we'll do it manually to observe the behavior:

```bash
# Check the current image tag
argocd app get fraud-detection --output json | grep image

# Now imagine CI pushed fraud-model:v3.3 to the registry
# and updated deployment.yaml in Git from v3.2 to v3.3
# ArgoCD would detect OutOfSync, and you'd sync again:
argocd app sync fraud-detection
```

This is the core loop we will automate in Chapter 5.

---

## Step 6 — Verify the deployment

Check that pods are running:

```bash
kubectl get pods -n fraud-detection-dev
```

You should see pods with status `Running`. Check the events if something looks off:

```bash
kubectl describe pod <pod-name> -n fraud-detection-dev
```

---

## Common mistakes at this stage

- **Using the wrong destination namespace.** Always create the namespace before creating the Application, or enable `CreateNamespace=true` in your sync options.
- **Expecting to call the API immediately.** The service is running inside the cluster but not exposed externally yet. We'll cover service exposure in later chapters.
- **Syncing before the namespace exists.** ArgoCD will throw an error. Always create destination namespaces first.

---

## Summary

- An ArgoCD Application connects a Git repo path to a Kubernetes namespace.
- **OutOfSync** = the desired state differs from the live state — this is normal before a first sync.
- **Syncing** applies the Git state to the cluster and starts your inference pods.
- You can create and manage Applications via the UI or CLI — both are equally valid.

---

## What's next

Your inference service is running. But you triggered the sync manually. In the next chapter, we will automate this — ArgoCD will sync automatically whenever your CI pipeline updates the image tag in Git. That's the complete MLOps deployment loop.
