# Chapitre 8 — Troubleshooting : quoi faire quand ça se passe mal

---

## La réalité du MLOps en production

À un moment, quelque chose va casser.

Un déploiement va rester bloqué. Un modèle va échouer son health check. ArgoCD affichera `OutOfSync` un lundi matin sans raison évidente. Votre service de détection de fraude arrêtera de répondre et une alerte vous réveillera.

Ce n'est pas le signe que vous avez fait quelque chose de mal. C'est la condition de fonctionnement normale de tout système en production. Ce qui distingue un ingénieur MLOps serein d'un ingénieur MLOps stressé, ce n'est pas que les choses cassent ou non — c'est de savoir exactement où regarder et quoi faire.

Ce chapitre est une référence pratique. On va passer en revue les problèmes les plus fréquents que vous rencontrerez avec ArgoCD et des services d'inférence sur Kubernetes, avec une approche de diagnostic concrète pour chacun.

---

## Le modèle mental : chaque panne a une couche

Quand quelque chose ne va pas, pensez en couches :

```
Couche 1 : ArgoCD lui-même         → ArgoCD est-il conscient du problème ?
Couche 2 : Objets Kubernetes       → Les manifests ont-ils été appliqués correctement ?
Couche 3 : Pod / conteneur         → Le conteneur tourne-t-il ?
Couche 4 : Application             → Le modèle répond-il ?
```

Commencez toujours par la couche 1 et descendez. Sauter à la couche 3 alors que la couche 2 a un manifest mal configuré fait perdre du temps.

---

## Les premières commandes à exécuter

Quand quelque chose ne va pas, ces quatre commandes vous donnent une vue complète en moins de deux minutes :

```bash
# 1. Qu'est-ce qu'ArgoCD pense qu'il se passe ?
argocd app get fraud-detection-production

# 2. Quels objets sont en mauvais état dans Kubernetes ?
kubectl get pods -n fraud-detection-production

# 3. Pourquoi un pod ne tourne pas ?
kubectl describe pod <nom-du-pod> -n fraud-detection-production

# 4. Que logue réellement le conteneur ?
kubectl logs <nom-du-pod> -n fraud-detection-production --tail=100
```

Exécutez-les dans l'ordre. Ne sautez pas d'étapes.

---

## Problème type 1 : application bloquée en `OutOfSync`

**Ce que vous voyez dans l'interface ArgoCD :** L'application affiche `OutOfSync` et ne se corrige pas d'elle-même, même après une synchronisation manuelle.

**Ce que ça signifie généralement :** Il y a une différence entre ce qui est dans Git et ce qui tourne dans le cluster — mais ArgoCD n'arrive pas à appliquer le changement, ou bien une ressource est gérée en dehors de Git.

### Diagnostiquer

```bash
argocd app diff fraud-detection-production
```

Cette commande vous montre le diff exact entre Git et l'état en live dans le cluster — comme `git diff` mais pour l'état Kubernetes. Lisez-le attentivement. Le diff vous pointera presque toujours directement vers le problème.

Causes fréquentes que vous verrez dans le diff :

| Ce que vous voyez | Ce que ça signifie |
|---|---|
| `image: my-registry/fraud-model:v3.2` dans le cluster vs `v3.3` dans Git | Quelqu'un a mis à jour l'image manuellement (`kubectl set image`) — dérive ArgoCD |
| Une ressource entière absente de Git | La ressource a été créée directement dans le cluster sans manifest |
| Un écart sur `resourceVersion` | Généralement sans conséquence — ArgoCD le résoudra à la prochaine sync |

### Corriger

Si la dérive était intentionnelle (un hotfix appliqué manuellement pendant un incident), mettez d'abord Git en phase avec le cluster, puis laissez ArgoCD tout gérer à partir de là.

Si la dérive est accidentelle, synchronisez et laissez ArgoCD écraser :

```bash
argocd app sync fraud-detection-production --force
```

> `--force` indique à ArgoCD d'écraser tout état en conflit dans le cluster par ce qui est dans Git. Utilisez cette option quand vous êtes certain que Git est la source de vérité.

---

## Problème type 2 : pods bloqués en `Pending`

**Ce que vous voyez :** `kubectl get pods` montre un ou plusieurs pods en état `Pending`. Ils ne démarrent jamais.

