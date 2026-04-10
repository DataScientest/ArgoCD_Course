# ArgoCD / Argo Rollouts — Repo Terminé

Ce dépôt correspond à une version **terminée** du projet fil rouge.

Il peut servir :

- de référence pédagogique
- de correction
- de support de démonstration pour les labs

Ce dépôt n'est pas pensé comme point d'entrée apprenant.
Le point d'entrée apprenant reste `argocd-ml-fraud-template`.

## Use case

Le service est un **service de scoring de fraude temps réel**.

Endpoints exposés :

- `POST /predict`
- `GET /health`
- `GET /metrics`

Versions manipulées dans le module :

- `v1`
- `v2`
- `v2-buggy`

## Dépôt et progression

Le dépôt est organisé pour illustrer les chapitres du cours :

- fondations du service ML
- shadow
- canary
- blue-green
- analysis automatisée

## Démarrage rapide

### 1. Créer le cluster local

```bash
kind create cluster --name argocd-ml --config scripts/kind-config.yaml
```

### 2. Installer les briques

```bash
bash scripts/install-ingress.sh
bash scripts/install-rollouts.sh
bash scripts/install-monitoring.sh
```

### 3. Déployer le namespace et les services

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/services/
```

### 4. Appliquer un rollout

```bash
kubectl apply -f k8s/rollouts/canary-rollout.yaml
kubectl argo rollouts get rollout fraud-rollout -n fraud-detection
```

## Important

Les images du service sont référencées ici sous des noms pédagogiques.

Dans un vrai lab, vous pourrez :

- les construire localement
- les charger dans `kind`
- ou les publier dans un registre
