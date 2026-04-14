# Chapitre 1 : Cadrage GitOps et Argo

## Pourquoi ce chapitre compte

Avant de parler de déploiement progressif, il faut comprendre le décor.

Sinon, vous risquez de mélanger plusieurs outils qui n'ont pas exactement le même rôle.

Dans ce chapitre, vous allez construire une carte mentale simple.

Le but est de répondre à trois questions :

- qu'est-ce que la livraison logicielle cherche à faire
- qu'est-ce que GitOps ajoute à cette logique
- pourquoi **Argo CD** et **Argo Rollouts** ne font pas la même chose

## La philosophie derrière

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

À partir de ce chapitre, vous allez travailler avec le dépôt du projet: [ArgoCD_Course](https://github.com/DataScientest/ArgoCD_Course.git).

Avant d'aller plus loin, vérifiez que vous avez bien installé les outils suivants :

- `git`
- `uv` -> https://github.com/astral-sh/uv.git
- `docker`
- `kind` -> 
- `kubectl` -> 
- `make`

Vous utiliserez aussi plus tard :

- le plugin `kubectl argo rollouts`

À ce stade, vous n'avez pas encore besoin d'avoir tout configuré dans Kubernetes.
Mais ces outils doivent être présents pour pouvoir suivre le projet dans de bonnes conditions.

Si vous êtes sur Linux, voici deux commandes utiles pour installer `kubectl` et `kind`.

### Installer `kubectl`

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Installer `kind`

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Vérifier l'installation

```bash
kubectl version --client
kind version
```

Pour le moment, vous n'avez rien à compléter.
Le plus utile est de parcourir calmement sa structure.

Ouvrez :

- `service/app.py`
- `service/.env.example`
- `scripts/kind-config.yaml`
- les dossiers `k8s/ingress/`, `k8s/rollouts/` et `k8s/analysis/`

Le but est surtout de comprendre la place de chaque partie :

- `service/` contient le service ML
- `service/.env.example` prépare déjà une configuration locale simple
- `scripts/` contient les scripts de setup du lab
- `k8s/` contient les manifestes que vous allez compléter au fil du module

Voici par exemple un extrait utile à lire dès maintenant dans `service/app.py` :

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

Vous pouvez aussi repérer dès maintenant que le service lit sa version depuis l'environnement.

Dans le dépôt du projet, une bonne pratique simple est déjà en place :

```bash
cp service/.env.example service/.env
```

Puis dans `service/.env` :

```env
MODEL_VERSION=v1
```

Cette variable sera utile tout au long du module pour faire vivre plusieurs versions du service.

Vous n'avez pas encore besoin de modifier ce code.
Mais il est important de voir dès maintenant le service que vous allez faire évoluer pendant tout le module.

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
