# Chapitre 3 : Shadow avec NGINX Ingress

## Préface

Dans le chapitre précédent, vous avez découvert les grandes stratégies de progressive delivery.

Vous savez maintenant :

- ce que signifie `shadow`
- ce que signifie `canary`
- ce que signifie `blue-green`
- pourquoi un service ML demande une validation progressive

Nous allons maintenant commencer par la stratégie la moins risquée : le **shadow**.

## Pourquoi ce chapitre compte

Quand vous n'avez pas encore confiance dans une nouvelle version, vous voulez l'observer sans l'exposer vraiment.

C'est exactement le rôle du shadow.

## La philosophie derrière

Imaginez un stagiaire qui suit un expert pendant une journée.

- l'expert continue à faire le vrai travail
- le stagiaire reçoit les mêmes cas
- mais ce n'est pas sa réponse qui est envoyée au client

Le shadow fonctionne de cette façon.

## À quoi sert le shadow

Le shadow permet de :

- garder la réponse utilisateur sur la version stable
- envoyer une copie du trafic à la nouvelle version
- observer le comportement du challenger sans risque direct pour l'utilisateur

## Rôle de NGINX Ingress

Dans ce module, le shadow repose sur la couche trafic.

Autrement dit, ce n'est pas Argo Rollouts qui fait tout ici.

Le rôle de **NGINX Ingress** est de :

- recevoir le trafic entrant
- envoyer la requête normale vers le service principal
- copier cette requête vers le service challenger

Cette copie du trafic s'appelle souvent du **mirroring**.

## Shadow et canary : différence immédiate

Il est important de bien les distinguer.

### Shadow

- la nouvelle version reçoit une copie du trafic
- l'utilisateur ne voit pas sa réponse

### Canary

- une partie du vrai trafic utilisateur est servie par la nouvelle version
- l'utilisateur peut donc réellement voir son comportement

## Ce qu'il faut mesurer

Pendant un shadow, vous pouvez observer :

- la latence du challenger
- le taux d'erreur
- la stabilité du service
- les logs par version

Dans un service ML, il est aussi très utile de tracer `model_version` dans les logs et les métriques.

## Limites du shadow

Le shadow est très utile.
Mais il ne répond pas à tout.

Il a plusieurs limites :

- il ne valide pas complètement l'expérience utilisateur
- il ne montre pas encore comment la nouvelle version se comporte face à de vrais retours visibles
- il ne remplace pas un canary réel

## Démonstration pédagogique attendue

Dans la démonstration du module :

- `v1` sert la réponse utilisateur
- `v2` reçoit le trafic miroir
- on observe les métriques et les logs

Dans le dépôt du projet, le fichier `k8s/ingress/shadow-ingress.yaml` contient déjà une base.

Vous pouvez maintenant l'utiliser pour passer de la théorie à une première implémentation.

Vous y trouverez ceci :

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    # TODO chapitre 3 : ajouter les annotations de mirroring vers le service challenger.
```

Votre objectif est d'ajouter les annotations nécessaires pour :

- envoyer le trafic normal vers `fraud-stable`
- envoyer une copie du trafic vers `fraud-canary`

Prenez quelques minutes pour essayer de le faire vous-même.

Si vous voulez vérifier votre écriture, ouvrez le bloc suivant.

%%SOLUTION%%

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fraud-shadow
  namespace: fraud-detection
  annotations:
    nginx.ingress.kubernetes.io/mirror-target: http://fraud-canary.fraud-detection.svc.cluster.local$request_uri
    nginx.ingress.kubernetes.io/mirror-request-body: "on"
spec:
  ingressClassName: nginx
  rules:
    - host: fraud.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fraud-stable
                port:
                  number: 80
```

%%SOLUTION%%

Ce que cette solution fait :

- `mirror-target` envoie une copie de la requête vers le challenger
- `mirror-request-body: "on"` indique que le corps de la requête doit aussi être copié
- le backend principal reste `fraud-stable`

Autrement dit :

- `v1` reste visible pour l'utilisateur
- `v2` travaille en arrière-plan

