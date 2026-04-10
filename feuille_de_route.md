# Plan détaillé — Module A : Progressive Delivery MLOps avec Argo sur Kubernetes

## Titre du module

**Module A — Progressive Delivery MLOps avec Argo sur Kubernetes**

Sous-titre :

**Shadow, canary, blue-green et rollback automatisé pour un service ML temps réel**

---

## 1. Positionnement du module

Ce module s'inscrit dans le sprint où Kubernetes est déjà abordé.

Il ne s'agit donc pas de refaire un cours complet sur :

- Kubernetes
- Argo CD
- NGINX
- Prometheus

Le module doit rester centré sur **Argo** et montrer comment mettre en place un **déploiement progressif d'un service ML** sur Kubernetes de manière :

- progressive
- observable
- réversible

Le cluster local de lab retenu pour les démonstrations est **`kind`**.

### Pourquoi `kind`

Ce choix doit être expliqué rapidement au début du module :

- cluster local simple à créer et supprimer
- environnement reproductible pour les labs
- proche d'un Kubernetes standard
- peu de concepts supplémentaires
- bien adapté à une stack de démonstration légère

---

## 2. Objectifs pédagogiques

À la fin du module, l'apprenant doit être capable de :

- expliquer la différence entre `RollingUpdate`, `shadow`, `canary` et `blue-green`
- expliquer la différence entre **Argo CD** et **Argo Rollouts**
- lire l'état d'un objet `Rollout`
- utiliser `kubectl argo rollouts` pour observer, promouvoir et annuler un rollout
- comprendre le rôle de `ingress-nginx` dans le mirroring et le traffic shifting
- construire une stratégie de validation progressive pour un service ML
- relier un rollout à des métriques techniques via **Prometheus**
- comprendre quand déclencher une promotion ou un abort

---

## 3. Prérequis

Les apprenants sont supposés avoir :

- les bases de Kubernetes
- les bases de Docker
- les bases YAML
- des notions de CI/CD

Les apprenants **n'ont pas** de vraie base GitOps.

Conséquence pédagogique :

- faire un rappel court de CI/CD
- faire une introduction simple et ciblée à GitOps

---

## 4. Fil rouge du module

Le module s'appuie sur un use case ML unique du début à la fin.

### Use case retenu

**Service de scoring de fraude temps réel**

### Pourquoi ce use case

- il est crédible en contexte MLOps
- il reste simple à expliquer
- il se prête très bien à un service synchrone
- il permet un vrai scénario champion / challenger
- il permet d'utiliser des métriques techniques claires pour le rollout

### Service de démonstration

Le service peut être construit simplement avec :

- `FastAPI`
- un modèle `scikit-learn`

Endpoints minimum :

- `POST /predict`
- `GET /health`
- `GET /metrics`

### Entrées type

- `amount`
- `merchant_category`
- `hour_of_day`
- `country`
- `is_international`
- `device_risk_score`

### Sortie type

- `fraud_probability`
- `prediction`
- `model_version`

### Versions utilisées dans le cours

- `v1` : version stable en production
- `v2` : nouvelle version candidate
- `v2-buggy` : version volontairement dégradée pour montrer l'abort automatique

---

## 5. Stack du module

La stack retenue doit rester simple à setup.

- `kind`
- `Argo Rollouts`
- `kubectl argo rollouts`
- `ingress-nginx`
- `Prometheus`
- `Grafana`
- service ML `FastAPI`

### Rôle des outils

- **Argo CD** : contexte GitOps, rappel minimal
- **Argo Rollouts** : cœur du module, stratégie de déploiement progressive
- **NGINX Ingress** : shadow et traffic shifting
- **Prometheus** : source de métriques
- **Grafana** : tableau de bord d'observation

---

## 6. Structure détaillée du module

## Partie 0 — Cadrage minimal

### 0.1 Rappel CI/CD

Objectif :

- rappeler rapidement la chaîne de livraison sans refaire un module CI/CD

Points à couvrir :

- CI = build, tests, image
- CD = déploiement de ce qui a été validé
- image versionnée dans un registre

### 0.2 Introduction à GitOps

Objectif :

- donner le minimum indispensable pour comprendre Argo

