# ArgoCD_Course

Ce dépôt est le projet fil rouge du module ArgoCD.

Le use case reste dans un contexte MLOps :

**une API de priorisation de tickets de support client**.

## Objectif du projet

Le but n'est pas de travailler des stratégies de déploiement progressif.
Le but est de montrer comment **ArgoCD** suit un dépôt Git et maintient un cluster Kubernetes dans l'état attendu.

Vous allez donc utiliser ce projet pour :

- déclarer une première `Application`
- synchroniser le cluster depuis Git
- observer une dérive
- tester `self-heal` et `prune`
- comprendre une organisation GitOps plus propre pour un service ML

## Structure du dépôt

```txt
ArgoCD_Course/
├── README.md
├── Makefile
├── .python-version
├── service/
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── .env.example
│   └── tests/
├── scripts/
│   └── kind-config.yaml
└── k8s/
    ├── base/
    ├── overlays/
    │   ├── dev/
    │   └── prod/
    └── argocd/
```

## Service ML

Le service expose :

- `POST /predict`
- `GET /health`
- `GET /metrics`

Le comportement du service est volontairement simple.
L'accent du module porte sur GitOps et ArgoCD, pas sur le modèle lui-même.

Dans ce module ArgoCD, nous ne nous appuyons pas sur un `Ingress` pour valider le service.
Le test de l'application se fait plus simplement via un `port-forward` sur le `Service`, afin de garder le lab léger et plus robuste localement.

## Pré-requis

- `git`
- `uv`
- `docker`
- `kind`
- `kubectl`
- `make`

## Premiers pas

### Installer les dépendances locales

```bash
make install
```

### Préparer le fichier `.env`

```bash
cp service/.env.example service/.env
```

### Vérifier l'état du service

```bash
make status
```

### Lancer le service localement

```bash
make run
```

### Créer le cluster local

```bash
make kind-create
```

### Construire et charger l'image du service dans `kind`

Avant de laisser ArgoCD déployer l'application, il faut que le cluster puisse trouver l'image locale.

```bash
make build-v1
make load-v1
```

Sinon, le `Deployment` sera bien créé, mais les pods resteront en `ImagePullBackOff`.

## Ce que vous manipulerez dans le cours

### Chapitre 2

- installation d'ArgoCD
- construction et chargement de l'image applicative
- création d'une `Application`

### Tester l'application une fois synchronisée

Quand ArgoCD a appliqué le `Deployment` et le `Service`, vous pouvez tester l'application avec :

```bash
kubectl port-forward -n support-priority svc/support-priority-api 8082:80
```

Puis dans un autre terminal :

```bash
curl -s http://127.0.0.1:8082/health
```

### Chapitre 3

- modification manuelle d'une ressource
- observation d'un drift
- correction via `self-heal`

### Chapitre 4

- lecture des dossiers `base/` et `overlays/`
- séparation `dev` / `prod`
- introduction à `AppProject`
