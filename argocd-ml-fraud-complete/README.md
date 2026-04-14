# ArgoCD / Argo Rollouts — Repo Terminé

Ce dépôt correspond à une version **terminée** du projet fil rouge.

Il sert côté formateur :

- de référence fonctionnelle
- de correction
- de support de démonstration pour les labs

Le point d'entrée apprenant reste le template.

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

## Structure du dépôt

```txt
argocd-ml-fraud-complete/
├── README.md
├── Makefile
├── service/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── tests/
├── scripts/
└── k8s/
```

## Vérifier le service localement

### Installer les dépendances

```bash
make install
```

### Lancer le service

```bash
make run
```

### Lancer les tests

```bash
make test
```

Les tests couvrent déjà :

- `/health`
- `/predict`
- `/metrics`

## Démarrage rapide du lab

### 1. Créer le cluster local

```bash
make kind-create
```

### 2. Installer les briques

```bash
bash scripts/install-ingress.sh
bash scripts/install-rollouts.sh
bash scripts/install-monitoring.sh
```

### 3. Déployer la base Kubernetes

```bash
make apply-base
```

### 4. Appliquer les manifests selon la démonstration visée

```bash
make apply-shadow
make apply-canary
make apply-bluegreen
make apply-analysis
```

## Makefile

Commandes disponibles :

- `make install`
- `make run`
- `make status`
- `make test`
- `make build-v1`
- `make build-v2`
- `make build-v2-buggy`
- `make kind-create`
- `make kind-delete`
- `make apply-base`
- `make apply-shadow`
- `make apply-canary`
- `make apply-bluegreen`
- `make apply-analysis`

## Note importante

Ce dépôt donne une base cohérente pour les démonstrations.

Selon votre environnement de lab, vous pourrez encore avoir besoin de :

- charger les images dans `kind`
- adapter les noms d'images
- brancher une stack Prometheus / Grafana complète

L'objectif de ce dépôt est d'offrir une référence technique claire et lisible pour accompagner le module.
