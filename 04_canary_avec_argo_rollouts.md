# Chapitre 4 : Canary avec Argo Rollouts

## Préface

Dans le chapitre précédent, vous avez vu comment observer une nouvelle version avec un shadow deployment.

Vous savez maintenant :

- pourquoi le shadow est utile
- quel est le rôle de NGINX Ingress
- quelles sont les limites de cette stratégie

Nous allons maintenant passer à une stratégie plus engageante : le **canary**.

## Pourquoi ce chapitre compte

Le canary est souvent la stratégie la plus parlante pour apprendre le progressive delivery.

Pourquoi ?

Parce qu'il permet d'exposer une petite part de trafic réel à la nouvelle version.

Vous obtenez donc une validation plus proche de la réalité, tout en gardant le risque sous contrôle.

## La philosophie derrière

Imaginez que vous ouvrez une nouvelle caisse dans un magasin.

Au lieu d'y envoyer tous les clients d'un coup, vous commencez avec une petite file.

Si tout se passe bien, vous ouvrez davantage.
Sinon, vous arrêtez.

Le canary suit cette logique.

## De `Deployment` à `Rollout`

Jusqu'ici, beaucoup d'apprenants connaissent déjà l'objet `Deployment`.

Avec Argo Rollouts, l'objet clé devient `Rollout`.

Pourquoi ce changement est important :

- `Deployment` gère bien le remplacement des pods
- `Rollout` ajoute une stratégie de transition plus riche

## Ce qu'un `Rollout` apporte

Un objet `Rollout` permet notamment de définir :

- des étapes de progression
- des pauses
- des promotions manuelles ou automatiques
- des analyses basées sur des métriques

## Lire l'état d'un rollout

Une grande partie du travail consiste à savoir lire la situation réelle.

Avant d'utiliser les commandes `kubectl argo rollouts ...`, vous devez installer le plugin correspondant.

Si vous êtes sur Linux, vous pouvez utiliser :

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

Puis vérifiez l'installation :

```bash
kubectl-argo-rollouts version
```

Commande importante :

```bash
kubectl argo rollouts get rollout fraud-rollout -n fraud-detection
```

Cette commande permet de voir :

- la phase actuelle
- le pourcentage de trafic
- les pauses
- les ReplicaSets concernés
- les événements importants

## Déroulé d'un canary manuel

Dans ce module, le scénario canary manuel attendu est :

1. déploiement de `v2`
2. passage à `10 %`
3. pause
4. passage à `25 %`
5. pause
6. passage à `50 %`
7. pause
8. passage à `100 %`

## Pourquoi les pauses sont importantes

Une pause n'est pas un blocage inutile.

Elle sert à :

- observer les métriques
- vérifier la stabilité
- limiter le blast radius, c'est-à-dire la zone d'impact potentielle

## Promotion manuelle

La promotion manuelle consiste à dire :

"les signaux sont suffisamment bons, nous pouvons passer à l'étape suivante".

Cela permet d'éviter une montée trop rapide du risque.

## Exemple concret

Dans une démonstration canary propre, on ne démarre pas directement avec `v2`.

On procède en deux temps :

1. on installe d'abord le rollout avec `v1`
2. puis on met à jour le rollout vers `v2`

Le canary commence alors à partir d'une vraie base stable.

## Livrables attendus du chapitre

- un YAML `Rollout` simple
- un scénario de promotion manuelle

Dans le dépôt du projet, le fichier `k8s/rollouts/canary-rollout.yaml` contient déjà un début de stratégie.

Mais les étapes du canary ne sont pas encore complètes.

Vous avez actuellement ceci :

```yaml
steps:
  - setWeight: 10
  - pause: {}
```

Votre objectif est d'obtenir la progression suivante :

- `10 %`
- pause
- `25 %`
- pause
- `50 %`
- pause
- `100 %`

Essayez de compléter le YAML vous-même avant d'ouvrir le bloc suivant.

%%SOLUTION%%

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: fraud-rollout
  namespace: fraud-detection
spec:
  replicas: 3
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: fraud-scoring
  template:
    metadata:
      labels:
        app: fraud-scoring
    spec:
      containers:
        - name: fraud-api
          image: fraud-scoring:v1
          ports:
            - containerPort: 8000
          env:
            - name: MODEL_VERSION
              value: v1
  strategy:
    canary:
      stableService: fraud-stable
      canaryService: fraud-canary
      steps:
        - setWeight: 10
        - pause: {}
        - setWeight: 25
        - pause: {}
        - setWeight: 50
        - pause: {}
        - setWeight: 100
