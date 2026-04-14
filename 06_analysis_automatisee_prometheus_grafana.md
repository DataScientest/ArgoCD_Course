# Chapitre 6 : Analysis Automatisée avec Prometheus et Grafana

## Préface

Dans le chapitre précédent, vous avez vu le blue-green.

Vous savez maintenant :

- ce qu'est un environnement actif
- ce qu'est un environnement preview
- quand une bascule nette peut être utile

Nous allons maintenant passer à un point essentiel du progressive delivery moderne : **l'automatisation de la décision**.

## Pourquoi ce chapitre compte

Si vous promouvez une nouvelle version uniquement à l'intuition, vous prenez un risque inutile.

L'objectif de ce chapitre est donc de montrer comment décider à partir de signaux mesurables.

## La philosophie derrière

Imaginez un feu de signalisation automatique.

Au lieu de demander à une personne de regarder la route à chaque instant, on utilise des capteurs.

Dans un rollout, les métriques jouent le rôle de ces capteurs.

## Pourquoi automatiser la décision

Automatiser la décision permet de :

- éviter une promotion basée sur une impression
- rendre la décision traçable
- standardiser l'abort automatique

## `AnalysisTemplate`

L'objet important ici est `AnalysisTemplate`.

Son rôle est de décrire :

- quelle métrique on interroge
- où on la lit
- quel seuil est acceptable
- quand il faut considérer l'analyse comme réussie ou échouée

## Éléments clés d'une analyse

Quand vous lisez un `AnalysisTemplate`, vous devez repérer :

- le provider Prometheus
- la requête de métrique
- `successCondition`
- `failureCondition`
- `failureLimit`

## Quelles métriques choisir

Pour un rollout rapide, les métriques les plus utiles sont souvent :

- le taux d'erreur
- la latence `p95`
- la latence `p99`

Pourquoi ces métriques sont intéressantes :

- elles réagissent vite
- elles sont directement observables
- elles permettent de prendre une décision technique rapide

## Ce qu'il ne faut pas utiliser comme gate immédiat

Certaines métriques sont importantes.
Mais elles ne sont pas adaptées à une décision de rollout immédiate.

Par exemple :

- l'accuracy retardée
- un drift mesuré sur plusieurs jours
- des KPI métier qui demandent du temps pour être interprétés

Ces indicateurs restent utiles.
Mais pas comme signal immédiat pour décider une promotion minute par minute.

## Rôle de Grafana

**Grafana** ne prend pas la décision à la place de l'analyse.

Son rôle est de vous aider à lire rapidement la situation.

Dans ce module, on veut surtout visualiser :

- les métriques par `model_version`
- la latence
- le taux d'erreur

## Démonstrations attendues

Deux cas pédagogiques sont importants :

### `v2` saine

Le rollout peut continuer sa progression.

### `v2-buggy`

Les seuils sont dépassés.
Le système doit alors déclencher un abort automatique.

## Livrables du chapitre

- un `AnalysisTemplate`
- un canary automatisé `10 -> 25 -> 50 -> 100`
- un abort automatique si les seuils sont dépassés

Dans le dépôt du projet, le fichier `k8s/analysis/prometheus-analysis-template.yaml` contient volontairement une structure incomplète.

Vous allez le compléter pour lui donner un vrai rôle de garde-fou pendant un rollout.

Vous devez renseigner :

- la requête Prometheus
- `successCondition`
- `failureCondition`

Le fichier part de cette base :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: fraud-success-rate
  namespace: fraud-detection
spec:
  metrics:
    - name: error-rate
      interval: 30s
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          # TODO chapitre 6 : compléter la requête Prometheus.
          query: |
            up
      # TODO chapitre 6 : compléter successCondition et failureCondition.
```

Essayez d'abord de proposer votre propre version.
Ensuite, si vous voulez vérifier votre écriture, ouvrez le bloc suivant.

%%SOLUTION%%

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: fraud-latency-and-errors
  namespace: fraud-detection
spec:
  metrics:
    - name: error-rate
      interval: 30s
      failureLimit: 1
      successCondition: result[0] < 0.05
      failureCondition: result[0] >= 0.05
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            sum(rate(fraud_prediction_errors_total{model_version="v2-buggy"}[1m])) or vector(0)
    - name: p95-latency
      interval: 30s
      failureLimit: 1
      successCondition: result[0] < 0.8
      failureCondition: result[0] >= 0.8
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            histogram_quantile(
              0.95,
              sum(rate(fraud_prediction_latency_seconds_bucket[1m])) by (le)
            )
```

%%SOLUTION%%

Ce que vous devez retenir :

- une analyse automatisée repose sur une règle claire
- Prometheus fournit la métrique
- Argo Rollouts compare cette métrique à des seuils
- si les seuils sont mauvais, le rollout peut être interrompu

## Erreurs fréquentes

### 1. Choisir une métrique trop lente pour décider

Pour éviter cette erreur :

- utilisez d'abord des signaux techniques rapides
- gardez les métriques longues pour une analyse plus globale

### 2. Utiliser Grafana comme seule source de décision

Pour éviter cette erreur :

- rappelez-vous que Grafana sert à visualiser
- rappelez-vous que la logique de décision formelle est dans l'analyse et ses conditions

## Résumé

- L'automatisation permet de rendre la promotion ou l'abort plus fiable et plus traçable.
- `AnalysisTemplate` décrit comment évaluer une nouvelle version à partir des métriques.
- Prometheus mesure, Grafana visualise, Argo Rollouts décide selon les règles définies.

## Pour la suite

Dans le dernier chapitre, vous allez apprendre à diagnostiquer un rollout bloqué et à appliquer de bonnes pratiques de progressive delivery pour les services ML.
