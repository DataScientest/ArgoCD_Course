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

Commande importante :

```bash
kubectl argo rollouts get rollout fraud-rollout
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

Vous déployez `fraud-model:v2`.

Le rollout commence à `10 %`.

Vous observez :

- la latence
- le taux d'erreur
- les logs de version

Si tout reste sain, vous promouvez à `25 %`, puis à `50 %`, puis à `100 %`.

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
          image: fraud-scoring:v2
          ports:
            - containerPort: 8000
          env:
            - name: MODEL_VERSION
              value: v2
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
