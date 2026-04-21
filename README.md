# ArgoCD_Course

Ce dépôt regroupe le support projet du module **Progressive Delivery MLOps avec Argo sur Kubernetes**.

## Use case du module

Tout le projet repose sur un même fil rouge :

**un service de scoring de fraude en temps réel**.

Le service est volontairement simple, mais crédible dans un contexte MLOps.

Il expose trois endpoints :

- `POST /predict`
- `GET /health`
- `GET /metrics`

Le module manipule trois versions :

- `v1` : version stable
- `v2` : nouvelle version candidate
- `v2-buggy` : version volontairement dégradée

## Objectif pédagogique

Le but n'est pas seulement de lire des explications sur Argo Rollouts.

Le but est de :

- suivre un projet concret
- appliquer les notions au fur et à mesure
- observer ce que font vraiment les stratégies de déploiement progressif

## Prérequis

Avant de commencer, assurez-vous d'avoir installé les outils suivants sur votre machine :

- `git`
- `uv`
- `docker`
- `kind`
- `kubectl`
- `make`
- `helm`

Pour la suite du module, vous utiliserez aussi :

- le plugin `kubectl argo rollouts`

Pourquoi ces outils sont nécessaires :

- `git` pour récupérer le dépôt du projet
- `uv` pour gérer l'environnement Python, installer Python `3.11` si besoin, et installer les dépendances
- `docker` pour construire et exécuter les images
- `kind` pour créer un cluster Kubernetes local
- `kubectl` pour interagir avec le cluster
- `make` pour lancer plus facilement les commandes du projet
- `helm` pour installer Prometheus et Grafana dans le cluster local

Le projet utilise Python `3.11`.
Si votre machine a une version plus ancienne de Python, ce n'est pas bloquant : `uv` pourra créer l'environnement avec Python `3.11` automatiquement.

## Installation rapide de quelques outils sur Linux

### Installer `kubectl`

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Installer `kind`

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Installer `helm`

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Vérifier

```bash
kubectl version --client
kind version
helm version
```

## Structure du dépôt

```txt
ArgoCD_Course/
├── README.md
├── Makefile
├── service/
├── scripts/
└── k8s/
```

## Bonnes pratiques retenues

Le projet introduit déjà quelques habitudes utiles :

- utilisation d'un fichier `.env`
- présence d'un `Makefile`
- présence de tests locaux du service
- séparation claire entre service, scripts et manifests Kubernetes


## Premiers pas

### 1. Installer les dépendances du service

```bash
make install
```

Cette commande utilise `uv` pour :

- installer Python `3.11` si nécessaire
- créer l'environnement virtuel `.venv`
- installer les dépendances du service

### 2. Préparer le `.env`

```bash
cp service/.env.example service/.env
```

Valeur de départ recommandée :

```env
MODEL_VERSION=v1
```

### 3. Vérifier l'état initial du service

```bash
make status
```

### 4. Lancer le service localement

```bash
make run
```

### 5. Préparer le cluster local

```bash
make kind-create
```

### 6. Installer les briques du lab

```bash
bash scripts/install-ingress.sh
bash scripts/install-rollouts.sh
```

### 7. Installer le plugin `kubectl argo rollouts`

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

Puis vérifiez :

```bash
kubectl-argo-rollouts version
```

### 8. Appliquer la base du projet

```bash
make apply-namespace
make apply-services
```

### 9. Construire et charger les deux versions pour le shadow

```bash
make build-v1
make build-v2
make load-v1
make load-v2
```

### 10. Déployer les deux versions dans le cluster

```bash
make apply-shadow-base
make apply-shadow-ingress
```

### 11. Envoyer une première requête de test

Si vous travaillez encore localement sur le service seul, laissez `make run` tourner dans un premier terminal, puis ouvrez un second terminal :

```bash
make sample-request
```

Pour observer le shadow dans l'infrastructure Kubernetes, utilisez ensuite :

```bash
make sample-shadow-request
```

Puis regardez les pods et leurs logs :

```bash
kubectl get pods -n fraud-detection
kubectl logs deployment/fraud-v1 -n fraud-detection
kubectl logs deployment/fraud-v2 -n fraud-detection
```

Ce que vous devez constater :

- la réponse visible vient de `v1`
- `v2` reçoit aussi la requête grâce au mirroring

## Commandes utiles

- `make install`
- `make run`
- `make status`
- `make sample-request`
- `make sample-shadow-request`
- `make build-image`
- `make build-v1`
- `make build-v2`
- `make load-v1`
- `make load-v2`
- `make kind-create`
- `make kind-delete`
- `make apply-namespace`
- `make apply-services`
- `make apply-shadow-base`
- `make apply-shadow-ingress`
- `make cleanup-shadow`
- `make apply-canary`
- `make update-canary-to-v2`
- `make cleanup-canary`
- `make apply-bluegreen`
- `make update-bluegreen-to-v2`
- `make cleanup-bluegreen`
- `make build-v2-buggy`
- `make load-v2-buggy`
- `make apply-analysis-template`
- `make apply-servicemonitor`
- `make apply-analysis-rollout`
- `make update-analysis-to-v2-buggy`

## Petite démo monitoring

Une fois le chapitre 6 lancé, vous pouvez vérifier les métriques visuellement.

### Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Puis ouvrez :

```txt
http://127.0.0.1:9090/graph
```

### Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Puis ouvrez :

```txt
http://127.0.0.1:3000
```

Identifiants par défaut :

- utilisateur : `admin`
- mot de passe : `admin`

### Requêtes utiles

```promql
sum(rate(fraud_prediction_errors_total{model_version="v2-buggy"}[1m])) or vector(0)
```

```promql
histogram_quantile(
  0.95,
  sum(rate(fraud_prediction_latency_seconds_bucket{model_version="v2-buggy"}[1m])) by (le)
) or vector(0)
```
