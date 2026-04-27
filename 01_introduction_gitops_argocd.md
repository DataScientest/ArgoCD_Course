# Chapitre 1 : Comprendre GitOps et le rôle d'ArgoCD

## Introduction : Pourquoi Git ne suffit plus tout seul

Dans un projet Kubernetes débutant, il est fréquent de fonctionner ainsi :

1. on écrit un manifest YAML
2. on lance `kubectl apply`
3. on vérifie que les pods tournent

Au départ, cela paraît suffisant.

Mais dès que le projet grandit, les problèmes arrivent vite :

- une personne modifie le cluster à la main
- une autre croit que Git contient encore la vérité
- les deux états divergent
- personne ne sait plus exactement ce qui est réellement déployé

C'est précisément cette situation que GitOps cherche à éviter.

## Le contexte du module

Dans ce module, nous allons travailler avec un projet concret :

**une API de priorisation de tickets de support client**.

L'application représente un petit service ML qui attribue un score de priorité à une demande entrante.

Elle expose :

- `POST /predict`
- `GET /health`
- `GET /metrics`

Le dépôt de travail du module est :

[`ArgoCD_Course`](https://github.com/DataScientest/ArgoCD_Course.git)

## Préparation rapide de l'environnement

Avant d'aller plus loin, assurez-vous d'avoir les outils nécessaires :

- `git`
- `uv`
- `docker`
- `kind`
- `kubectl`
- `make`

Ici, nous considérons que vous connaissez déjà les bases de Kubernetes. Nous allons donc pouvoir rester centrés sur GitOps et ArgoCD.

## GitOps, en termes simples

GitOps consiste à considérer Git comme la **source de vérité** du système.

Cela veut dire que :

- ce que vous attendez du cluster est écrit dans Git
- le cluster doit refléter cet état
- un outil compare en permanence les deux

Le point important est que Git n'est plus un simple dossier de sauvegarde.
Il devient la référence officielle.

## État désiré et état réel

Ces deux notions sont fondamentales.

### État désiré

C'est ce que vous avez déclaré dans Git.

Par exemple :

- un `Deployment`
- un `Service`
- une `Ingress`

### État réel

C'est ce qui tourne réellement dans le cluster.

Quand ces deux états divergent, on parle de **drift**.

## Le rôle d'ArgoCD

ArgoCD observe un dépôt Git et un cluster Kubernetes.

Son rôle est de :

- lire l'état désiré
- comparer avec l'état réel
- afficher les écarts
- synchroniser le cluster
- parfois corriger automatiquement une dérive

## Ce qu'ArgoCD n'est pas

Pour éviter les confusions, il faut aussi dire ce qu'ArgoCD n'est pas.

ArgoCD n'est pas :

- un outil d'entraînement de modèle
- un moteur de monitoring
- un système d'expérimentation
- un outil de progressive delivery avancé

Dans ce module, son rôle est clair :

**garder le cluster aligné avec Git**.

## Le grand modèle mental

Imaginez que votre dépôt Git est le plan officiel d'un bâtiment.

Le cluster, lui, est le bâtiment réellement construit.

ArgoCD joue alors le rôle d'un inspecteur :

- il lit le plan
- il regarde le bâtiment
- il signale ce qui ne correspond pas
- il peut parfois remettre le bâtiment en conformité

## Lire le dépôt du projet

Avant d'installer quoi que ce soit, prenez quelques minutes pour parcourir le dépôt `ArgoCD_Course`.

Regardez en particulier :

- `service/`
- `k8s/base/`
- `k8s/overlays/`
- `k8s/argocd/`
- `Makefile`

Le but est de comprendre la logique générale :

- `service/` contient l'application ML
- `k8s/base/` contient les ressources communes
- `k8s/overlays/` contient les variantes par environnement
- `k8s/argocd/` contient les objets ArgoCD

## Une première lecture utile dans `service/`

Dans `service/app.py`, vous pouvez déjà repérer les endpoints qui seront déployés plus tard.

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

Même si le nom des classes dans le code peut encore être retravaillé plus tard, l'important ici est de comprendre que vous avez déjà :

- une petite API exploitable
- un endpoint de santé
- un endpoint de métriques

Autrement dit, le support du module n'est pas abstrait.
Il s'appuie sur une vraie petite application de service ML.

## Erreurs fréquentes

### 1. Penser que GitOps veut seulement dire “mettre ses YAML dans Git”

Pour éviter cette erreur :

- retenez que GitOps implique aussi une boucle d'observation et de synchronisation

### 2. Penser qu'ArgoCD remplace toute la chaîne MLOps

Pour éviter cette erreur :

- voyez ArgoCD comme une brique de déploiement et de cohérence, pas comme une solution à tout

## Résumé

- GitOps fait de Git la source de vérité.
- ArgoCD compare l'état désiré et l'état réel.
- Le dépôt `ArgoCD_Course` servira de support concret pendant tout le module.

## Pour la suite

Dans le prochain chapitre, vous allez installer ArgoCD sur un cluster léger, créer votre première `Application`, puis observer concrètement la synchronisation entre Git et Kubernetes.
