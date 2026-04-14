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
    nginx.ingress.kubernetes.io/rewrite-target: /
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

## Exemple concret

Vous avez un service de fraude avec :

- `fraud-model:v1`
- `fraud-model:v2`

Une requête arrive.

Le système fait alors ceci :

1. l'utilisateur envoie une requête de scoring
2. `v1` traite la requête officielle
3. `v2` reçoit une copie en arrière-plan
4. vous comparez latence, erreurs et stabilité

## Erreurs fréquentes

### 1. Croire que le shadow valide toute la qualité métier

Pour éviter cette erreur :

- considérez le shadow comme une étape d'observation
- ne le traitez pas comme une validation finale complète

### 2. Oublier d'observer le challenger par version

Pour éviter cette erreur :

- ajoutez `model_version` dans vos logs et métriques
- séparez clairement ce qui vient de `v1` et ce qui vient de `v2`

## Résumé

- Le shadow permet de tester une nouvelle version sans l'exposer directement à l'utilisateur.
- NGINX Ingress joue ici un rôle important dans le mirroring du trafic.
- Le shadow réduit le risque, mais ne remplace pas un canary réel.

## Pour la suite

Dans le prochain chapitre, vous allez passer au **canary** avec Argo Rollouts, c'est-à-dire à une vraie exposition progressive d'une nouvelle version sur du trafic réel.
