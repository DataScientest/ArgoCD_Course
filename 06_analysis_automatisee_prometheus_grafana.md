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
- `count`
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
          count: 3
          failureLimit: 1
          successCondition: result[0] < 0.05
          failureCondition: result[0] >= 0.05
      provider:
        prometheus:
          address: http://prometheus-server.monitoring.svc.cluster.local
          query: |
            sum(rate(fraud_prediction_errors_total{model_version="v2-buggy"}[1m])) or vector(0)
        - name: p95-latency
          interval: 30s
          count: 3
          failureLimit: 1
          successCondition: result[0] < 0.8
          failureCondition: result[0] >= 0.8
      provider:
        prometheus:
          address: http://prometheus-server.monitoring.svc.cluster.local
          query: |
            histogram_quantile(
              0.95,
              sum(rate(fraud_prediction_latency_seconds_bucket{model_version="v2-buggy"}[1m])) by (le)
            ) or vector(0)
```

%%SOLUTION%%

Ce que vous devez retenir :

- une analyse automatisée repose sur une règle claire
- Prometheus fournit la métrique
- Argo Rollouts compare cette métrique à des seuils
- si les seuils sont mauvais, le rollout peut être interrompu
- `count` évite qu'une mesure se répète indéfiniment
- une requête Prometheus doit aussi rester robuste si la série de métriques est vide au début

## Mettre en place et tester l'analyse automatisée

Comme pour les chapitres précédents, modifier le YAML ne suffit pas.
Il faut aussi mettre en place l'infrastructure d'observabilité et provoquer un comportement mesurable.

### 1. Nettoyer l'étape précédente

Si vous venez du chapitre 5, commencez par retirer le rollout blue-green :

```bash
make cleanup-bluegreen
```

### 2. Installer Prometheus et Grafana

Le projet fournit un script de base pour ce chapitre :

```bash
bash scripts/install-monitoring.sh
```

Cette étape peut prendre un peu de temps.

Le script commence par installer les **CRDs** du Prometheus Operator.

Pourquoi est-ce important ?

- les objets comme `ServiceMonitor`, `Prometheus` ou `PrometheusRule` n'existent pas dans Kubernetes par défaut
- sans ces CRDs, Helm ne peut pas installer correctement la stack de monitoring
- et le chapitre 6 ne peut pas fonctionner de bout en bout

Ensuite, vérifiez que les pods de monitoring deviennent bien `Running` :

```bash
kubectl get pods -n monitoring
```

### 3. Appliquer l'`AnalysisTemplate`

```bash
make apply-analysis-template
make apply-servicemonitor
kubectl get analysistemplate -n fraud-detection
```

Le `ServiceMonitor` est important ici.
Il permet à Prometheus de découvrir explicitement les métriques du service.

### 4. Vérifier d'abord Prometheus

Avant même de regarder Grafana, il faut vérifier que Prometheus scrape bien l'application.

Faites un port-forward vers Prometheus :

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Puis ouvrez dans votre navigateur :

```txt
http://127.0.0.1:9090/targets
```

Vous devez y voir une target liée à votre service de fraude en `UP`.

Si vous ne voyez rien dans Prometheus, Grafana ne pourra rien afficher non plus.

### 5. Appliquer le rollout d'analyse en `v1`

```bash
make apply-analysis-rollout
kubectl argo rollouts get rollout fraud-rollout-analysis -n fraud-detection
```

À ce stade, `v1` reste la base stable.

### 6. Préparer et charger la version `v2-buggy`

```bash
make build-v2-buggy
make load-v2-buggy
```

### 7. Mettre à jour le rollout vers `v2-buggy`

```bash
make update-analysis-to-v2-buggy
kubectl argo rollouts get rollout fraud-rollout-analysis -n fraud-detection
```

Cette mise à jour lance la nouvelle révision candidate avec les étapes d'analyse automatiques.

### 8. Générer du trafic vers la version canary

Pour que Prometheus observe des erreurs et de la latence, il faut produire du trafic.

Commencez par identifier le pod canary :

```bash
kubectl argo rollouts get rollout fraud-rollout-analysis -n fraud-detection
kubectl get pods -n fraud-detection
```

Le pod que vous devez viser est celui de la **révision canary actuelle**.

Autrement dit :

- pas un pod stable
- pas une ancienne révision scaled down
- mais bien le pod associé à la nouvelle révision candidate

Puis faites un port-forward vers le pod de la nouvelle révision :

```bash
kubectl port-forward -n fraud-detection pod/<pod-canary> 8083:8000
```

Dans un second terminal, envoyez plusieurs requêtes :

```bash
for i in $(seq 1 20); do
  curl -s -X POST http://127.0.0.1:8083/predict \
    -H "Content-Type: application/json" \
    -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
  echo
