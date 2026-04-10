# Chapter 3 — Installing ArgoCD

---

## What we need to get started

Before we install ArgoCD, we need a Kubernetes cluster to install it on. For this course, we will use **kind** — a tool that runs a Kubernetes cluster inside Docker containers on your local machine.

Since you already know Docker, this is a natural starting point. No cloud account needed, no billing surprises.

> **kind** stands for "Kubernetes IN Docker." It is lightweight, easy to set up, and perfect for learning and local experimentation.

You will also need **kubectl** — the command-line tool for talking to Kubernetes. Think of it as the `docker` CLI, but for Kubernetes.

---

## Step 1 — Install kubectl

```bash
# On Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

```bash
# On macOS
brew install kubectl
```

Verify:
```bash
kubectl version --client
```

---

## Step 2 — Install kind

```bash
# On Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

```bash
# On macOS
brew install kind
```

Verify:
```bash
kind version
```

---

## Step 3 — Create a local Kubernetes cluster

Let's create a cluster named after what we'll use it for:

```bash
kind create cluster --name mlops-argocd
```

This command:
1. Pulls a Docker image containing a full Kubernetes installation
2. Starts it as a container on your machine
3. Automatically configures `kubectl` to point to this new cluster

It takes about a minute. When done, verify your cluster is running:

```bash
kubectl cluster-info --context kind-mlops-argocd
```

You should see:
```
Kubernetes control plane is running at https://127.0.0.1:XXXXX
```

You now have a real Kubernetes cluster running locally — inside a Docker container. We will deploy our ML services in here.

---

## Step 4 — Install ArgoCD

ArgoCD runs inside your Kubernetes cluster. You install it by applying official configuration files from the ArgoCD team.

First, create a dedicated namespace for ArgoCD:

```bash
kubectl create namespace argocd
```

> **Namespace reminder:** Think of this as creating a dedicated folder called `argocd` inside your cluster. All ArgoCD components will live there — separate from your ML workloads.

Then install ArgoCD:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/install.yaml
```

This applies a large configuration file that tells Kubernetes to run all ArgoCD components: its API server, its application controller, its repo server, its Redis cache, and more.

Wait for everything to be ready:

```bash
kubectl wait --for=condition=available --timeout=180s deployment --all -n argocd
```

This pauses until all ArgoCD components report that they are ready. It may take 2–3 minutes on the first run since images need to be pulled.

---

## Step 5 — Access the ArgoCD UI

ArgoCD comes with a web interface. To access it from your machine, forward a local port to the ArgoCD server:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

> **Port forwarding** creates a tunnel from your machine's port `8080` into the cluster. Keep this terminal open while you use the UI — if you close it, the UI becomes unreachable.

Open your browser and navigate to: **https://localhost:8080**

Your browser will warn you about an untrusted certificate — this is expected in a local setup. Click through to continue.

---

## Step 6 — Log in

The default username is `admin`. Retrieve the auto-generated password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode
```

Copy the output — that's your password. Log in with:
- **Username:** `admin`
- **Password:** (the value you just copied)

You should now see the ArgoCD dashboard. Empty for now — we will populate it in the next chapter.

> **Security note for MLOps teams:** In a real team setup, you would replace the default admin password immediately and configure SSO (GitHub, Google, LDAP). For this course, we keep it simple.

---

## Step 7 — Install the ArgoCD CLI

The CLI lets you interact with ArgoCD from your terminal — faster than the UI for many operations, and easier to script.

```bash
# On Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/argocd
```

```bash
# On macOS
brew install argocd
```

Log in via the CLI:

```bash
argocd login localhost:8080 --insecure
```

Use the same `admin` credentials. The `--insecure` flag is needed because we're using a self-signed certificate in local mode.

---

## Common mistakes at this stage

- **Forgetting to keep the port-forward running.** If you close the terminal running `kubectl port-forward`, the UI and CLI become unreachable. Just re-run the command.
- **Using the wrong namespace.** ArgoCD lives in the `argocd` namespace. Always add `-n argocd` to `kubectl` commands targeting ArgoCD itself. Your ML workloads will go in separate namespaces.
- **Panicking at the certificate warning.** The browser warning is normal in local development. It does not mean anything is broken.

---

## Summary

- **kind** lets us run a real Kubernetes cluster locally using Docker.
- ArgoCD is installed inside that cluster via `kubectl apply`.
- We access the UI via port-forwarding on `https://localhost:8080`.
- Default login: `admin` / (password from the Kubernetes secret).

---

## What's next

Our ArgoCD is installed and running. In the next chapter, we will create our very first ArgoCD Application — connecting a Git repository to our cluster and watching ArgoCD deploy an ML inference service automatically.