**Ce que ça signifie :** Kubernetes a accepté la spécification du pod mais ne peut pas le placer sur un nœud. Il attend des ressources.

### Diagnostiquer

```bash
kubectl describe pod <nom-du-pod> -n fraud-detection-production
```

Faites défiler jusqu'à la section `Events` en bas du résultat. Le message vous dira exactement pourquoi :

```
Events:
  Warning  FailedScheduling  30s   default-scheduler
    0/3 nodes are available: 3 Insufficient memory.
```

Cela signifie qu'aucun nœud du cluster n'a assez de mémoire pour placer ce pod.

### Causes fréquentes pour les workloads d'inférence

- **Modèle trop volumineux.** Un modèle de détection de fraude chargé en mémoire peut nécessiter 8 à 16 Go. Si vos nœuds n'ont que 4 Go de mémoire allouable, le pod ne peut pas démarrer.
- **Requests de ressources trop élevées.** Vérifiez votre manifest :

```yaml
resources:
  requests:
    memory: "16Gi"   # ← est-ce réaliste par rapport à la taille de vos nœuds ?
    cpu: "4"
```

- **Node selector ou règles d'affinité bloquant le placement.** Si vous avez ajouté des sélecteurs de nœuds GPU (`nvidia.com/gpu: "1"`) et qu'aucun nœud GPU n'existe, le pod restera en attente.

### Corriger

Ajustez vos requests de ressources pour correspondre à ce que vos nœuds peuvent réellement fournir, ou scalez votre cluster. Ne supprimez pas les requests de ressources — elles protègent les autres workloads sur le même nœud.

---

## Problème type 3 : pods en `CrashLoopBackOff`

**Ce que vous voyez :** Un pod démarre, plante, Kubernetes le redémarre, il plante à nouveau. Kubernetes augmente le temps d'attente entre les redémarrages de façon exponentielle. Le statut affiche `CrashLoopBackOff`.

