# ArgoCD / Argo Rollouts — Repo Template

Ce dépôt est le **projet fil rouge** du module.

Vous allez l'utiliser pendant tout le cours.
Le principe est simple :

- vous partez d'une base incomplète
- vous ajoutez des morceaux au fur et à mesure
- vous testez ce que vous avez ajouté

À la fin, vous aurez un service ML de scoring de fraude capable de montrer :

- une version `v1`
- une version `v2`
- une version `v2-buggy`
- un scénario de shadow
- un canary avec Argo Rollouts
- un blue-green
- une analyse automatisée avec Prometheus

## Structure du dépôt

```txt
argocd-ml-fraud-template/
├── README.md
├── Makefile
├── service/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── tests/
├── scripts/
│   ├── kind-config.yaml
│   ├── install-rollouts.sh
│   ├── install-ingress.sh
│   └── install-monitoring.sh
└── k8s/
    ├── namespace.yaml
    ├── services/
    ├── ingress/
    ├── rollouts/
    └── analysis/
```

## Ce que vous pouvez déjà tester

Même si le dépôt est incomplet, vous pouvez déjà tester le service ML localement.

### Installer les dépendances

```bash
make install
```

### Lancer le service

```bash
make run
```

### Lancer les tests automatisés du service

```bash
make test
```

Ces tests vérifient déjà :

- `/health`
- `/predict`
- `/metrics`

Cela vous permet de vérifier que le service reste cohérent pendant que vous avancez dans le module.

## Ce que vous compléterez pendant le cours

### Chapitre 3

Vous compléterez :

- `k8s/ingress/shadow-ingress.yaml`

### Chapitre 4

Vous compléterez :

- `k8s/rollouts/canary-rollout.yaml`

### Chapitre 5

Vous compléterez :

- `k8s/rollouts/bluegreen-rollout.yaml`

### Chapitre 6

Vous compléterez :

- `k8s/analysis/prometheus-analysis-template.yaml`

## Makefile

Quelques commandes utiles sont déjà disponibles :

- `make install`
- `make run`
- `make test`
- `make build-image`
- `make kind-create`
- `make kind-delete`
- `make apply-namespace`
- `make apply-services`

## Important

Ce dépôt est un **template pédagogique**.

Cela veut dire que certains fichiers contiennent volontairement :

- des `TODO`
- des valeurs à remplacer
- des étapes incomplètes

Vous n'êtes pas censé tout exécuter parfaitement dès le début.
Le dépôt est conçu pour évoluer avec le cours.
