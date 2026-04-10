# Chapter 7 — Deployment Strategies: Canary, Blue/Green, and MLOps

---

## The core problem: how do you know a new model is safe?

Here's a situation every MLOps engineer faces.

You've trained a new version of your fraud detection model. Offline metrics look great: recall improved by 3%, precision is up. Your evaluation pipeline gives it the green light.

But here's the uncomfortable truth: **offline metrics don't guarantee production behavior.**

The training data distribution might not perfectly match live traffic. Edge cases exist that your test set never covered. Model latency might spike under real load. The new model might interact differently with your feature store.

The only way to be truly sure is to test your model with real production traffic — but you can't just deploy to 100% of users and hope for the best. If the model degrades, every user is impacted.

This is where deployment strategies become essential.

---

## The three strategies

### Strategy 1: Recreate (all-or-nothing)

What we've used so far. ArgoCD stops the old version, starts the new one.

```
Before:   [v1] [v1] [v1]
During:   (brief interruption)
After:    [v2] [v2] [v2]
```

**In MLOps:** Acceptable for dev and staging. Never for production models where you need gradual validation.

---

### Strategy 2: Blue/Green

Two complete versions run simultaneously — the current (blue) and the new (green). Traffic points to only one at a time.

```
        Users
          │
          ▼
   ┌──────────────┐     ┌──────────────┐
   │  Blue (v1)  │     │  Green (v2)  │
   │  (live)     │     │  (standby)   │
   └──────────────┘     └──────────────┘
```

When you're ready, you switch traffic from blue to green instantly. No interruption.

**In MLOps:** Useful when you want to do a final validation of the new model (load test, smoke test, canary API call) before committing to it. Rollback is instant — just switch traffic back to blue.

**Cost:** You run double the infrastructure while both versions are live.

---

### Strategy 3: Canary (the MLOps gold standard)

You route a *fraction* of real production traffic to the new model. The rest continues on the current version.

```
100 incoming inference requests
        │
        ├──── 90 requests ──▶ [v1 — current fraud model]
        └──── 10 requests ──▶ [v2 — new fraud model]
```

You watch real production metrics — fraud recall, false positive rate, prediction latency, error rate — on that small slice. If everything looks good, you progressively increase the traffic share: 10% → 30% → 50% → 100%.

If metrics degrade, you cut the new model to 0% immediately. Only 10% of your users were exposed to the issue.

**This is the approach that defines mature MLOps practice.**

---

## Argo Rollouts: ArgoCD's companion for advanced strategies

Standard ArgoCD handles basic deployments. For canary and blue/green with fine-grained traffic control, we use **Argo Rollouts** — a companion tool that integrates natively with ArgoCD.

> Argo Rollouts replaces Kubernetes' standard `Deployment` object with a `Rollout` object that understands canary and blue/green natively.

ArgoCD applies your files from Git → Argo Rollouts orchestrates the progressive deployment.

### Installing Argo Rollouts

```bash
kubectl create namespace argo-rollouts

kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

Install the kubectl plugin for visualization:

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

---

## Canary deployment for a fraud detection model

Let's build a realistic canary rollout for our fraud detection service. We just trained `fraud-model:v3.3` and want to test it carefully before full rollout.

### The Rollout manifest

```yaml
# rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout                         # replaces "Deployment"
metadata:
  name: fraud-detection-api
  namespace: fraud-detection-production
spec:
  replicas: 10                        # 10 total instances
  selector:
    matchLabels:
      app: fraud-detection
  template:
    metadata:
      labels:
        app: fraud-detection
    spec:
      containers:
      - name: inference-server
        image: my-registry/fraud-model:v3.3   # new model version
        resources:
          requests:
            memory: "4Gi"
            cpu: "1"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 45     # model loading time
  strategy:
    canary:
      steps:
      - setWeight: 10                 # step 1: route 10% of traffic to v3.3
      - pause: {}                     # wait for manual approval
      - setWeight: 30                 # step 2: increase to 30%
      - pause: {duration: 15m}        # automatic pause — observe for 15 minutes
      - setWeight: 60                 # step 3: increase to 60%
      - pause: {duration: 15m}        # observe again
      - setWeight: 100                # step 4: full rollout — v3.3 is production
```

Each step is a decision point:
- `setWeight: 10` — 1 out of 10 pods serves v3.3, 9 still serve v3.2
- `pause: {}` — the rollout pauses and waits for a human to approve
- `pause: {duration: 15m}` — the rollout automatically pauses for 15 minutes, giving you time to observe metrics

---

## Observing and controlling the rollout

Store this file in Git, and ArgoCD will apply it to your cluster.

Watch the rollout in real time:

```bash
kubectl argo-rollouts get rollout fraud-detection-api \
  --namespace fraud-detection-production \
  --watch
```

Output:
```
Name:            fraud-detection-api
Status:          ॐ Paused
Step:            1/7
SetWeight:       10
ActualWeight:    10

