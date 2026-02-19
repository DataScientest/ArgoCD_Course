# Chapitre 4 — Votre première Application ArgoCD

---

## Ce qu'on construit aujourd'hui

À la fin de ce chapitre, vous aurez un vrai service d'inférence ML qui tourne dans Kubernetes — déployé et géré par ArgoCD depuis un dépôt Git.

On va simuler un scénario MLOps réaliste : un modèle de détection de fraude exposé comme une API REST, décrit dans Git, et déployé automatiquement par ArgoCD. Le modèle en lui-même est un placeholder — l'objectif, c'est de comprendre le flux de déploiement complet.

---

## La structure du dépôt Git qu'on va utiliser

Pour qu'ArgoCD puisse déployer quelque chose, on a besoin d'un dépôt Git avec des fichiers de configuration Kubernetes. On va utiliser le dépôt d'exemples officiel d'ArgoCD :

```
https://github.com/argoproj/argocd-example-apps
```

On va travailler avec l'app `guestbook` comme substitut d'un service d'inférence pour la détection de fraude. Dans vos vrais projets MLOps, ce dossier contiendrait des fichiers comme :

```
fraud-detection/
├── deployment.yaml    ← quelle image Docker, combien de réplicas, limites de ressources
├── service.yaml       ← comment exposer l'API d'inférence
└── configmap.yaml     ← variables d'environnement (chemin du modèle, seuil, etc.)
```

---

## Comprendre les fichiers qu'ArgoCD va lire

Avant de déployer, voyons ce que `deployment.yaml` fait dans le contexte d'un service ML :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fraud-detection-api
spec:
  replicas: 2                         # faire tourner 2 instances pour la redondance
  selector:
    matchLabels:
      app: fraud-detection
  template:
    spec:
      containers:
      - name: inference-server
        image: mon-registry/fraud-model:v3.2   # ← c'est ce que la CI met à jour
        resources:
          requests:
            memory: "2Gi"             # RAM minimale pour notre modèle
            cpu: "500m"
          limits:
            memory: "4Gi"             # le modèle ne dépassera pas ça
            cpu: "1"
        ports:
        - containerPort: 8080         # l'API écoute ici
```

ArgoCD lit ce fichier depuis Git et l'applique à Kubernetes. Quand votre pipeline CI change le tag de l'image de `v3.2` à `v3.3`, ArgoCD détecte la différence et ré-applique.

---

## Étape 1 — Créer l'Application via l'interface web

Assurez-vous que votre redirection de port tourne :

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Ouvrez **https://localhost:8080** et connectez-vous.

1. Cliquez sur **"+ New App"** (en haut à gauche)
2. Remplissez le formulaire :

| Champ | Valeur |
|---|---|
| Application Name | `fraud-detection` |
| Project | `default` |
| Sync Policy | `Manual` (pour l'instant) |

3. Sous **Source** :

| Champ | Valeur |
|---|---|
| Repository URL | `https://github.com/argoproj/argocd-example-apps` |
| Revision | `HEAD` |
| Path | `guestbook` |

4. Sous **Destination** :

| Champ | Valeur |
|---|---|
| Cluster URL | `https://kubernetes.default.svc` |
| Namespace | `fraud-detection-dev` |

5. Cliquez sur **"Create"**.

> On utilise un namespace dédié `fraud-detection-dev` — bonne pratique en MLOps pour isoler chaque modèle et chaque environnement.

Créez d'abord le namespace :

```bash
kubectl create namespace fraud-detection-dev
```

---

## Étape 2 — Comprendre le statut OutOfSync

Après la création, vous verrez la carte de votre app dans le tableau de bord avec le statut **OutOfSync**.

Ce n'est pas une erreur. Ça veut dire :
- Git dit que le service `fraud-detection` devrait exister (état souhaité)
- Le namespace `fraud-detection-dev` est vide (état réel)
- Ils ne correspondent pas → OutOfSync

C'est exactement ce qu'on veut voir avant un premier déploiement.

---

## Étape 3 — Synchroniser l'Application

