# Chapitre 2 : Fondations du Progressive Delivery pour le ML

## Préface

Dans le chapitre précédent, vous avez vu le cadre général.

Vous savez maintenant :

- ce qu'est GitOps
- la différence entre Argo CD et Argo Rollouts
- pourquoi `kind` est utilisé pour les labs

Nous allons maintenant entrer dans le coeur du sujet : le **progressive delivery**.

## Pourquoi ce chapitre compte

Quand vous déployez une nouvelle version d'un service ML, le vrai risque n'est pas seulement technique.

Le service peut :

- démarrer correctement
- répondre sans erreur HTTP
- mais produire un comportement moins bon que la version précédente

Dans ce chapitre, vous allez comprendre pourquoi il faut déployer progressivement.

## Pourquoi `RollingUpdate` est limité

Kubernetes propose déjà une stratégie très connue : `RollingUpdate`.

Cette stratégie remplace progressivement les anciens pods par les nouveaux.

C'est utile.
Mais cela reste limité pour un service ML.

Pourquoi ?

- on raisonne surtout en pods
- on valide peu le comportement réel du modèle
- le contrôle du trafic reste limité
- la décision de rollback n'est pas naturellement liée aux métriques métier ou techniques

## Les concepts à connaître

Avant d'aller plus loin, définissons chaque stratégie avec des mots simples.

### Shadow

Le **shadow** envoie une copie du trafic à une nouvelle version.

L'utilisateur continue à recevoir la réponse de la version stable.

La nouvelle version travaille en arrière-plan.

### Canary

Le **canary** donne une petite part du trafic réel à la nouvelle version.

On commence petit.
Puis on augmente progressivement si tout va bien.

### Blue-Green

Le **blue-green** maintient deux environnements :

- un environnement actif
- un environnement prêt à prendre la relève

Puis on bascule de l'un vers l'autre.

### Pause

Une **pause** arrête temporairement la progression du rollout.

Elle sert à observer avant de continuer.

### Promotion

La **promotion** consiste à autoriser l'étape suivante du déploiement.

### Abort

L'**abort** interrompt le rollout parce qu'un signal indique un risque ou un problème.

### Rollback

Le **rollback** consiste à revenir à une version stable précédente.

## Pourquoi c'est encore plus important en MLOps

Un service applicatif classique peut être principalement jugé sur :

- sa disponibilité
- son taux d'erreur
- sa latence

Un service ML ajoute une couche de risque supplémentaire.

Une nouvelle version peut être :

- saine côté pods
- saine côté HTTP
- mais mauvaise côté prédiction ou stabilité comportementale

Cela veut dire qu'un bon déploiement ML demande :

- une observation plus fine
- une validation progressive
- la possibilité de revenir vite en arrière

## Le Cas d' usage

Nous allons travailler sur un service unique :

**un service de scoring de fraude temps réel**.

Le scénario du module est le suivant :

- `fraud-model:v1` est le champion
- `fraud-model:v2` est le challenger
- `fraud-model:v2-buggy` sert à démontrer un abort automatique

Avant de passer aux stratégies de trafic, prenez quelques minutes pour relire `service/app.py` dans le dépôt du projet.

Si ce n'est pas déjà fait, créez aussi votre fichier local `service/.env` à partir de `service/.env.example`.

```bash
cp service/.env.example service/.env
```

Puis vérifiez que vous partez bien avec :

```env
MODEL_VERSION=v1
```

Cela vous permettra de lancer et tester localement le service avant de l'utiliser dans Kubernetes.

Repérez trois éléments :

- la variable `MODEL_VERSION`
- la fonction `score_request(...)`
- les métriques Prometheus

Dans le projet, le service distingue déjà plusieurs versions :

```python
MODEL_VERSION = os.getenv("MODEL_VERSION", "v1")

...

if MODEL_VERSION == "v2":
    score += 0.05
if MODEL_VERSION == "v2-buggy":
    time.sleep(1.2)
```

Ce code n'est pas encore parfait, et c'est normal.
Il sert déjà à faire comprendre une idée essentielle :

- une version différente peut avoir un comportement différent
- ce comportement peut être plus lent ou plus risqué
- c'est précisément pour cela que le progressive delivery est utile

En observant ce même fichier, repérez aussi les métriques suivantes :

- `fraud_predictions_total`
- `fraud_prediction_latency_seconds`
- `fraud_prediction_errors_total`

Question utile (essayez d'y répondre de votre côté pour vérifier vos connaissances) : pourquoi ces métriques seront-elles importantes pour un rollout ?

Si vous voulez vérifier votre réponse, ouvrez le bloc suivant.

%%SOLUTION%%

Réponse attendue :

- elles donnent de la visibilité sur le comportement technique du service
- elles permettront plus tard d'alimenter Prometheus
- elles préparent la décision de promotion ou d'abort

%%SOLUTION%%

## Exemple concret

Imaginez qu'une banque envoie des requêtes de scoring de fraude en temps réel.

Vous avez amélioré votre modèle.
Mais vous ne voulez pas exposer immédiatement tous les utilisateurs à la nouvelle version.

Vous pouvez alors :

1. commencer par du **shadow**
2. passer à un **canary**
3. éventuellement utiliser un **blue-green** selon le besoin de bascule

## Tableau mental rapide

```txt
Shadow     -> la nouvelle version observe sans servir la réponse
Canary     -> la nouvelle version sert une petite part du trafic réel
Blue-Green -> on prépare deux environnements puis on bascule
```

## Erreurs fréquentes

### 1. Penser que la santé des pods suffit à valider un modèle

Pour éviter cette erreur :

- regardez aussi la latence, les erreurs et le comportement du service
- gardez en tête qu'un modèle peut être techniquement vivant mais opérationnellement risqué

### 2. Confondre shadow et canary

Pour éviter cette erreur :

- retenez qu'en shadow, l'utilisateur ne voit pas la réponse de la nouvelle version
- retenez qu'en canary, une vraie part de trafic utilisateur arrive sur la nouvelle version

## Résumé

- `RollingUpdate` ne répond pas à tous les besoins d'un service ML.
- `shadow`, `canary` et `blue-green` servent à réduire le risque de mise en production.
- En MLOps, la validation progressive est particulièrement importante.

## Pour la suite

Dans le prochain chapitre, vous allez commencer par la stratégie la moins risquée pour l'utilisateur : le **shadow** avec NGINX Ingress.