```

%%SOLUTION%%

Ce que vous devez retenir :

- chaque `setWeight` définit une nouvelle part de trafic
- chaque `pause` crée un point d'observation
- le rollout devient plus prudent et plus lisible qu'un simple `Deployment`

## Mettre en place et tester le canary

Modifier le fichier YAML ne suffit pas.
Il faut aussi lancer le rollout et observer son comportement dans l'infrastructure.

### 1. Nettoyer ce qui vient du shadow

Le chapitre précédent utilisait deux `Deployment` séparés pour `v1` et `v2`.

Pour passer proprement au canary avec Argo Rollouts, commencez par retirer cette mise en place précédente :

```bash
make cleanup-shadow
```

### 2. Appliquer le rollout canary

```bash
make apply-canary
```

Puis vérifiez qu'il existe bien :

```bash
kubectl get rollouts -n fraud-detection
kubectl argo rollouts get rollout fraud-rollout -n fraud-detection
```

À ce stade, le rollout doit représenter votre version stable `v1`.

### 3. Mettre à jour le rollout vers `v2`

Le canary commence vraiment quand vous faites évoluer la version stable vers la nouvelle version candidate.

Pour cela, appliquez la mise à jour vers `v2` :

```bash
make update-canary-to-v2
kubectl argo rollouts get rollout fraud-rollout -n fraud-detection
```

Ici, le projet utilise une commande `kubectl patch`.

Pourquoi ?

- un fichier YAML partiel ne suffit pas avec `kubectl apply`
- l'objet `Rollout` doit rester valide dans son ensemble
- `kubectl patch` est mieux adapté pour modifier uniquement l'image et la variable `MODEL_VERSION`

Cette fois, Argo Rollouts doit conserver `v1` comme base stable, puis introduire `v2` progressivement.

### 4. Observer les pods créés

```bash
kubectl get pods -n fraud-detection -w
```

L'idée ici est de voir le rollout créer et gérer ses ReplicaSets à votre place.

À ce moment-là, il ne faut pas seulement regarder le nombre de pods.
Il faut surtout comprendre **pourquoi** plusieurs pods coexistent en même temps.

Dans un rollout canary, Argo Rollouts ne supprime pas immédiatement l'ancienne version.
Il garde :

- une partie des pods de la version stable
- puis il ajoute des pods de la nouvelle version

Cela permet d'avoir une vraie phase de transition.

Quand vous observez les pods, vous pouvez donc voir deux familles de pods :

- des pods issus de l'ancienne révision
- des pods issus de la nouvelle révision

Le point important à comprendre est le suivant :

- l'ancienne révision représente la base stable
- la nouvelle révision représente la version candidate

Autrement dit, tant que le rollout n'est pas terminé, il est normal de voir les deux coexister.

### Ce qu'il faut lire concrètement

Quand vous utilisez :

```bash
kubectl argo rollouts get rollout fraud-rollout -n fraud-detection
```

vous verrez souvent apparaître :

- une révision marquée `stable`
- une révision marquée `canary`

Et quand vous utilisez :

```bash
kubectl get pods -n fraud-detection
```

vous voyez les pods qui appartiennent à ces révisions.

Ce que cela signifie :

- si plusieurs pods appartiennent à la révision stable, alors `v1` reste la base principale
- si un plus petit nombre de pods appartient à la révision canary, alors `v2` est encore en phase d'introduction

### Pourquoi le nombre de pods peut surprendre

Il est fréquent de voir plus de pods que le nombre final attendu pendant la transition.

Par exemple, si le rollout vise `3` replicas au final, vous pouvez quand même observer temporairement `4` pods :

- `3` pods stables
- `1` pod canary

Cela arrive parce qu'Argo Rollouts cherche à introduire la nouvelle version sans casser immédiatement l'ancienne.

Donc ici, voir plus de pods que prévu n'est pas forcément un problème.
C'est souvent le signe qu'une transition progressive est en cours.

### 5. Tester la version stable et la version canary

Dans ce chapitre, le plus simple est de tester directement les deux services.

Dans un premier terminal :

```bash
kubectl port-forward -n fraud-detection svc/fraud-stable 8082:80
```

Dans un second terminal :

```bash
kubectl port-forward -n fraud-detection svc/fraud-canary 8083:80
```

Puis envoyez une requête à chaque service.

Version stable :

```bash
curl -s -X POST http://127.0.0.1:8082/predict \
  -H "Content-Type: application/json" \
  -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
```

Version canary :

```bash
curl -s -X POST http://127.0.0.1:8083/predict \
  -H "Content-Type: application/json" \
  -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
```

Ce que vous devez observer :

- le service stable doit répondre avec `model_version: "v1"`
- le service canary doit répondre avec `model_version: "v2"`


### 6. Promouvoir manuellement le rollout

Une fois l'état observé, vous pouvez passer à l'étape suivante :

```bash
kubectl argo rollouts promote fraud-rollout -n fraud-detection
kubectl argo rollouts get rollout fraud-rollout -n fraud-detection
```

Vous pouvez répéter cette commande à chaque pause pour faire progresser le canary.

### 7. Ce que ce test valide réellement

Dans ce chapitre, le test du canary valide surtout :

- que le rollout est bien pris en charge par Argo Rollouts
- que les pauses sont visibles
- que les services stable et canary pointent vers les bonnes versions
- que la promotion manuelle fait avancer l'état du rollout

## Erreurs fréquentes

### 1. Promouvoir trop vite

Pour éviter cette erreur :

- utilisez les pauses comme de vrais points de décision
- observez avant de promouvoir

### 2. Lire seulement le nombre de pods et pas l'état global du rollout

Pour éviter cette erreur :

- utilisez `kubectl argo rollouts get rollout`
- regardez la phase, les événements et les ReplicaSets

## Résumé

- Le canary expose progressivement une nouvelle version à du trafic réel.
- L'objet `Rollout` apporte une logique plus riche qu'un `Deployment` standard.
- Les pauses et les promotions servent à limiter le risque.

## Pour la suite

Dans le prochain chapitre, vous allez découvrir une autre stratégie standard : le **blue-green**, avec sa logique de bascule nette entre deux environnements.