Points à couvrir :

- état désiré vs état réel
- Git comme source de vérité
- changement traçable par commit
- réconciliation automatique

### 0.3 Argo CD vs Argo Rollouts

Objectif :

- éviter la confusion entre les deux outils

Points à couvrir :

- Argo CD synchronise l'état désiré
- Argo Rollouts pilote la stratégie de transition entre versions
- Argo CD applique
- Argo Rollouts orchestre la transition

### 0.4 Schéma d'ensemble

Présenter un schéma simple :

- Git
- Argo CD
- Rollout
- Ingress
- Service ML
- Prometheus / Grafana

**Livrable pédagogique**

- schéma d'architecture simplifié du module

---

## Partie 1 — Fondations du progressive delivery pour services ML

### 1.1 Pourquoi `Deployment RollingUpdate` est limité

Objectif :

- montrer pourquoi on ne se contente pas d'un `Deployment`

Points à couvrir :

- mise à jour orientée pods, pas validation métier
- contrôle limité du trafic
- pas d'analysis progressive intégrée
- rollback moins piloté par métriques
- blast radius moins maîtrisé

### 1.2 Concepts clés

Définir clairement :

- `shadow`
- `canary`
- `blue-green`
- `pause`
- `promotion`
- `abort`
- `rollback`

### 1.3 Spécificité MLOps

Objectif :

- montrer qu'un service ML n'est pas un service stateless banal

Points à couvrir :

- une nouvelle version peut être saine côté pods mais mauvaise côté comportement
- les décisions de rollout doivent s'appuyer sur des signaux observables
- importance de la version de modèle dans les logs et métriques

### 1.4 Présentation du fil rouge

Présenter :

- `fraud-model:v1` comme champion
- `fraud-model:v2` comme challenger
- logique de validation progressive

**Livrable pédagogique**

- fiche de cadrage du service ML et du scénario global

---

## Partie 2 — Shadow avec NGINX pour un service ML

### 2.1 Pourquoi faire du shadow

Objectif :

- introduire une pratique de validation sans risque utilisateur

Points à couvrir :

- la réponse utilisateur reste celle du champion
- le challenger reçoit une copie du trafic
- on observe son comportement sans exposition réelle

### 2.2 Rôle de NGINX Ingress

Objectif :

- faire le lien avec le module NGINX sans le refaire

Points à couvrir :

- le shadow est géré ici par la couche trafic
- rôle du mirroring
- distinction entre shadow et canary

### 2.3 Ce qu'on mesure

Points à observer :

- latence du challenger
- erreurs
- stabilité
- logs par version

### 2.4 Limites du shadow

Points à expliquer :

- pas de validation business complète
- pas de réponse visible par l'utilisateur
- ne remplace pas un canary réel

**Démo**

- `v1` sert la réponse
- `v2` reçoit le trafic miroir
- lecture des métriques et logs

**Livrable**

- démonstration de shadow champion / challenger

---

## Partie 3 — Canary avec Argo Rollouts

### 3.1 Passage de `Deployment` à `Rollout`

Objectif :

- introduire l'objet principal du module

Points à couvrir :

- structure d'un `Rollout`
- différence avec `Deployment`
- stratégie `canary`

### 3.2 Lecture d'un rollout

Objectif :

- apprendre à lire et diagnostiquer l'état

Points à couvrir :

- `kubectl argo rollouts get rollout`
- phases et statut
- événements
- ReplicaSets

### 3.3 Canary manuel

Objectif :

- montrer le progressive delivery en conditions réelles

Étapes à démontrer :

- déploiement de `v2`
- `10%`
- pause
- `25%`
- pause
- `50%`
- pause
- `100%`

### 3.4 Promotion manuelle

Points à couvrir :

- lecture du bon moment de promotion
- rôle des pauses
- réduction du blast radius

**Démo**

- canary manuel complet sur le service de fraude

**Livrable**

- YAML `Rollout` simple
- scénario de promotion manuelle

---

## Partie 4 — Blue-Green avec Argo Rollouts

### 4.1 Principe du blue-green

Objectif :

- présenter la deuxième stratégie standard couverte par Rollouts

Points à couvrir :

