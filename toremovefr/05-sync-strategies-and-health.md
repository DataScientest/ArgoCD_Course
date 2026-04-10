# Chapitre 5 — Stratégies de synchronisation et santé des applications

---

## Le problème avec les syncs manuels

Dans le chapitre précédent, on a déclenché chaque sync manuellement. C'est bien pour apprendre, mais ça brise la promesse centrale de l'automatisation MLOps.

Réfléchissez : votre équipe réentraîne le modèle de détection de fraude chaque nuit. Le pipeline CI tourne, pousse une nouvelle image Docker, met à jour le tag dans Git. Et ensuite... rien. Parce que quelqu'un doit cliquer sur "Sync" le matin.

Ce n'est pas un pipeline — c'est un pense-bête. Corrigeons ça.

---

## Sync manuel vs. sync automatique

ArgoCD vous donne deux modes :

### Sync manuel
Vous contrôlez chaque déploiement. ArgoCD détecte le décalage et affiche **OutOfSync**, mais attend qu'un humain agisse.

**Quand l'utiliser en MLOps :**
- Déploiements de modèles en production où un humain doit approuver avant de passer en live
- Quand vous voulez valider des métriques sur staging avant de pousser en prod
- Pendant les incidents — vous voulez geler les déploiements pendant l'investigation

### Sync automatique
ArgoCD surveille votre dépôt Git et synchronise automatiquement à chaque changement détecté.

**Quand l'utiliser en MLOps :**
- Environnements de dev et staging — vous voulez que votre équipe voie le dernier modèle immédiatement
- Pipelines de réentraînement nocturne — nouveau modèle entraîné, CI met à jour le tag Git, ArgoCD déploie, aucun humain nécessaire
- Feature stores et pipelines de données où la fraîcheur est importante

---

## Activer le sync automatique

### Via le CLI

```bash
argocd app set fraud-detection --sync-policy automated
```