## Comment voir concrètement l'effet du shadow

Vous avez raison de vous poser la question : un shadow n'est pas visible directement dans la réponse utilisateur.

Si tout fonctionne bien :

- la réponse reçue par l'utilisateur continue à venir de `v1`
- mais `v2` reçoit aussi la requête en arrière-plan

Il faut donc observer le shadow avec d'autres signaux.

### 1. Démarrer l'infrastructure du lab

Avant d'envoyer des requêtes, il faut d'abord avoir un cluster et les briques minimales du lab.

Commencez par créer le cluster local :

```bash
make kind-create
```

Puis installez les composants utiles pour ce chapitre :

```bash
bash scripts/install-ingress.sh
bash scripts/install-rollouts.sh
```

Ensuite, appliquez la base du projet :

```bash
make apply-namespace
make apply-services
```

Puis construisez et chargez les deux versions du service dans `kind` :

```bash
make build-v1
make build-v2
make load-v1
make load-v2
```

Ensuite, déployez les deux versions dans le cluster et appliquez l'Ingress de shadow :

```bash
make apply-shadow-base
make apply-shadow-ingress
```

À ce stade, vous avez enfin une infrastructure sur laquelle observer le comportement du shadow.

### 2. Vérifier que la réponse utilisateur reste stable

Si vous voulez d'abord vérifier localement la forme de la requête, laissez le service tourner dans un terminal avec :

Si ce n'est pas déjà fait, commencez par installer les dépendances du projet :

```bash
make install
```

Puis lancez le service dans un premier terminal :

```bash
make run
```

Puis, dans un second terminal, vous pouvez tester la requête avec :

```bash
make sample-request
```

Cette étape ne valide pas encore le shadow dans Kubernetes.
Elle permet surtout de vérifier que votre service répond bien et que le payload de test est correct.

Pour observer le shadow dans l'infrastructure, utilisez ensuite :

```bash
make sample-shadow-request
```

Quand le shadow sera en place derrière l'Ingress, l'idée restera la même :

- vous envoyez une requête
- la réponse visible doit encore provenir de la version stable

Si tout fonctionne bien, la réponse JSON doit continuer à contenir :

```json
"model_version": "v1"
```

### 3. Regarder les logs des deux versions

Pour voir que le challenger reçoit aussi du trafic, le plus simple est de regarder les logs des pods.

Par exemple :

```bash
kubectl get pods -n fraud-detection
```

Puis :

```bash
kubectl logs deployment/fraud-v1 -n fraud-detection
kubectl logs deployment/fraud-v2 -n fraud-detection
```

L'objectif est de constater que :

- `v1` continue à traiter les requêtes visibles
- `v2` reçoit aussi des requêtes grâce au mirroring

### 4. Observer les métriques par version

Vous pouvez aussi observer le shadow via les métriques Prometheus exposées par le service.

Par exemple, en ouvrant les métriques du service stable puis du service challenger, vous pourrez comparer l'évolution des compteurs.

Ce que vous cherchez à vérifier est simple :

- les requêtes augmentent côté `v1`
- des requêtes apparaissent aussi côté `v2`
- mais l'utilisateur continue à recevoir la réponse de `v1`

### 5. Plus tard avec Grafana

Quand Prometheus et Grafana seront en place dans le module, le shadow deviendra plus lisible visuellement.

Vous pourrez alors suivre :

- la latence par `model_version`
- le taux d'erreur par version
- l'activité du challenger pendant qu'il reste invisible pour l'utilisateur

Le point important à retenir est donc le suivant :

le shadow se valide moins par la réponse utilisateur que par les **logs**, les **métriques** et les **dashboards**.

## Résumé

- Le shadow permet de tester une nouvelle version sans l'exposer directement à l'utilisateur.
- NGINX Ingress joue ici un rôle important dans le mirroring du trafic.
- Le shadow réduit le risque, mais ne remplace pas un canary réel.

## Pour la suite

Dans le prochain chapitre, vous allez passer au **canary** avec Argo Rollouts, c'est-à-dire à une vraie exposition progressive d'une nouvelle version sur du trafic réel.