- environnement actif
- environnement preview
- bascule nette
- rollback rapide

### 4.2 Concepts techniques

À expliquer :

- `activeService`
- `previewService`
- promotion
- retour arrière

### 4.3 Comparaison avec canary

Tableau comparatif attendu :

- vitesse de validation
- granularité du risque
- simplicité de bascule
- coût en infrastructure

### 4.4 Intérêt en contexte ML

Points à couvrir :

- bon choix quand on veut une bascule propre
- moins riche qu'un canary pour observer une fraction réelle du trafic

**Démo**

- bascule blue-green simple entre `v1` et `v2`

**Livrable**

- YAML blue-green minimal
- tableau comparatif canary vs blue-green

---

## Partie 5 — Analysis automatisée avec Prometheus

### 5.1 Pourquoi automatiser la décision

Objectif :

- montrer la valeur opérationnelle d'Argo Rollouts

Points à couvrir :

- éviter une promotion à l'intuition
- rendre la décision traçable
- standardiser l'abort automatique

### 5.2 `AnalysisTemplate`

À présenter :

- structure générale
- provider Prometheus
- logique de requête
- `successCondition`
- `failureCondition`
- `failureLimit`

### 5.3 Choix des métriques

Métriques prioritaires :

- taux d'erreur
- latence `p95`
- latence `p99`

### 5.4 Ce qu'on ne doit pas utiliser comme gate immédiat

Points à expliquer :

- accuracy retardée
- drift long terme
- KPI métier nécessitant plusieurs jours

### 5.5 Grafana

Objectif :

- lire rapidement l'état du rollout dans un dashboard

Points à couvrir :

- visualisation par `model_version`
- suivi de latence
- suivi de taux d'erreur

**Démo**

- `v2` saine : progression du rollout
- `v2-buggy` : abort automatique sur seuil

**Livrable**

- `AnalysisTemplate`
- canary automatisé `10 -> 25 -> 50 -> 100`
- rollback ou abort automatique sur seuil dépassé

---

## Partie 6 — Bonnes pratiques et diagnostic

### 6.1 Diagnostic rapide d'un rollout

Cas à traiter :

- rollout bloqué
- pause active
- erreur d'analyse
- problème d'Ingress
- problème applicatif

### 6.2 Bonnes pratiques de conception

À recommander explicitement :

- garder le service ML simple pour la démo
- exposer `/health` et `/metrics`
- tracer `model_version`
- commencer avec des gates techniques robustes
- utiliser le shadow avant canary quand le risque est élevé
- limiter le périmètre d'un rollout à un service bien défini

### 6.3 Message MLOps final

Le message à faire passer :

- un déploiement réussi n'est pas seulement un pod qui démarre
- il faut une validation progressive
- il faut des métriques
- il faut pouvoir interrompre et revenir en arrière rapidement

**Livrable**

- checklist de troubleshooting
- checklist de bonnes pratiques

---

## 7. Livrables finaux du module

Le module final doit permettre de produire ou montrer :

- un cluster local de démonstration sur `kind`
- un service ML de scoring de fraude
- `v1`, `v2`, `v2-buggy`
- une démonstration de shadow
- une démonstration de canary manuel
- une démonstration blue-green
- une `AnalysisTemplate` branchée sur Prometheus
- un dashboard Grafana
- une démonstration d'abort automatique

---

## 8. Démonstrations prioritaires si le temps est limité

Si le temps est court, les démonstrations à garder en priorité sont :

1. rappel GitOps + Argo CD vs Argo Rollouts
2. shadow léger avec NGINX
3. canary manuel `10 -> 25 -> 50 -> 100`
4. abort automatique sur latence ou taux d'erreur

---

## 9. Message de conclusion

Le message final du module doit être :

> Dans un système ML, déployer une nouvelle version ne consiste pas à remplacer une image puis espérer que tout se passe bien. Il faut valider progressivement, observer avec des métriques fiables, limiter l'impact et pouvoir revenir rapidement à une version stable.

Et le message technique clé :

> Argo Rollouts orchestre la stratégie de déploiement progressive ; NGINX aide à gérer le trafic ; Prometheus et Grafana donnent la visibilité nécessaire pour décider.
