# ArgoCD / Argo Rollouts — Repo Template

Ce dépôt est le **projet fil rouge** du module.

Le but est simple :

- vous partez de cette version incomplète
- vous avancez chapitre après chapitre
- vous complétez progressivement le service et les manifests Kubernetes

À la fin du module, vous aurez un service ML de scoring de fraude capable de montrer :

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
├── service/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
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

## Progression conseillée

### Chapitres 1 et 2

Objectif : comprendre le use case et lancer le cluster local.

À faire :

- lire `scripts/kind-config.yaml`
- créer le cluster `kind`
- lire les manifests Kubernetes du dossier `k8s/`

### Chapitre 3

Objectif : compléter le shadow.

À faire :

- compléter l'Ingress de shadow
- vérifier que `v1` sert la réponse
- vérifier que `v2` reçoit le trafic miroir

### Chapitre 4

Objectif : compléter le canary.

À faire :

- compléter le `Rollout` canary
- ajouter les étapes `10 -> 25 -> 50 -> 100`

### Chapitre 5

Objectif : compléter le blue-green.

À faire :

- compléter `activeService`
- compléter `previewService`

### Chapitre 6

Objectif : compléter l'analyse automatisée.

À faire :

- compléter l'`AnalysisTemplate`
- brancher les requêtes Prometheus
- définir `successCondition` et `failureCondition`

## Important

Ce dépôt est un **template pédagogique**.

Cela veut dire que certains fichiers contiennent volontairement :

- des `TODO`
- des valeurs à remplacer
- des étapes incomplètes

Une version terminée existe à côté dans le dépôt `argocd-ml-fraud-complete`.

Ce dépôt terminé sert de référence côté formateur.
Les apprenants travaillent, eux, à partir du template et des solutions données dans le cours.