**Ce que ça signifie :** Le conteneur démarre correctement (l'image a bien été téléchargée), mais le processus à l'intérieur plante immédiatement après le lancement.

### Diagnostiquer

```bash
kubectl logs <nom-du-pod> -n fraud-detection-production --previous
```

`--previous` est essentiel ici. Cette option vous montre les logs de l'*exécution précédente* du conteneur — celle qui a planté. Sans elle, vous voyez les logs de l'exécution en cours (qui plante aussi), souvent presque vide.

### Causes fréquentes pour les services d'inférence MLOps

- **Fichier modèle introuvable.** Le conteneur démarre, essaie de charger le modèle depuis un chemin comme `/models/fraud-model-v3.3.pkl`, mais le fichier n'est pas là. Vérifiez vos montages de volumes et vos chemins d'artefacts.
- **Variable d'environnement incorrecte.** Beaucoup de serveurs d'inférence lisent leur configuration depuis des variables d'environnement (`MODEL_PATH`, `PORT`, `WORKERS`). Une variable manquante ou mal configurée provoque un crash au démarrage.
- **Incompatibilité de dépendances.** L'image du conteneur a été construite avec Python 3.9, mais le modèle a été sérialisé avec Python 3.11. Ou la version de `scikit-learn` a changé entre l'entraînement et le service.
- **Mémoire insuffisante lors du chargement du modèle.** Le modèle est trop volumineux pour la limite mémoire du conteneur. L'OS tue le processus (OOM Kill). Vérifiez :

```bash
kubectl describe pod <nom-du-pod> -n fraud-detection-production | grep -A5 "Last State"
```

Si vous voyez `Reason: OOMKilled`, le conteneur a manqué de mémoire.

### Corriger

Lisez attentivement les logs de crash. Le message d'erreur dans les logs est presque toujours la cause directe. Corrigez le problème sous-jacent (chemin du modèle, variable d'environnement, dépendance d'image), mettez à jour votre manifest ou votre image Docker, committez dans Git, et laissez ArgoCD synchroniser.

---

## Problème type 4 : ArgoCD affiche une santé `Degraded`

**Ce que vous voyez :** La santé de l'application affiche `Degraded` — ni `Synced`, ni `Healthy`.

**Ce que ça signifie :** ArgoCD a bien appliqué les manifests, mais une ou plusieurs ressources Kubernetes signalent un état non sain. Le plus souvent, un Deployment indique que ses pods ne sont pas tous prêts.

### Diagnostiquer

```bash
argocd app get fraud-detection-production
```

Regardez la liste des ressources dans le résultat. L'une d'elles affichera `Degraded`. Notez son type et son nom, puis investigez directement :

```bash
kubectl rollout status deployment/fraud-detection-api -n fraud-detection-production
```

Si le rollout est bloqué :

```bash
kubectl describe deployment fraud-detection-api -n fraud-detection-production
```

La section `Conditions` vous dira ce qui bloque le rollout — généralement une probe de readiness en échec ou des répliques indisponibles.

### Le lien avec la readiness probe

ArgoCD utilise la **readiness probe** pour déterminer la santé. Si votre serveur d'inférence met 60 secondes à charger un modèle mais que votre readiness probe commence à vérifier après 10 secondes, chaque pod échouera sa probe et ArgoCD signalera `Degraded`.

Correction : adaptez votre `initialDelaySeconds` au temps de chargement réel de votre modèle :

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 60    # laissez le temps au modèle de se charger
  periodSeconds: 10
  failureThreshold: 3
```

---

## Problème type 5 : la sync réussit mais le modèle est mauvais

**Ce que vous voyez :** ArgoCD affiche `Synced` et `Healthy`. Les pods tournent. Mais les prédictions sont incorrectes, ou vous obtenez des réponses inattendues.

**Ce que ça signifie :** L'infrastructure est saine. Le problème se situe à la couche applicative — le modèle lui-même, sa configuration, ou les données qu'il reçoit.

C'est la catégorie la plus délicate, car ArgoCD ne la détectera pas. Le système a l'air sain pour tout outil d'infrastructure.

### Diagnostiquer

Commencez par confirmer quelle version tourne réellement :

```bash
kubectl get pods -n fraud-detection-production -o jsonpath='{.items[*].spec.containers[*].image}'
```

Cette commande affiche le tag d'image réellement en cours dans vos pods. Comparez-le à ce que vous attendez depuis Git.

Puis sondez le modèle directement :

```bash
# Port-forward vers le pod pour tester en local
kubectl port-forward pod/<nom-du-pod> 8080:8080 -n fraud-detection-production

# Envoyer une requête d'inférence de test
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"transaction_amount": 4500, "merchant_category": "online", "hour_of_day": 3}'
```

Examinez la réponse. Si la prédiction est incorrecte, le problème vient du modèle ou du prétraitement des features, pas de l'infrastructure.

### Endpoints de diagnostic utiles à intégrer dans tout service d'inférence

| Endpoint | Ce qu'il doit retourner |
|---|---|
| `GET /health` | `{"status": "ok"}` — utilisé par les readiness probes |
| `GET /version` | `{"model": "fraud-model", "version": "v3.3", "trained_at": "2026-01-15"}` |
| `GET /metrics` | Métriques Prometheus — nombre de prédictions, histogrammes de latence, taux d'erreur |

Si vous avez un endpoint `/version`, vous pouvez toujours confirmer exactement quel artefact de modèle répond aux requêtes.

---

## Problème type 6 : ArgoCD lui-même ne fonctionne plus

**Ce que vous voyez :** Vous n'arrivez pas à accéder à l'interface ArgoCD, ou les commandes `argocd` expirent.

### Vérifier les composants ArgoCD

```bash
kubectl get pods -n argocd
```

Tous les pods doivent être en état `Running`. Les composants clés sont :

```
argocd-server                  ← interface et API
argocd-application-controller  ← surveille Git et le cluster
argocd-repo-server             ← clone les dépôts Git et génère les manifests
argocd-redis                   ← couche de cache
```

Si l'un de ces pods est en `CrashLoopBackOff` ou `Pending`, diagnostiquez-le comme n'importe quel autre pod — `describe` et `logs`.

### Consulter les logs ArgoCD pour les erreurs de sync

```bash
kubectl logs deployment/argocd-application-controller \
  -n argocd \
  --tail=50