done
```

Si vous voulez rendre le signal encore plus visible, vous pouvez augmenter la charge avec :

```bash
for i in $(seq 1 100); do
  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:8083/predict \
    -H "Content-Type: application/json" \
    -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
done
```

Cette version est utile quand vous voulez provoquer davantage d'erreurs `500` et rendre l'effet de `v2-buggy` plus visible pendant l'analyse.

Avec `v2-buggy`, vous devez observer :

- des réponses lentes
- parfois des erreurs HTTP `500`

### 9. Observer le résultat de l'analyse

Surveillez les `AnalysisRun` créés par Argo Rollouts :

```bash
kubectl get analysisrun -n fraud-detection
kubectl describe analysisrun -n fraud-detection <analysisrun-name>
```

Et relisez l'état du rollout :

```bash
kubectl argo rollouts get rollout fraud-rollout-analysis -n fraud-detection
```

Si la version candidate se comporte mal pendant l'analyse, vous devez voir apparaître un échec dans l'un de ces deux endroits :

- un `AnalysisRun` qui passe en `Failed` ou `Error`
- un rollout qui passe en `Degraded` ou qui est `Aborted`

### 10. Ce que vous devez voir concrètement

Si la version `v2-buggy` génère assez d'erreurs ou de latence, vous devez observer :

- un `AnalysisRun` en échec
- un rollout interrompu ou dégradé
- l'ancienne version stable qui reste en place

Autrement dit, l'analyse automatisée aura joué son rôle de garde-fou.

## Vérifier le fail dans Prometheus

Une fois le trafic généré vers `v2-buggy`, vous pouvez vérifier le signal directement dans Prometheus.

Faites un port-forward :

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Puis ouvrez :

```txt
http://127.0.0.1:9090/graph
```

Testez les deux requêtes suivantes.

### Taux d'erreur

```promql
sum(rate(fraud_prediction_errors_total{model_version="v2-buggy"}[1m])) or vector(0)
```

### Latence `p95`

```promql
histogram_quantile(
  0.95,
  sum(rate(fraud_prediction_latency_seconds_bucket{model_version="v2-buggy"}[1m])) by (le)
) or vector(0)
```

Ce que vous devez observer :

- pendant le trafic, les courbes montent
- si `v2-buggy` se comporte mal, elles peuvent dépasser les seuils du `AnalysisTemplate`

Autrement dit, Prometheus vous montre la **cause métrique** de l'échec.

### 11. Ce que Grafana apporte ici

Même si Argo Rollouts prend la décision à partir de Prometheus, Grafana vous permet de rendre cette décision plus lisible.

Vous pouvez l'utiliser pour voir plus clairement :

- l'augmentation de la latence
- la montée des erreurs
- la différence entre la version stable et la version candidate

Dans ce chapitre, Grafana sert donc à interpréter visuellement ce que l'analyse automatisée a déjà détecté.

## Vérifier visuellement dans Grafana

Pour donner un rendu plus concret à ce chapitre, vous pouvez aussi ouvrir Grafana et regarder l'effet de `v2-buggy` de manière visuelle.

### 1. Ouvrir Grafana

Si vous avez installé Grafana avec le script du projet, vous pouvez faire un port-forward :

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Puis ouvrez :

```txt
http://127.0.0.1:3000
```

Identifiants par défaut du script d'installation :

- utilisateur : `admin`

Selon votre installation, le mot de passe peut être différent de `admin`.

Si la connexion échoue, récupérez le mot de passe réel avec :

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

Puis utilisez la valeur affichée comme mot de passe Grafana.

### 2. Ce qu'il faut regarder

Dans Grafana, vous pouvez créer un panneau simple ou utiliser l'exploration de requêtes pour observer :

- le taux d'erreur de `v2-buggy`
- la latence `p95`
- la comparaison entre `v1` et `v2-buggy`

Exemples de requêtes Prometheus utiles :

```promql
sum(rate(fraud_prediction_errors_total{model_version="v2-buggy"}[1m]))
```

```promql
histogram_quantile(
  0.95,
  sum(rate(fraud_prediction_latency_seconds_bucket{model_version="v2-buggy"}[1m])) by (le)
)
```

Ce que vous devez voir si `v2-buggy` se comporte mal :

- une hausse du taux d'erreur
- une latence plus élevée
- un comportement visiblement plus mauvais que `v1`

Une petite démo visuelle suffisante pour ce chapitre consiste à créer deux panneaux simples :

- un panneau pour le taux d'erreur de `v2-buggy`
- un panneau pour la latence `p95`

Même sans dashboard très sophistiqué, cela suffit pour rendre visible l'effet de la version candidate.

## Petite démo visuelle de fail dans Grafana

Pour une démo simple, vous pouvez faire ceci.

### 1. Ouvrir Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Puis ouvrir :

```txt
http://127.0.0.1:3000
```

### 2. Aller dans Explore

Dans Grafana :

- ouvrez **Explore**
- choisissez la source de données Prometheus

### 3. Lancer les deux requêtes

Requête 1 :

```promql
sum(rate(fraud_prediction_errors_total{model_version="v2-buggy"}[1m])) or vector(0)
```

Requête 2 :

```promql
histogram_quantile(
  0.95,
  sum(rate(fraud_prediction_latency_seconds_bucket{model_version="v2-buggy"}[1m])) by (le)
) or vector(0)
```

### 4. Rejouer du trafic pendant l'observation

Pendant que Grafana affiche les courbes, relancez la charge :

```bash
for i in $(seq 1 100); do
  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:8083/predict \
    -H "Content-Type: application/json" \
    -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
