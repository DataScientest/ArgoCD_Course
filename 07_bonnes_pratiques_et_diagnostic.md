# Chapitre 7 : Bonnes Pratiques et Diagnostic

## Préface

Dans le chapitre précédent, vous avez vu comment automatiser une décision de rollout à l'aide des métriques.

Vous savez maintenant :

- pourquoi il faut des signaux objectifs
- comment `AnalysisTemplate` structure une règle de décision
- quelles métriques techniques privilégier

Nous allons terminer le module avec deux compétences très utiles :

- diagnostiquer un problème rapidement
- concevoir un rollout de manière plus robuste

## Pourquoi ce chapitre compte

Même avec une bonne stratégie, un rollout peut se bloquer.

Le vrai niveau opérationnel commence quand vous savez répondre à cette question :

**qu'est-ce qui ne va pas, et où regarder d'abord ?**

## Diagnostic rapide d'un rollout

Voici les cas les plus utiles à savoir traiter.

### Rollout bloqué

Questions à se poser :

- le rollout est-il en pause
- une analyse a-t-elle échoué
- les ReplicaSets sont-ils corrects

### Pause active

Une pause n'est pas forcément un problème.

Il faut d'abord vérifier si elle est attendue.

### Erreur d'analyse

Si l'analyse échoue, regardez :

- la requête de métrique
- les seuils définis
- la disponibilité des données côté Prometheus

### Problème d'Ingress

Si le trafic ne va pas où il faut, vérifiez :

- les règles d'Ingress
- le traffic shifting
- le mirroring

### Problème applicatif

Si l'application elle-même pose problème, observez :

- `/health`
- `/metrics`
- les logs
- la version de modèle réellement servie

## Bonnes pratiques de conception

Voici les recommandations les plus importantes à retenir.

### Garder le service simple pour la démo

Le but du module n'est pas de complexifier artificiellement le service ML.

### Exposer `/health` et `/metrics`

Ces endpoints facilitent beaucoup l'observabilité.

### Tracer `model_version`

C'est indispensable pour distinguer clairement le comportement de `v1`, `v2` et `v2-buggy`.

### Commencer avec des gates techniques robustes

Il vaut mieux commencer avec :

- taux d'erreur
- latence

plutôt qu'avec des signaux trop lents ou trop ambigus.

### Utiliser le shadow avant le canary quand le risque est élevé

Le shadow peut vous donner une première observation sans exposer l'utilisateur.

### Limiter le périmètre d'un rollout

Un rollout est plus lisible et plus sûr s'il concerne un service bien défini.

## Le message MLOps final

Le point le plus important du module est celui-ci :

un déploiement réussi n'est pas seulement un pod qui démarre.

Il faut aussi :

- une validation progressive
- des métriques fiables
- la capacité d'interrompre
- la capacité de revenir en arrière rapidement

## Checklists pédagogiques

### Checklist de troubleshooting

- le rollout est-il en pause
- les métriques remontent-elles bien
- la requête Prometheus est-elle correcte
- l'Ingress envoie-t-il le trafic attendu
- l'application expose-t-elle bien `/health` et `/metrics`

### Checklist de bonnes pratiques

- service ML simple et observable
- `model_version` tracée partout
- stratégies de rollout adaptées au risque
- critères de promotion explicites
- rollback possible rapidement

## Conclusion du module

Le message final du module est le suivant :

> Dans un système ML, déployer une nouvelle version ne consiste pas à remplacer une image puis espérer que tout se passe bien. Il faut valider progressivement, observer avec des métriques fiables, limiter l'impact et pouvoir revenir rapidement à une version stable.

Et le message technique clé est :

> Argo Rollouts orchestre la stratégie de déploiement progressive ; NGINX aide à gérer le trafic ; Prometheus et Grafana donnent la visibilité nécessaire pour décider.

## Résumé

- Savoir déployer progressivement ne suffit pas : il faut aussi savoir diagnostiquer et corriger.
- Les bonnes pratiques de visibilité et de simplicité sont essentielles en MLOps.
- La valeur d'Argo Rollouts apparaît pleinement quand la décision repose sur des métriques observables.
