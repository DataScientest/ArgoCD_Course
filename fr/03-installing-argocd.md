# Chapitre 3 — Installer ArgoCD

---

## Ce dont on a besoin pour commencer

Avant d'installer ArgoCD, on a besoin d'un cluster Kubernetes. Pour ce cours, on va utiliser **kind** — un outil qui fait tourner un cluster Kubernetes dans des conteneurs Docker sur votre machine locale.

Puisque vous connaissez déjà Docker, c'est un point de départ naturel. Pas besoin de compte cloud, pas de mauvaises surprises de facturation.

> **kind** signifie "Kubernetes IN Docker". C'est léger, facile à mettre en place, et parfait pour apprendre et expérimenter en local.

Vous aurez aussi besoin de **kubectl** — l'outil en ligne de commande pour parler à Kubernetes. Pensez-y comme le CLI `docker`, mais pour Kubernetes.

---

## Étape 1 — Installer kubectl

```bash
# Sur Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

```bash
# Sur macOS
brew install kubectl
```

Vérifiez :
```bash
kubectl version --client
```

---

## Étape 2 — Installer kind

```bash
# Sur Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

```bash
# Sur macOS
brew install kind
```

Vérifiez :
```bash
kind version
```

---

## Étape 3 — Créer un cluster Kubernetes local

Créons un cluster avec un nom parlant pour ce qu'on va en faire :

```bash
kind create cluster --name mlops-argocd
```

Cette commande :
1. Télécharge une image Docker contenant une installation complète de Kubernetes
2. La démarre en tant que conteneur sur votre machine
3. Configure automatiquement `kubectl` pour pointer vers ce nouveau cluster

Ça prend environ une minute. Une fois terminé, vérifiez que votre cluster tourne :

```bash
kubectl cluster-info --context kind-mlops-argocd
```

Vous devriez voir :
```
Kubernetes control plane is running at https://127.0.0.1:XXXXX
```

Vous avez maintenant un vrai cluster Kubernetes qui tourne en local — dans un conteneur Docker. C'est là qu'on déploiera nos services ML.

---

## Étape 4 — Installer ArgoCD

ArgoCD tourne à l'intérieur de votre cluster Kubernetes. On l'installe en appliquant des fichiers de configuration officiels de l'équipe ArgoCD.

D'abord, créez un namespace dédié pour ArgoCD :

```bash
kubectl create namespace argocd
```

> **Rappel namespace :** Pensez-y comme un dossier dédié appelé `argocd` dans votre cluster. Tous les composants d'ArgoCD vivront là — séparés de vos workloads ML.

Ensuite, installez ArgoCD :

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/install.yaml
```

Cette commande applique un grand fichier de configuration qui demande à Kubernetes de faire tourner tous les composants d'ArgoCD : son serveur API, son contrôleur d'applications, son serveur de dépôts, son cache Redis, et plus encore.

Attendez que tout soit prêt :

```bash
kubectl wait --for=condition=available --timeout=180s deployment --all -n argocd
```

Cette commande se met en pause jusqu'à ce que tous les composants d'ArgoCD soient prêts. Ça peut prendre 2 à 3 minutes au premier lancement, le temps de télécharger les images.

---

## Étape 5 — Accéder à l'interface web d'ArgoCD

ArgoCD est livré avec une interface web. Pour y accéder depuis votre machine, on redirige un port local vers le serveur ArgoCD :

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

> **La redirection de port** crée un tunnel depuis le port `8080` de votre machine vers l'intérieur du cluster. Gardez ce terminal ouvert pendant que vous utilisez l'interface — si vous le fermez, l'interface devient inaccessible.

Ouvrez votre navigateur et allez sur : **https://localhost:8080**

Votre navigateur va vous avertir d'un certificat non fiable — c'est normal en local. Cliquez pour continuer quand même.

---

## Étape 6 — Se connecter

Le nom d'utilisateur par défaut est `admin`. Récupérez le mot de passe généré automatiquement :

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode
```

Copiez la valeur — c'est votre mot de passe. Connectez-vous avec :
- **Utilisateur :** `admin`
- **Mot de passe :** (la valeur que vous venez de copier)

Vous devriez maintenant voir le tableau de bord ArgoCD. Vide pour l'instant — on le remplira dans le prochain chapitre.

> **Note de sécurité pour les équipes MLOps :** Dans un vrai contexte d'équipe, vous changeriez le mot de passe admin immédiatement et configureriez le SSO (GitHub, Google, LDAP). Pour ce cours, on garde ça simple.

---

## Étape 7 — Installer le CLI ArgoCD

Le CLI vous permet d'interagir avec ArgoCD depuis votre terminal — plus rapide que l'interface pour beaucoup d'opérations, et plus facile à scripter.

```bash
# Sur Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/argocd
```

```bash
# Sur macOS
brew install argocd
```

Connectez-vous via le CLI :

```bash
argocd login localhost:8080 --insecure
```

Utilisez les mêmes identifiants `admin`. Le flag `--insecure` est nécessaire parce qu'on utilise un certificat auto-signé en mode local.

---

## Les erreurs fréquentes à ce stade

- **Oublier de garder la redirection de port active.** Si vous fermez le terminal qui fait tourner `kubectl port-forward`, l'interface et le CLI deviennent inaccessibles. Relancez simplement la commande.
- **Utiliser le mauvais namespace.** ArgoCD vit dans le namespace `argocd`. Ajoutez toujours `-n argocd` aux commandes `kubectl` qui ciblent ArgoCD lui-même. Vos workloads ML iront dans des namespaces séparés.
- **Paniquer face à l'avertissement de certificat.** L'avertissement du navigateur est normal en développement local. Ça ne signifie pas que quelque chose est cassé.

---

## Résumé

- **kind** nous permet de faire tourner un vrai cluster Kubernetes en local grâce à Docker.
- ArgoCD s'installe dans ce cluster via `kubectl apply`.
- On accède à l'interface web via la redirection de port sur `https://localhost:8080`.
- Identifiants par défaut : `admin` / (mot de passe récupéré depuis le secret Kubernetes).

---

## La suite

Notre ArgoCD est installé et opérationnel. Dans le prochain chapitre, on créera notre toute première Application ArgoCD — en connectant un dépôt Git à notre cluster et en regardant ArgoCD déployer un service d'inférence ML automatiquement.
