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
- `uv` pour gérer l'environnement Python, installer Python `3.11` si besoin, et installer les dépendances
- `docker` pour construire et exécuter les images
- `kind` pour créer un cluster Kubernetes local
- `kubectl` pour interagir avec le cluster
- `make` pour lancer plus facilement les commandes du projet

Le projet utilise Python `3.11`.
Si votre machine a une version plus ancienne de Python, ce n'est pas bloquant : `uv` pourra créer l'environnement avec Python `3.11` automatiquement.

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

### 7. Appliquer la base du projet

```bash
make apply-namespace
make apply-services
```

### 8. Construire et charger les deux versions pour le shadow

```bash
make build-v1
make build-v2
make load-v1
make load-v2
```

### 9. Déployer les deux versions dans le cluster

```bash
make apply-shadow-base
make apply-shadow-ingress
```

### 10. Envoyer une première requête de test

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