ArgoCD va maintenant interroger votre dépôt Git toutes les 3 minutes par défaut. Quand il détecte un nouveau commit (par exemple, un tag d'image mis à jour), il synchronise automatiquement.

### Via un fichier de configuration (recommandé)

Définir la politique de sync en YAML est préférable car c'est stocké dans Git — la politique elle-même est versionnée.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fraud-detection
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/votre-org/ml-platform
    targetRevision: HEAD
    path: models/fraud-detection
  destination:
    server: https://kubernetes.default.svc
    namespace: fraud-detection-dev
  syncPolicy:
    automated:
      prune: true       # supprimer les ressources retirées de Git
      selfHeal: true    # annuler les modifications manuelles du cluster
    syncOptions:
      - CreateNamespace=true   # créer le namespace s'il n'existe pas
```

---

## Deux options critiques : `prune` et `selfHeal`

### `prune: true`

En MLOps, on met souvent à jour nos configurations de déploiement — on retire des variables d'environnement obsolètes, on supprime des services inutilisés. Sans `prune`, les fichiers supprimés dans Git laissent des ressources orphelines qui continuent de tourner dans le cluster.

Avec `prune: true`, si vous supprimez `configmap.yaml` de Git (parce que vous avez migré la config vers un gestionnaire de secrets), ArgoCD supprimera aussi ce ConfigMap du cluster.

> N'activez `prune` que lorsque votre dépôt Git est une image complète et exacte de tout ce que vous voulez faire tourner. Ne l'activez jamais sur un setup en cours de migration.

### `selfHeal: true`

Imaginez qu'un collègue modifie manuellement le déploiement de détection de fraude dans le cluster — peut-être qu'il augmente les limites mémoire pour déboguer un problème OOM. Sans `selfHeal`, cette modification manuelle persiste et votre cluster diverge silencieusement de Git.

Avec `selfHeal: true`, ArgoCD détecte le décalage et ramène le cluster à l'état Git en quelques minutes.

> C'est la garantie GitOps stricte : **aucun changement n'atteint la production sans passer par Git.** C'est exactement ce qu'adorent les équipes d'audit et les cadres de conformité.

---

## Comprendre la santé dans un contexte ML

Après une synchronisation, ArgoCD évalue la **santé**. Pour un service d'inférence ML, la santé va au-delà de "est-ce que ça tourne ?"

| Statut | Ce que ça veut dire pour notre service de détection de fraude |
|---|---|
| `Healthy` | Tous les pods d'inférence sont actifs, passent les probes de disponibilité, acceptent les requêtes |
| `Progressing` | La nouvelle image du modèle est en cours de téléchargement, les pods redémarrent — c'est normal pendant une mise à jour |
| `Degraded` | Les pods crashent — causes possibles : OOM (modèle trop grand pour la limite mémoire), mauvais démarrage, fichier de modèle introuvable |
| `Missing` | Le déploiement a été supprimé — ArgoCD avec `selfHeal` va le recréer |
| `Unknown` | Problème de connectivité avec le cluster |

---

## Configurer les probes de disponibilité et de vivacité

Un service d'inférence vraiment en bonne santé n'est pas juste "en train de tourner" — il doit être *prêt à servir des prédictions*. Ajoutons des probes correctes à notre déploiement :

```yaml
containers:
- name: inference-server
  image: mon-registry/fraud-model:v3.2
  readinessProbe:
    httpGet:
      path: /health     # votre API d'inférence doit exposer ce endpoint
      port: 8080
    initialDelaySeconds: 30    # laisser le temps au modèle de se charger
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 60    # délai plus long — le chargement du modèle peut être lent
    periodSeconds: 30
```

> **Pourquoi c'est crucial en MLOps :** Les grands modèles (transformers, LLMs) peuvent mettre 30 à 120 secondes à se charger en mémoire. Sans un `initialDelaySeconds` adapté, Kubernetes va tuer et redémarrer le pod en boucle avant même que le modèle ait eu le temps de se charger. On voit ça constamment sur le terrain.

Le statut de santé ArgoCD sera `Progressing` jusqu'à ce que la probe de disponibilité passe — ce qui est le comportement correct.

---

## Simuler la boucle automatisée complète

Voici à quoi ressemble la boucle de déploiement MLOps automatisée complète :

```
1. La CI réentraîne fraud-model, pousse fraud-model:v3.3 vers le registre
2. La CI met à jour deployment.yaml dans Git : tag image → v3.3
3. ArgoCD détecte le changement Git dans les 3 minutes
4. ArgoCD synchronise : demande à Kubernetes de déployer fraud-model:v3.3
5. Kubernetes démarre les nouveaux pods avec v3.3, attend la probe de disponibilité
6. Une fois la probe passée, les anciens pods v3.2 sont arrêtés
7. ArgoCD rapporte Healthy
```

Aucun humain nécessaire après les étapes 1 et 2. C'est la puissance de ce setup.

---

## Les erreurs fréquentes à ce stade

- **Activer le sync auto en production sans portes d'approbation.** En MLOps, vous voulez souvent qu'un humain valide les métriques A/B avant de promouvoir vers 100% du trafic. Utilisez le sync manuel en prod, le sync auto en dev/staging.
- **Oublier `initialDelaySeconds` pour le chargement du modèle.** Les grands modèles ont besoin de temps pour se charger en mémoire. Sans ça, Kubernetes va crash-looper vos pods.
- **Activer `prune` avant que votre dépôt soit complet.** Si votre dépôt ne contient qu'une partie de vos ressources, `prune` supprimera celles qui n'y sont pas.

---

## Résumé

- Le **sync manuel** vous donne le contrôle des déploiements — adapté à la production.
- Le **sync automatique** automatise la boucle MLOps complète — adapté au dev et au staging.
- `prune` impose Git comme source de vérité complète. `selfHeal` empêche la dérive manuelle.
- Des **probes de disponibilité** correctes sont critiques pour les services ML — les modèles ont besoin de temps pour se charger.

---

## La suite

Vous savez déployer et auto-synchroniser un seul modèle. Dans le prochain chapitre, on va structurer une vraie plateforme MLOps avec plusieurs environnements — dev, staging, et production — chacun faisant tourner des versions différentes de nos modèles, tout ça géré depuis un seul dépôt Git.
