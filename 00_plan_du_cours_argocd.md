# ArgoCD : GitOps pour l'Industrialisation d'un Service ML

## Introduction du module

Dans beaucoup de projets MLOps, on parle souvent d'entraînement, de métriques, de registre de modèles, ou encore de monitoring. Pourtant, une question reste souvent floue pour les apprenants au début :

**comment fait-on pour déployer proprement une application ML dans Kubernetes sans perdre la maîtrise de ce qui est réellement en production ?**

C'est exactement la question de ce module.

Ici, nous n'allons pas travailler la performance d'un modèle. Nous allons travailler sa **mise à disposition contrôlée** dans un cluster Kubernetes, avec une logique GitOps claire, traçable et reproductible.

L'outil central du module sera **ArgoCD**.

## Le fil rouge du module

Pour garder une progression concrète, nous allons suivre un même projet du début à la fin.

Le use case retenu est le suivant :

**une API de priorisation de tickets de support client**.

Cette API représente un petit service ML qui aide une équipe support à classer les demandes entrantes selon leur niveau de priorité.

Le service expose trois endpoints :

- `POST /predict`
- `GET /health`
- `GET /metrics`

Le but du module n'est pas d'expliquer le modèle de priorité en lui-même. Le but est d'apprendre à piloter son déploiement et sa cohérence opérationnelle avec ArgoCD.

## Le projet utilisé pendant le module

Le support projet du module est disponible ici :

[`ArgoCD_Course`](https://github.com/DataScientest/ArgoCD_Course.git)

Vous l'utiliserez tout au long du cours.

Le principe est simple :

- le chapitre introduit une notion
- vous ouvrez le bon fichier dans le dépôt
- vous appliquez la configuration
- vous observez le résultat dans Kubernetes et dans ArgoCD

## Pourquoi ce module compte en MLOps

Dans un contexte d'entreprise, un service ML n'a de valeur que s'il reste :

- traçable
- reproductible
- cohérent avec ce qui a été validé

Un déploiement manuel dans Kubernetes peut fonctionner au début. Mais très vite, il pose des problèmes :

- on ne sait plus quel YAML correspond à l'état réel
- on modifie le cluster à la main
- Git n'est plus la référence
- l'équipe perd en visibilité

ArgoCD apporte justement une réponse à ce problème.

## Pré-requis

Les apprenants connaissent déjà les bases de Kubernetes. Nous allons donc utiliser une stack légère, adaptée à un lab local ou à une VM.

Outils attendus :

- `git`
- `uv`
- `docker`
- `kind`
- `kubectl`
- `make`

## Répartition du module

### Chapitre 1 — Comprendre GitOps et le rôle d'ArgoCD

Dans ce premier chapitre, vous allez construire la bonne carte mentale.

Nous verrons :

- ce que signifie GitOps
- ce qu'on appelle état désiré et état réel
- le rôle exact d'ArgoCD
- comment le dépôt du projet s'inscrit dans cette logique

### Chapitre 2 — Déployer une première application avec ArgoCD

Dans ce deuxième chapitre, vous passerez à la mise en pratique.

Nous verrons :

- comment préparer le projet
- comment lancer un cluster léger
- comment installer ArgoCD
- comment créer une première `Application`
- comment lire les états `Synced` et `Healthy`

### Chapitre 3 — Détecter et corriger une dérive

Dans ce troisième chapitre, vous verrez enfin l'intérêt concret de GitOps.

Nous verrons :

- ce qu'est un drift
- comment ArgoCD le détecte
- comment fonctionne `self-heal`
- comment fonctionne `prune`

### Chapitre 4 — Organiser un dépôt GitOps pour un projet MLOps

Dans ce dernier chapitre, nous prendrons de la hauteur.

Nous verrons :

- comment structurer un dépôt GitOps
- comment séparer `dev` et `prod`
- à quoi sert un `AppProject`
- comment garder une organisation claire dans un projet ML plus large

## Ce que vous saurez faire à la fin

À la fin du module, vous saurez :

- expliquer le rôle d'ArgoCD dans une approche GitOps
- relier un dépôt Git à un cluster Kubernetes
- lire une synchronisation et un état de santé
- comprendre et corriger une dérive
- organiser plus proprement un dépôt GitOps pour un service ML