Cliquez sur la carte de votre app pour ouvrir la vue détaillée.

Cliquez sur **"Sync"**, puis **"Synchronize"** dans le panneau de confirmation.

ArgoCD va :
1. Lire les fichiers YAML depuis le dépôt Git
2. Les appliquer dans le namespace `fraud-detection-dev` de Kubernetes
3. Kubernetes va télécharger l'image Docker et démarrer les pods

Observez le graphe de l'app se mettre à jour en temps réel — vous verrez le deployment, le service et le replicaset apparaître un par un.

Au bout d'une minute environ, le statut passe à **Synced** et **Healthy**.

---

## Étape 4 — Faire la même chose via le CLI

Le CLI, c'est ce qu'on utilisera dans les vrais pipelines CI/CD et les scripts. Entraînons-nous.

Supprimez l'app que vous venez de créer via l'interface, puis lancez :

```bash
# Créer le namespace
kubectl create namespace fraud-detection-dev

# Créer l'Application ArgoCD
argocd app create fraud-detection \
  --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace fraud-detection-dev
```

Chaque option correspond à un champ de l'interface :
- `--repo` → l'URL du dépôt Git
- `--path` → le dossier dans le dépôt qui contient nos fichiers de config
- `--dest-server` → quel cluster Kubernetes cibler
- `--dest-namespace` → quel namespace dans ce cluster

Synchronisez :
```bash
argocd app sync fraud-detection
```

Vérifiez le statut :
```bash
argocd app get fraud-detection
```

Vous devriez voir :
```
Name:               argocd/fraud-detection
Sync Status:        Synced to HEAD
Health Status:      Healthy
```

---

## Étape 5 — Simuler une mise à jour de modèle

C'est le moment MLOps vers lequel on construisait tout. Simulons ce qui se passe quand votre pipeline CI pousse une nouvelle version du modèle.

Dans un vrai setup, votre CI mettrait à jour le tag de l'image dans `deployment.yaml` automatiquement. Ici, on le fait manuellement pour observer le comportement :

```bash
# Vérifier le tag d'image actuel
argocd app get fraud-detection --output json | grep image

# Imaginez maintenant que la CI a poussé fraud-model:v3.3 dans le registre
# et mis à jour deployment.yaml dans Git de v3.2 à v3.3
# ArgoCD détecterait OutOfSync, et vous re-synchroniseriez :
argocd app sync fraud-detection
```

C'est la boucle centrale qu'on va automatiser au chapitre 5.

---

## Étape 6 — Vérifier le déploiement

Vérifiez que les pods tournent :

```bash
kubectl get pods -n fraud-detection-dev
```

Vous devriez voir des pods avec le statut `Running`. Consultez les événements si quelque chose semble anormal :

```bash
kubectl describe pod <nom-du-pod> -n fraud-detection-dev
```

---

## Les erreurs fréquentes à ce stade

- **Utiliser le mauvais namespace de destination.** Créez toujours le namespace avant de créer l'Application, ou activez `CreateNamespace=true` dans vos options de sync.
- **S'attendre à appeler l'API immédiatement.** Le service tourne dans le cluster mais n'est pas encore exposé vers l'extérieur. On abordera l'exposition des services dans des chapitres ultérieurs.
- **Synchroniser avant que le namespace existe.** ArgoCD retournera une erreur. Créez toujours les namespaces de destination en premier.

---

## Résumé

- Une Application ArgoCD connecte un chemin dans un dépôt Git à un namespace Kubernetes.
- **OutOfSync** = l'état souhaité diffère de l'état réel — c'est normal avant un premier sync.
- **Synchroniser** applique l'état Git au cluster et démarre vos pods d'inférence.
- Vous pouvez créer et gérer des Applications via l'interface ou le CLI — les deux sont valides.

---

## La suite

Votre service d'inférence tourne. Mais vous avez déclenché le sync manuellement. Dans le prochain chapitre, on va automatiser ça — ArgoCD synchronisera automatiquement dès que votre pipeline CI mettra à jour le tag de l'image dans Git. C'est la boucle de déploiement MLOps complète.
