# Chapitre 2 : Déployer une première application avec ArgoCD

## Préface

Dans le chapitre précédent, vous avez construit la bonne carte mentale.

Vous savez maintenant :

- ce que signifie GitOps
- ce que signifie état désiré et état réel
- quel est le rôle exact d'ArgoCD
- comment le dépôt du projet est organisé

Nous allons maintenant passer à une première mise en pratique complète.

## De la théorie au cluster

Dans ce chapitre, l'objectif est très simple :

- préparer le projet
- créer un cluster léger
- installer ArgoCD
- lui faire suivre une première application

Ce passage est important, car c'est lui qui transforme une idée de synchronisation en comportement observable.

## Préparer le projet

Commencez par récupérer le dépôt :

```bash
git clone https://github.com/DataScientest/ArgoCD_Course.git
cd ArgoCD_Course
```

Puis initialisez l'environnement Python du projet :

```bash
make install
```

Créez ensuite votre fichier `.env` local :

```bash
cp service/.env.example service/.env
```

Valeur de départ :

```env
MODEL_VERSION=v1
```

Avant d'aller plus loin, vérifiez que le service est sain :

```bash
make status
```

Cette étape peut sembler secondaire, mais elle est importante. En MLOps, on évite de bâtir une chaîne de déploiement sur une base applicative incertaine.

## Créer le cluster léger

```bash
make kind-create
kubectl get nodes
```

Ici, `kind` nous sert de cluster local léger.

Le but n'est pas de simuler une grosse infrastructure.
Le but est d'avoir un support simple pour voir ArgoCD agir.

## Installer ArgoCD

Créez d'abord le namespace :

```bash
kubectl create namespace argocd
```

Puis installez ArgoCD :

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Vérifiez ensuite l'état des pods :

```bash
kubectl get pods -n argocd
```

Attendez qu'ils passent en `Running`.

## Accéder à l’interface

Lancez un port-forward :

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Puis ouvrez :

```txt
https://127.0.0.1:8080
```

## Récupérer le mot de passe admin initial

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

Login par défaut :

- utilisateur : `admin`
- mot de passe : valeur affichée

## Déclarer une première `Application`

Dans le dépôt, le dossier `k8s/argocd/` contient les objets propres à ArgoCD.

Dans ce chapitre, créez un fichier `k8s/argocd/application.yaml`.

Avant de regarder une écriture complète, essayez d'identifier ce qu'une `Application` doit connaître :

- le dépôt Git à suivre
- la révision à suivre
- le chemin des manifests
- le cluster cible
- le namespace cible

%%SOLUTION%%

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: support-priority-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/DataScientest/ArgoCD_Course.git
    targetRevision: HEAD
    path: k8s/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: fraud-detection
  syncPolicy:
    automated: {}
```

%%SOLUTION%%

## Appliquer l’Application

```bash
kubectl apply -f k8s/argocd/application.yaml
kubectl get applications -n argocd
```

## Ce qu’il faut observer

Dans l’interface ArgoCD ou via `kubectl`, regardez :

- le nom de l’application
- son état de synchronisation
- son état de santé

Les deux mots importants ici sont :

- `Synced`
- `Healthy`

Ils vous disent si Git et Kubernetes racontent la même histoire.

## Une lecture utile dans l’interface

Ouvrez l’application dans l’interface ArgoCD et observez la liste des ressources suivies.

Vous devez y retrouver la structure du projet :

- `Deployment`
- `Service`
- `Ingress`

Cela vous montre qu'ArgoCD ne suit pas une idée abstraite de l'application.
Il suit des objets Kubernetes concrets.

## Erreurs fréquentes

### 1. Mauvais chemin Git

Pour éviter cette erreur :

- vérifiez soigneusement le champ `path`

### 2. Namespace de destination absent

Pour éviter cette erreur :

- assurez-vous que la base Kubernetes du projet crée bien les objets au bon endroit

## Résumé

- ArgoCD peut être installé sur un cluster léger `kind`.
- Une `Application` relie un dépôt Git à un cluster cible.
- Les états `Synced` et `Healthy` sont les premiers indicateurs à savoir lire.

## Pour la suite

Dans le prochain chapitre, vous allez casser volontairement cet alignement pour observer un drift, puis voir comment ArgoCD peut le corriger.
