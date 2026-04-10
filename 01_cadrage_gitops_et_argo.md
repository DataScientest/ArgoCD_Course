# Chapitre 1 : Cadrage GitOps et Argo

## Pourquoi ce chapitre compte

Avant de parler de déploiement progressif, il faut comprendre le décor.

Sinon, vous risquez de mélanger plusieurs outils qui n'ont pas exactement le même rôle.

Dans ce chapitre, vous allez construire une carte mentale simple.

Le but est de répondre à trois questions :

- qu'est-ce que la livraison logicielle cherche à faire
- qu'est-ce que GitOps ajoute à cette logique
- pourquoi **Argo CD** et **Argo Rollouts** ne font pas la même chose

## Le grand modèle mental

Imaginez un chantier.

- **Git** contient le plan attendu
- **Argo CD** vérifie que le chantier réel suit bien ce plan
- **Argo Rollouts** décide comment remplacer une ancienne version par une nouvelle sans prendre trop de risques

Autrement dit :

- **Argo CD** s'occupe de la **réconciliation**
- **Argo Rollouts** s'occupe de la **transition**

## Rappel très court : CI/CD

Vous avez déjà croisé ce vocabulaire, mais faisons un rappel très simple.

### CI

**CI** signifie **Continuous Integration**.

Cela correspond en général à :

- récupérer le code
- lancer les tests
- construire l'image

### CD

**CD** signifie **Continuous Delivery** ou **Continuous Deployment** selon le contexte.

Dans ce module, retenez surtout cette idée :

- on déploie ce qui a été validé

Cela veut dire qu'une image versionnée arrive dans un environnement cible.

## Introduction à GitOps

Les apprenants de ce module n'ont pas forcément une base GitOps solide.
Nous allons donc garder une explication courte et utile.

### L'idée centrale

Avec GitOps, le dépôt Git devient la **source de vérité**.

Cela veut dire :

- l'état désiré du système est écrit dans Git
- le cluster doit refléter cet état
- si le cluster diverge, un outil essaye de corriger l'écart

## État désiré et état réel

Ce vocabulaire est important.

- **État désiré** : ce que vous avez déclaré dans vos fichiers YAML
- **État réel** : ce qui tourne réellement dans Kubernetes

Le travail d'un outil GitOps est de réduire l'écart entre les deux.

## Argo CD vs Argo Rollouts

Cette distinction est essentielle.

### Argo CD

**Argo CD** sert à synchroniser le cluster avec ce qui est défini dans Git.

Son rôle est de :

- lire l'état désiré
- comparer avec le cluster
- appliquer les changements nécessaires

### Argo Rollouts

**Argo Rollouts** sert à piloter la manière dont une nouvelle version remplace l'ancienne.

Son rôle est de :

- organiser la transition entre versions
- gérer les pauses
- gérer la promotion
- gérer l'abort
- s'appuyer sur des métriques

### Résumé de la différence

- **Argo CD applique**
- **Argo Rollouts orchestre la transition**

## Pourquoi `kind` pour les labs

Le cluster de démonstration retenu est **`kind`**.

`kind` signifie **Kubernetes in Docker**.

L'idée est simple :

- on lance un cluster Kubernetes local
- on le crée vite
- on le supprime vite
- on garde un environnement reproductible

Pourquoi c'est un bon choix ici :

- peu de complexité supplémentaire
- proche d'un Kubernetes standard
- bien adapté à un lab local

## Schéma d'ensemble du module

Voici la vue d'ensemble à retenir :

```txt
Git -> Argo CD -> Rollout -> Ingress -> Service ML
                              |
                              -> Prometheus -> Grafana
```

Ce schéma veut dire :

- Git décrit l'état attendu
- Argo CD synchronise cet état
- Argo Rollouts gère le passage d'une version à l'autre
- Ingress contrôle la circulation du trafic
- Prometheus et Grafana donnent de la visibilité

## Exemple concret

Vous avez un service de scoring de fraude.

- `fraud-model:v1` est stable
- `fraud-model:v2` est candidate

Argo CD peut appliquer la nouvelle définition.
Mais Argo Rollouts décide si `v2` reçoit :

- aucun trafic réel
- 10 % du trafic
- 50 % du trafic
- ou 100 % du trafic

## Projet fil rouge du chapitre

À partir de ce chapitre, vous allez utiliser le dépôt `argocd-ml-fraud-template`.

Le but n'est pas seulement de lire le cours.
Le but est aussi de manipuler un projet que vous allez enrichir au fil du module.

Dans ce premier chapitre, il n'y a pas encore de stratégie de rollout à compléter.
Mais vous devez prendre en main la structure du dépôt.

### Ce que vous devez faire

1. ouvrez le dépôt `argocd-ml-fraud-template`
2. repérez les dossiers `service/`, `scripts/` et `k8s/`
3. ouvrez `service/app.py`
4. ouvrez `scripts/kind-config.yaml`
5. repérez les dossiers `k8s/ingress/`, `k8s/rollouts/` et `k8s/analysis/`

À ce stade, vous ne cherchez pas encore à tout exécuter.
Vous construisez surtout une carte mentale du projet.

### Ce que vous devez comprendre

- `service/` contient le service ML
- `scripts/` contient les briques de setup du lab
- `k8s/` contient les manifestes que vous allez compléter au fil des chapitres

### Exemple utile à lire tout de suite

Dans `service/app.py`, vous pouvez déjà repérer les endpoints du service :

```python
@app.post("/predict", response_model=FraudResponse)
def predict(payload: FraudRequest):
    ...


@app.get("/health")
def health():
    return {"status": "ok", "model_version": MODEL_VERSION}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

Ce que cela montre déjà :

- `/predict` sert la prédiction
- `/health` sert à vérifier que le service répond
- `/metrics` servira plus tard pour Prometheus

Vous n'avez pas encore besoin de modifier ce code.
Mais il est important de voir dès maintenant le service que vous allez faire évoluer.

## Erreurs fréquentes

### 1. Croire qu'Argo CD et Argo Rollouts sont deux noms pour la même chose

Pour éviter cette erreur :

- retenez qu'Argo CD gère l'état voulu
- retenez qu'Argo Rollouts gère la stratégie de remplacement

### 2. Penser qu'un déploiement Kubernetes standard suffit toujours

Pour éviter cette erreur :

- gardez en tête qu'un service ML peut être sain côté pods mais mauvais côté comportement
- comprenez qu'il faut observer la nouvelle version avant de la généraliser

## Résumé

- GitOps repose sur l'idée d'un état désiré stocké dans Git.
- Argo CD synchronise l'état du cluster avec Git.
- Argo Rollouts pilote la transition progressive entre versions.

## Pour la suite

Dans le prochain chapitre, vous allez découvrir pourquoi le progressive delivery est particulièrement important en MLOps, et vous allez définir clairement les stratégies `shadow`, `canary` et `blue-green`.