```

C'est ici que vous trouverez les erreurs comme les échecs d'authentification Git, les erreurs de rendu Helm, ou les timeouts réseau lors de l'accès à votre registre d'images.

---

## Le journal des opérations de sync ArgoCD

Chaque opération de sync dans ArgoCD est journalisée. Quand une sync échoue, c'est le premier endroit où regarder :

```bash
argocd app sync-windows fraud-detection-production
```

Ou dans l'interface : Application → Sync Status → cliquer sur la sync échouée → lire le journal d'opération.

Le journal d'opération vous dira exactement quelle ressource n'a pas pu être appliquée et pourquoi — généralement une erreur de validation dans votre YAML ou un namespace manquant.

---

## Référence rapide : commandes de diagnostic

```bash
# État de l'application ArgoCD
argocd app get <nom-app>
argocd app diff <nom-app>
argocd app history <nom-app>

# Forcer une sync depuis Git
argocd app sync <nom-app> --force

# État des pods Kubernetes
kubectl get pods -n <namespace>
kubectl describe pod <nom-pod> -n <namespace>
kubectl logs <nom-pod> -n <namespace> --tail=100
kubectl logs <nom-pod> -n <namespace> --previous   # logs du conteneur crashé

# État du déploiement Kubernetes
kubectl rollout status deployment/<nom> -n <namespace>
kubectl rollout history deployment/<nom> -n <namespace>

# Rollback d'urgence (niveau Kubernetes, contourne ArgoCD)
kubectl rollout undo deployment/<nom> -n <namespace>

# État Argo Rollouts (si vous utilisez canary/blue-green)
kubectl argo-rollouts get rollout <nom> -n <namespace> --watch
kubectl argo-rollouts abort <nom> -n <namespace>
kubectl argo-rollouts promote <nom> -n <namespace>
```

> **Important :** `kubectl rollout undo` est une mesure d'urgence. Elle contourne Git et crée de la dérive. Après l'avoir utilisée, mettez immédiatement à jour votre manifest Git pour refléter l'état restauré afin qu'ArgoCD puisse reprendre la main.

---

## Erreurs fréquentes à ce stade

- **Lire les logs du conteneur actuel plutôt qu'avec `--previous`.** Si un conteneur est en `CrashLoopBackOff`, le conteneur actuel vient de démarrer et ses logs sont presque vides. Utilisez toujours `--previous` pour voir le crash.
- **Ignorer la section `Events` dans `kubectl describe`.** Cette section contient les informations de diagnostic les plus utiles que Kubernetes fournit. Elle se trouve en bas du résultat et est facile à manquer.
- **Corriger le symptôme plutôt que la cause.** Si ArgoCD signale `OutOfSync` parce que quelqu'un a patché le cluster manuellement, la solution n'est pas de désactiver la détection de dérive — c'est de mettre le bon manifest dans Git.
- **Utiliser `--force` sur `argocd app sync` par habitude.** Cette option supprime l'état en live et le remplace par Git. Utilisée sans précaution, elle peut effacer une configuration légitime. Réservez-la pour les cas où vous êtes certain que Git est correct.
- **Ne pas configurer `initialDelaySeconds` pour le chargement du modèle.** Les modèles ML prennent du temps à se désérialiser depuis le disque. Sans un délai approprié, la readiness probe échouera systématiquement et votre déploiement n'atteindra jamais l'état `Healthy`.

---

## Résumé

- Pensez en couches : ArgoCD → Kubernetes → Pod → Application. Diagnostiquez de haut en bas.
- `argocd app diff` vous montre exactement ce qui diffère entre Git et le cluster.
- `kubectl describe pod` et `kubectl logs --previous` sont vos outils les plus importants au niveau pod.
- La santé `Degraded` signifie généralement un échec de readiness probe — adaptez le timing de votre probe au temps de chargement de votre modèle.
- ArgoCD ne détecte pas les pannes au niveau applicatif. Construisez toujours des endpoints `/health`, `/version` et `/metrics` dans vos services d'inférence.

---

## Et maintenant ?

Vous disposez maintenant d'un kit ArgoCD complet pour le MLOps : des premiers principes à l'installation et la configuration d'ArgoCD, en passant par le déploiement dans plusieurs environnements, la mise en œuvre de stratégies de déploiement adaptées à la production, et la capacité à récupérer sereinement quand quelque chose se passe mal.

La prochaine étape, c'est d'appliquer tout cela à votre propre infrastructure — définir la structure de votre dépôt Git, écrire votre premier manifest Application, et déployer un vrai modèle. Les patterns de ce cours vous donnent tout ce qu'il vous faut pour commencer.
