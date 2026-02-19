# Chapter 7 — Common Mistakes and Troubleshooting

---

## Why this chapter exists

Even when you do everything right, things break. That's not a sign of failure — it's a normal part of working with real systems.

This chapter collects the most frequent problems that new ArgoCD users encounter, and shows you exactly how to diagnose and fix them.

---

## Problem 1: App is stuck in "Progressing"

**What you see:** The Application health shows `Progressing` for more than a few minutes.

**What it usually means:** A pod (container) is failing to start.

**How to diagnose:**

```bash
# List all pods and their status
kubectl get pods -n <your-namespace>
```

Look for pods with status `CrashLoopBackOff`, `ImagePullBackOff`, or `Error`.

```bash
# Get more details about a specific pod
kubectl describe pod <pod-name> -n <your-namespace>
```

Scroll to the `Events` section at the bottom — it usually tells you exactly what went wrong.

```bash
# Read the container's logs
kubectl logs <pod-name> -n <your-namespace>
```

---

## Problem 2: "ImagePullBackOff" error

**What you see:** A pod has status `ImagePullBackOff`.

**What it means:** Kubernetes couldn't download the Docker image. Either the image name is wrong, the tag doesn't exist, or the registry requires authentication.

**How to fix:**

1. Double-check the image name and tag in your config file. A typo is the most common cause.
2. If the image is in a private registry, you need to create a Kubernetes secret with your registry credentials and reference it in your deployment.

```bash
# Check the exact error message
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 Events
```

---

## Problem 3: App is "OutOfSync" but sync fails

**What you see:** ArgoCD shows the app is OutOfSync, you click Sync, but it immediately shows an error.

**Common causes and fixes:**

| Error message | Cause | Fix |
|---|---|---|
| `permission denied` | ArgoCD doesn't have rights to create a resource | Check your Kubernetes RBAC configuration |
| `namespace not found` | The destination namespace doesn't exist | Run `kubectl create namespace <name>` |
| `invalid yaml` | A config file has a syntax error | Validate your YAML files |
| `repository not found` | ArgoCD can't access the Git repo | Check the repo URL and credentials |

To see the detailed error:

```bash
argocd app get <app-name> --show-operation
```

---

## Problem 4: Changes in Git are not picked up

**What you see:** You pushed to Git, but ArgoCD still shows the old version.

**What to check:**

1. **Is auto-sync enabled?** If not, you need to sync manually.

```bash
argocd app sync <app-name>
```

2. **Is ArgoCD polling the right branch?** Check that your Application's `targetRevision` matches the branch you pushed to.

3. **Did the push actually succeed?** Verify on GitHub/GitLab that your commit appears.

4. **Force a refresh:**

```bash
argocd app get <app-name> --refresh
```

This forces ArgoCD to re-check the repo immediately instead of waiting for the next poll cycle.

---

## Problem 5: Resources are Degraded after sync

**What you see:** The sync succeeded (Synced), but health is `Degraded`.

**What it means:** The deployment was applied, but the app inside isn't working correctly.

**How to investigate:**

```bash
# Check which specific resource is degraded
argocd app get <app-name>
```

Look at the resource list — it shows the health of each individual Kubernetes resource.

```bash
# For a degraded pod, check logs
kubectl logs <pod-name> -n <namespace>

# For a deployment that has 0/1 ready pods
kubectl describe deployment <deployment-name> -n <namespace>
```

---

## Problem 6: "ComparisonError" in the UI

**What you see:** ArgoCD shows `ComparisonError` instead of Synced/OutOfSync.

**What it means:** ArgoCD can't compare the desired state with the live state. Usually a connectivity or permissions issue.

**How to fix:**

```bash
# Check ArgoCD's own logs
kubectl logs -n argocd deployment/argocd-application-controller
```

Common causes:
- The Kubernetes cluster ArgoCD is trying to connect to is unreachable
- RBAC permissions are too restrictive

---

## Problem 7: You accidentally deleted something important

**What you see:** A resource you need is gone from the cluster.

**The ArgoCD advantage:** Because your desired state is in Git, recovery is simple.

```bash
argocd app sync <app-name>
```

ArgoCD will re-create anything that's missing, based on what Git says should exist.

If the resource was deleted from Git too, revert the Git commit and sync again.

---

## General debugging toolkit

Here are the commands you'll use most often when troubleshooting:

```bash
# Overview of all apps and their status
argocd app list

# Detailed status of one app
argocd app get <app-name>

# Force ArgoCD to re-check the repo
argocd app get <app-name> --refresh

# Manually trigger a sync
argocd app sync <app-name>

# List all pods in a namespace
kubectl get pods -n <namespace>

# Describe a pod (shows events and errors)
kubectl describe pod <pod-name> -n <namespace>

# Read a pod's logs
kubectl logs <pod-name> -n <namespace>

# Read ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Read ArgoCD controller logs (handles sync logic)
kubectl logs -n argocd deployment/argocd-application-controller
```

---

## Common mistakes recap (from the whole course)

| Mistake | Why it happens | How to avoid it |
|---|---|---|
| Deploying to the wrong namespace | Forgetting `-n` or using the wrong name | Always double-check `--dest-namespace` in your Application |
| Storing secrets in Git | Not knowing the alternatives | Use Sealed Secrets or External Secrets Operator |
| Enabling `prune` too early | Not realizing it deletes resources | Only enable when your repo is a complete source of truth |
| Manually editing the cluster | Old habits from non-GitOps workflows | Let Git be the only way to make changes |
| Not checking pod logs when something breaks | Going straight to ArgoCD UI | Always check `kubectl logs` for the real error |

---

## Summary

- Most issues come down to: wrong image, wrong namespace, missing permissions, or bad YAML.
- ArgoCD's sync log and `kubectl describe` / `kubectl logs` are your two most powerful debugging tools.
- Because everything is in Git, recovery is almost always a sync away.

---

## What's next

Congratulations — you've completed the ArgoCD course! You now know:

- What CD and GitOps are and why they matter
- The core vocabulary of ArgoCD
- How to install ArgoCD locally
- How to create, sync, and monitor an Application
- How to use automatic sync with health checks
- How to structure multiple environments
- How to debug the most common problems

From here, you might explore:
- **Helm** — another way to template Kubernetes configs (works great with ArgoCD)
- **ApplicationSets** — ArgoCD's way to manage many Applications at once
- **Notifications** — get Slack or email alerts when deployments succeed or fail
- **RBAC in ArgoCD** — control who can deploy what in a team setting