REVISION  IMAGE                            REPLICAS  READY
2         my-registry/fraud-model:v3.3     1         1     ← 10% (1 pod out of 10)
1         my-registry/fraud-model:v3.2     9         9     ← 90%
```

You have 1 pod serving the new model. Your monitoring shows:
- Fraud recall: 94.1% (current production: 91.8%) ✓
- False positive rate: 6.2% (current: 7.1%) ✓
- p99 latency: 42ms (current: 38ms) — slightly higher, acceptable ✓

Looks good. Approve manually to proceed to the next step:

```bash
kubectl argo-rollouts promote fraud-detection-api \
  --namespace fraud-detection-production
```

If instead you see a spike in false positives or a latency regression, abort immediately:

```bash
kubectl argo-rollouts abort fraud-detection-api \
  --namespace fraud-detection-production
```

ArgoCD will roll back to v3.2 across all 10 pods. Your production model is unaffected.

---

## Automated analysis — the next level

In a mature MLOps platform, we don't want a human approving every canary step. We want the system to decide based on metrics.

Argo Rollouts provides `AnalysisTemplate` for this:

```yaml
# analysis-fraud-model.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: fraud-model-metrics
  namespace: fraud-detection-production
spec:
  metrics:
  - name: fraud-recall
    interval: 2m                          # check every 2 minutes
    successCondition: result[0] >= 0.90   # recall must stay above 90%
    failureLimit: 2                        # allow 2 failures before aborting
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(fraud_predictions_correct_total[5m]))
          /
          sum(rate(fraud_predictions_total[5m]))

  - name: api-error-rate
    interval: 1m
    successCondition: result[0] <= 0.01   # less than 1% errors
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_errors_total[5m]))
          /
          sum(rate(http_requests_total[5m]))
```

Integrate it into the Rollout:

```yaml
  strategy:
    canary:
      analysis:
        templates:
        - templateName: fraud-model-metrics   # run analysis at each step
      steps:
      - setWeight: 10
      - pause: {duration: 10m}               # observe automatically
      - setWeight: 30
      - pause: {duration: 10m}
      - setWeight: 100
```

Now: if fraud recall drops below 90% or API errors spike above 1%, Argo Rollouts automatically aborts the rollout and reverts to the previous model. Zero human intervention.

This is production-grade MLOps.

---

## Blue/Green for model validation

When you want to validate a new model *before* any user traffic touches it:

```yaml
  strategy:
    blueGreen:
      activeService: fraud-detection-active     # current live service
      previewService: fraud-detection-preview   # new model preview
      autoPromotionEnabled: false               # require manual promotion
      prePromotionAnalysis:                     # run analysis before switching traffic
        templates:
        - templateName: fraud-model-metrics
```

With this setup:
1. You deploy v3.3 — it's running but getting zero user traffic (preview service)
2. You run your validation suite against the preview service
3. ArgoCD runs `AnalysisTemplate` metrics automatically
4. If everything passes, you manually promote — traffic switches from v3.2 to v3.3 instantly
5. v3.2 stays running for a grace period in case you need to revert

---

## Deployment strategy decision guide

| Situation | Recommended strategy |
|---|---|
| Dev environment | Recreate — speed matters, stability doesn't |
| Staging environment | Blue/Green — validate before any user traffic |
| Production, low-risk update (config change, bug fix) | Blue/Green with automated analysis |
| Production, new model version | Canary — gradual traffic shift with metric analysis |
| Production, critical rollback needed | Abort rollout → instant revert to previous |

---

## Common mistakes at this stage

- **Using a standard `Deployment` instead of a `Rollout`.** Argo Rollouts only works with its own `Rollout` object. If you keep a standard Deployment, you get no canary or blue/green control.
- **Setting `pause: {}` and forgetting to promote.** The rollout will stay paused indefinitely. Add `duration` if you want it to auto-proceed after observation.
- **Not setting up Prometheus or any monitoring.** A canary without metrics observation is just a partial deployment. You need observability to make canary valuable.
- **Confusing ArgoCD sync status with rollout progress.** ArgoCD will show `Synced` when the Rollout object is applied — but the rollout might still be in progress. Check `kubectl argo-rollouts get rollout` for the actual rollout state.

---

## Summary

- **Recreate:** simple, full interruption, not suitable for production models.
- **Blue/Green:** two versions live simultaneously, instant traffic switch, good for pre-validation.
- **Canary:** gradual traffic shift with real user data — the gold standard for MLOps.
- **Argo Rollouts** is the tool that brings these strategies to ArgoCD.
- **AnalysisTemplate** automates the go/no-go decision based on your production metrics.

---

## What's next

In the next chapter, we will cover troubleshooting — the commands and patterns you will use when things go wrong in production. Because they will go wrong eventually, and we want you to be fast and confident when they do.
