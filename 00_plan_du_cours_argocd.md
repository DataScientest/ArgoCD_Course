# Module A — Progressive Delivery MLOps avec Argo sur Kubernetes

## Pourquoi ce module compte

Déployer un service ML n'est pas seulement une question de conteneur qui démarre.

Une nouvelle version peut être :

- correcte côté infrastructure
- mais mauvaise côté comportement
- plus lente
- plus instable
- plus risquée pour les utilisateurs

Ce module vous apprend donc à déployer **progressivement**.

Vous allez voir comment :

- exposer d'abord une nouvelle version sans risque
- donner ensuite une petite part de trafic réel
- observer les métriques
- promouvoir ou interrompre le déploiement

## Fil rouge du module

Tout le module repose sur un même use case :

**un service de scoring de fraude en temps réel**.

Le service est construit avec :

- `FastAPI`
- un modèle `scikit-learn`

Endpoints minimum :

- `POST /predict`
- `GET /health`
- `GET /metrics`

Versions utilisées dans le module :

- `v1` : version stable
- `v2` : nouvelle version candidate
- `v2-buggy` : version volontairement dégradée

## Dépôts fil rouge du module

Le module s'appuie maintenant sur deux dépôts complémentaires :

- `argocd-ml-fraud-template`
- `argocd-ml-fraud-complete`

Leur rôle est différent.

### `argocd-ml-fraud-template`

Ce dépôt est destiné aux apprenants.

Vous partez de cette base au début du module.
Puis vous la complétez au fur et à mesure des chapitres.

Lien GitHub du template :

`https://github.com/<organisation>/argocd-ml-fraud-template`

Vous y trouverez volontairement :

- des fichiers incomplets
- des `TODO`
- des manifestes à terminer

### `argocd-ml-fraud-complete`

Ce dépôt correspond à une version terminée.

Il sert côté formateur :

- de correction
- de support de démonstration
- de référence fonctionnelle complète

## Comment utiliser ces dépôts pendant le cours

La logique pédagogique du module est la suivante :

- le cours explique une notion
- puis il vous demande de l'implémenter dans le repo template
- quand une correction de l'exercice est utile, elle est masquée dans un bloc `%%SOLUTION%%`

## Stack du module

La stack reste volontairement simple :

- `kind`
- `Argo Rollouts`
- `kubectl argo rollouts`
- `ingress-nginx`
- `Prometheus`
- `Grafana`
- service ML `FastAPI`

## Répartition des chapitres

### Chapitre 1 — Cadrage GitOps et Argo

Vous apprendrez :

- le minimum sur CI/CD
- le minimum sur GitOps
- la différence entre **Argo CD** et **Argo Rollouts**
- le rôle de `kind` dans les labs
- la structure du repo fil rouge

Fichier : `01_cadrage_gitops_et_argo.md`

### Chapitre 2 — Fondations du progressive delivery pour le ML

Vous apprendrez :

- pourquoi `RollingUpdate` ne suffit pas
- les notions de `shadow`, `canary`, `blue-green`, `promotion`, `abort`, `rollback`
- pourquoi un service ML demande une validation plus prudente
- comment lire le service ML du repo template

Fichier : `02_fondations_progressive_delivery_ml.md`

### Chapitre 3 — Shadow avec NGINX Ingress

Vous apprendrez :

- ce qu'est un shadow deployment
- comment le trafic miroir fonctionne
- ce qu'il faut observer sur un challenger
- les limites de cette stratégie
- comment compléter l'Ingress de shadow dans le repo template

Fichier : `03_shadow_avec_nginx.md`

### Chapitre 4 — Canary avec Argo Rollouts

Vous apprendrez :

- à passer de `Deployment` à `Rollout`
- à lire l'état d'un rollout
- à exécuter un canary manuel
- à promouvoir ou interrompre un rollout
- comment compléter le `Rollout` canary du repo template

Fichier : `04_canary_avec_argo_rollouts.md`

### Chapitre 5 — Blue-Green avec Argo Rollouts

Vous apprendrez :

- le principe du blue-green
- la différence avec le canary
- quand préférer l'une ou l'autre stratégie
- comment basculer rapidement entre deux versions
- comment compléter le `Rollout` blue-green du repo template

Fichier : `05_blue_green_avec_argo_rollouts.md`

### Chapitre 6 — Analysis automatisée avec Prometheus et Grafana

Vous apprendrez :

- pourquoi automatiser une décision de promotion
- comment fonctionne `AnalysisTemplate`
- quelles métriques utiliser
- comment déclencher un abort automatique
- comment compléter l'`AnalysisTemplate` du repo template

Fichier : `06_analysis_automatisee_prometheus_grafana.md`

### Chapitre 7 — Diagnostic et bonnes pratiques

Vous apprendrez :

- à diagnostiquer un rollout bloqué
- à distinguer un problème d'analyse, d'Ingress ou d'application
- à définir de bonnes pratiques MLOps pour le déploiement progressif

Fichier : `07_bonnes_pratiques_et_diagnostic.md`

## Ce que vous saurez faire à la fin

- expliquer la différence entre `RollingUpdate`, `shadow`, `canary` et `blue-green`
- expliquer la différence entre **Argo CD** et **Argo Rollouts**
- lire un objet `Rollout`
- utiliser `kubectl argo rollouts`
- relier un rollout à des métriques techniques
- décider quand promouvoir, interrompre ou revenir en arrière
