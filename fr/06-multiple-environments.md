# Chapitre 6 — Gérer plusieurs environnements

---

## La vraie plateforme MLOps

Parlons de ce à quoi ressemble une vraie plateforme ML en production.

Vous avez un modèle de détection de fraude. Mais vous n'avez pas juste *un* déploiement — vous avez tout un pipeline de promotion :

```
dev  →  staging  →  production
```

- En **dev**, les data scientists expérimentent en permanence. Les modèles sont reconstruits plusieurs fois par jour. On veut du sync auto, des itérations rapides, et on ne se préoccupe pas de la stabilité.
- En **staging**, on valide le modèle contre un échantillon représentatif du trafic de production. On fait des tests A/B et on compare les métriques au modèle actuellement en prod. On veut du contrôle — sync manuel avant la promotion.
- En **production**, de l'argent réel est en jeu. Un modèle de détection de fraude dégradé signifie des fraudes manquées ou des faux positifs. On veut une approbation humaine, une capacité de rollback, et des traces d'audit strictes.

Chaque environnement a besoin d'une configuration différente : des nombres de réplicas différents, des limites de ressources différentes, des variables d'environnement différentes (base de données staging vs production), des seuils différents.

Comment gérer tout ça proprement dans Git sans copier-coller des fichiers partout ?

---

## Approche 1 : un dossier par environnement

L'approche la plus simple. Votre dépôt ressemble à ça :

```
ml-platform/
├── fraud-detection/
│   ├── dev/
│   │   └── deployment.yaml     # 1 réplica, 1Go mémoire, DB dev
│   ├── staging/
│   │   └── deployment.yaml     # 2 réplicas, 2Go mémoire, DB staging
│   └── production/
│       └── deployment.yaml     # 5 réplicas, 4Go mémoire, DB prod
```

Une Application ArgoCD par environnement :

```bash
argocd app create fraud-detection-dev \
  --repo https://github.com/votre-org/ml-platform \
  --path fraud-detection/dev \
  --dest-namespace fraud-detection-dev \
  --sync-policy automated

argocd app create fraud-detection-staging \
  --repo https://github.com/votre-org/ml-platform \
  --path fraud-detection/staging \
  --dest-namespace fraud-detection-staging

argocd app create fraud-detection-production \
  --repo https://github.com/votre-org/ml-platform \
  --path fraud-detection/production \
  --dest-namespace fraud-detection-production
```

Notez : le dev a `--sync-policy automated`, staging et production non — ils nécessitent un sync manuel.

**Avantages :** Simple. Facile à comprendre. Chaque environnement est entièrement explicite.

**Inconvénients :** Beaucoup de duplication de YAML. Si vous changez le port du conteneur du modèle, vous mettez à jour trois fichiers. Facile d'en oublier un.

---

## Approche 2 : Kustomize — base + overlays (recommandé pour le MLOps)

**Kustomize** est un outil natif Kubernetes qui vous permet de définir une configuration de base une seule fois et d'appliquer des patches spécifiques par environnement.

C'est la bonne approche pour les plateformes MLOps car :
- Vos modèles partagent la même structure entre les environnements
- Seule une poignée de valeurs diffèrent par environnement (tag d'image, réplicas, ressources, variables d'env)
- Vous voulez un seul endroit pour changer le port API du modèle et que ça s'applique partout

### Structure du dépôt avec Kustomize

```
ml-platform/
├── base/
│   ├── deployment.yaml       # config partagée pour tous les envs
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── production/
        └── kustomization.yaml
```

### Le déploiement de base

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraud-detection-api
spec:
  replicas: 1                       # par défaut — sera patché par env
  selector:
    matchLabels:
      app: fraud-detection
  template:
    spec:
      containers:
      - name: inference-server
        image: mon-registry/fraud-model:latest   # sera patché par la CI par env
        resources:
          requests:
            memory: "1Gi"           # par défaut — patché par env
            cpu: "500m"
        env:
        - name: MODEL_THRESHOLD
          value: "0.5"              # seuil par défaut — patché par env
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
```

```yaml
# base/kustomization.yaml
resources:
  - deployment.yaml
  - service.yaml
