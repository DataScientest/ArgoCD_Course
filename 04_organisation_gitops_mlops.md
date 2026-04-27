# Chapitre 4 : Organiser un dépôt GitOps pour un projet MLOps

## Préface

Dans le chapitre précédent, vous avez vu comment ArgoCD détecte et corrige une dérive.

Vous savez maintenant :

- ce qu’est un drift
- ce que fait `self-heal`
- ce que fait `prune`

Nous allons terminer ce module avec une question plus structurelle : comment organiser proprement un dépôt GitOps pour un projet MLOps.

## Pourquoi ce chapitre compte

Un dépôt GitOps peut rester lisible au début, puis devenir difficile à maintenir si tout est mélangé dans les mêmes fichiers.

Dans un contexte MLOps, les besoins deviennent vite plus riches :

- plusieurs environnements
- plusieurs applications
- plusieurs responsabilités

Il faut donc penser plus tôt à l’organisation.

## Reprendre la structure du projet

Le dépôt `ArgoCD_Course` contient déjà une base utile pour cette réflexion.

Relisez :

- `k8s/base/`
- `k8s/overlays/dev/`
- `k8s/overlays/prod/`
- `k8s/argocd/`

Cette organisation n’est pas là par hasard.
Elle montre une manière plus propre d’organiser un dépôt GitOps.

## Base et overlays

La logique est la suivante :

- `base/` contient les ressources communes
- `overlays/` introduit les différences selon les environnements

Dans notre projet, cela permet déjà de faire varier :

- le nombre de replicas
- la cible d’un environnement
- le contexte d’exécution

## Pourquoi séparer `dev` et `prod`

Pour un service ML, il est fréquent d’avoir au moins :

- un environnement `dev`
- un environnement `prod`

Cette séparation est utile parce qu’elle permet :

- de tester sans impacter la production
- de garder une trace claire des différences
- de faire évoluer un environnement sans casser l’autre

## À quoi sert un `AppProject`

Dans ArgoCD, un `AppProject` sert à encadrer des applications.

Il peut définir :

- les dépôts autorisés
- les namespaces autorisés
- les types de ressources autorisées

Autrement dit, il apporte une couche de gouvernance.

Dans un petit lab, cela peut sembler accessoire.
Dans un vrai projet MLOps, cela devient vite très utile.

## Exemple de réflexion MLOps

Dans un projet ML réel, vous pouvez vouloir séparer :

- l’API de scoring
- les dashboards de monitoring
- les manifests de `dev`
- les manifests de `prod`

Le but n’est pas d’ajouter de la complexité gratuitement.
Le but est de garder un dépôt lisible, traçable et maintenable.

## Ce qu’il faut viser dans un vrai projet

Le but n’est pas d’avoir le plus de YAML possible.

Le but est d’avoir :

- une structure compréhensible
- des responsabilités séparées
- des changements traçables
- une automatisation maîtrisée

## Exercice de lecture

Dans `k8s/argocd/appproject-fraud.yaml`, repérez :

- les dépôts autorisés
- les destinations autorisées
- le rôle général du projet

Cette lecture vous montrera qu’un `AppProject` n’est pas un simple regroupement visuel.
Il sert aussi à définir ce qu’une application a le droit de faire.

## Erreurs fréquentes

### 1. Mélanger tous les environnements dans les mêmes manifests

Pour éviter cette erreur :

- séparez clairement les contextes `dev` et `prod`

### 2. Utiliser ArgoCD sans règles de périmètre

Pour éviter cette erreur :

- utilisez `AppProject` dès que le projet commence à grandir

## Résumé

- Un dépôt GitOps doit être organisé, pas seulement versionné.
- La séparation des environnements est importante en MLOps.
- `AppProject` apporte une couche utile de gouvernance.

## Conclusion du module

Le message principal du module est le suivant :

> ArgoCD permet de rendre le déploiement d’un service ML plus traçable, plus cohérent et plus reproductible en traitant Git comme source de vérité.

Et le message opérationnel à retenir est :

> plus votre dépôt GitOps est clair, plus votre usage d’ArgoCD sera fiable et compréhensible.