done
```

### 5. Ce que vous devez voir

Si le fail est bien visible :

- le taux d'erreur monte dans Grafana
- la latence `p95` monte aussi
- en parallèle, Argo Rollouts peut finir par dégrader ou interrompre le rollout

Donc la lecture complète devient :

- **Prometheus** montre les valeurs brutes
- **Grafana** les rend visuelles
- **Argo Rollouts** prend la décision sur cette base

## Où voit-on l'alerte ?

Ici, il faut bien distinguer deux choses.

### Ce que vous voyez dans ce chapitre

Dans ce module, la "décision" n'apparaît pas d'abord comme une alerte Prometheus classique.

Elle apparaît surtout dans :

- `kubectl describe analysisrun ...`
- `kubectl argo rollouts get rollout ...`

Autrement dit, Argo Rollouts lit les métriques Prometheus et prend sa décision via l'`AnalysisTemplate`.

Le signal principal se voit donc dans :

- l'état de l'`AnalysisRun`
- l'état du `Rollout`

### Ce que vous ne voyez pas encore forcément

Vous ne verrez pas automatiquement une alerte Prometheus ou Alertmanager, sauf si vous créez en plus :

- une règle d'alerte Prometheus (`PrometheusRule`)
- et éventuellement une notification côté Alertmanager ou Grafana

Donc, dans la démonstration actuelle :

- Prometheus sert de source de métriques
- Argo Rollouts exploite ces métriques pour décider
- Grafana sert à visualiser
- l'"alerte" opérationnelle se lit d'abord dans Argo Rollouts, pas dans Alertmanager

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