```

### L'overlay production

```yaml
# overlays/production/kustomization.yaml
bases:
  - ../../base

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 5                    # 5 réplicas en production
    target:
      kind: Deployment
      name: fraud-detection-api

  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "4Gi"               # plus de mémoire pour la charge de production
    target:
      kind: Deployment
      name: fraud-detection-api

images:
  - name: mon-registry/fraud-model
    newTag: v3.2                   # la CI met à jour ce tag par environnement
```

### L'overlay dev

```yaml
# overlays/dev/kustomization.yaml
bases:
  - ../../base

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: fraud-detection-api

images:
  - name: mon-registry/fraud-model
    newTag: v3.3-dev              # dernier build instable
```

ArgoCD détecte Kustomize automatiquement. Il suffit de pointer chaque Application vers le dossier de l'overlay :

```bash
argocd app create fraud-detection-production \
  --repo https://github.com/votre-org/ml-platform \
  --path overlays/production \
  --dest-namespace fraud-detection-production
```

---

## Le flux de promotion de modèle MLOps

Avec cette structure, promouvoir un modèle de staging vers production devient une simple opération Git :

```bash
# Dans votre pipeline CI ou manuellement :
# 1. Staging fait tourner v3.3 avec succès depuis 24 heures
# 2. Les métriques sont bonnes : rappel fraude 94%, précision 88%
# 3. Promotion vers la production :

# Mettre à jour l'overlay production dans Git
sed -i 's/newTag: v3.2/newTag: v3.3/' overlays/production/kustomization.yaml
git add overlays/production/kustomization.yaml
git commit -m "chore: promouvoir fraud-model v3.3 en production"
git push

# ArgoCD détecte le changement et affiche OutOfSync sur fraud-detection-production
# Un humain vérifie et clique sur Sync — ou votre CI appelle :
argocd app sync fraud-detection-production
```

C'est entièrement traçable : chaque promotion est un commit avec un horodatage, un auteur, et un diff.

---

## Ne jamais stocker des secrets dans Git

En tant qu'ingénieurs MLOps, on manipule des valeurs sensibles en permanence : identifiants de base de données, clés API pour les feature stores, tokens de registre de modèles.

**Ne mettez jamais ces valeurs dans Git**, même dans un dépôt privé. Utilisez :
- **Sealed Secrets** — chiffre les secrets pour qu'ils puissent être stockés en toute sécurité dans Git
- **External Secrets Operator** — synchronise les secrets depuis AWS Secrets Manager, Vault, GCP Secret Manager, etc.
- Des **Kubernetes Secrets** gérés hors de Git et référencés par nom dans vos déploiements

---

## Les erreurs fréquentes à ce stade

- **Déployer plusieurs environnements dans le même namespace.** Si dev et staging déploient tous les deux dans `default`, ils vont s'écraser mutuellement. Utilisez toujours des namespaces dédiés.
- **Oublier de mettre à jour tous les overlays quand on change une valeur partagée.** Avec Kustomize, la base gère ça — changez une fois, s'applique partout. Avec les dossiers, vous devez mettre à jour les trois manuellement.
- **Mettre des secrets dans Git pour "gagner du temps".** C'est un risque de sécurité sérieux. Le coût d'installation d'une gestion correcte des secrets en vaut la peine.

---

## Résumé

- Chaque environnement a sa propre Application ArgoCD pointant vers un chemin ou un overlay différent.
- L'**approche par dossiers** est simple mais crée de la duplication.
- **Kustomize** permet de définir la config une fois et de la patcher par environnement — idéal pour les plateformes ML avec plusieurs modèles.
- Promotion de modèle = mettre à jour un tag Git → ArgoCD détecte la différence → sync → déployé.
- Ne jamais stocker des secrets dans Git.

---

## La suite

On sait déployer et promouvoir des modèles entre environnements. Dans le prochain chapitre, on va aller plus loin dans les stratégies de déploiement — canary, blue/green — qui sont essentielles en MLOps pour tester en toute sécurité de nouvelles versions de modèles en production.
