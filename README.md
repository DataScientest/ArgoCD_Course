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

Pour la suite du module, vous utiliserez aussi :

- le plugin `kubectl argo rollouts`

Pourquoi ces outils sont nécessaires :

- `git` pour récupérer le dépôt du projet
- `uv` pour gérer l'environnement Python et les dépendances
- `docker` pour construire et exécuter les images
- `kind` pour créer un cluster Kubernetes local
- `kubectl` pour interagir avec le cluster
- `make` pour lancer plus facilement les commandes du projet

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

### 2. Préparer le `.env`

```bash
cp service/.env.example service/.env
```

Valeur de départ recommandée :

```env
MODEL_VERSION=v1
```

### 3. Lancer les tests du service

```bash
make test
```

### 4. Lancer le service localement

```bash
make run
```

### 5. Préparer le cluster local

```bash
make kind-create
```

## Commandes utiles

- `make install`
- `make run`
- `make status`
- `make test`
- `make build-image`
- `make kind-create`
- `make kind-delete`
- `make apply-namespace`
- `make apply-services`
