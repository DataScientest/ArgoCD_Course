# Chapitre 3 : Drift, self-heal et prune

## Préface

Dans le chapitre précédent, vous avez installé ArgoCD et déclaré une première application.

Vous savez maintenant :

- comment créer une `Application`
- comment lire son état général
- comment observer une synchronisation

Nous allons maintenant voir le point où GitOps devient vraiment parlant : la dérive.

## Pourquoi ce chapitre compte

Tant que Git et le cluster sont alignés, ArgoCD paraît simple.

Mais sa vraie valeur apparaît au moment où quelqu'un modifie le cluster autrement que par Git.

C'est là qu'on voit apparaître le **drift**.

## Qu’est-ce qu’une dérive ?

Une dérive, ou **drift**, apparaît quand le cluster s’éloigne de ce qui est déclaré dans Git.

Exemples classiques :

- un champ est modifié avec `kubectl edit`
- une ressource est supprimée à la main
- Git a changé mais le cluster n'a pas encore été synchronisé

## Trois notions importantes

### Détection de drift

ArgoCD compare l’état réel et l’état désiré.

### Self-heal

Le **self-heal** permet à ArgoCD de remettre automatiquement le cluster dans l’état attendu.

### Prune

Le **prune** permet de supprimer du cluster les ressources qui n’existent plus dans Git.

## Mise en pratique : provoquer une dérive

Commencez par vérifier l’état actuel de votre application :

```bash
kubectl get applications -n argocd
```

Puis choisissez une ressource suivie par ArgoCD.

Par exemple, vous pouvez modifier manuellement le nombre de replicas d’un `Deployment`.

Le but n’est pas de casser le projet.
Le but est de créer un petit écart volontaire pour observer la réaction d’ArgoCD.

## Observer ArgoCD

Après cette modification manuelle, retournez dans l’interface ArgoCD.

Vous devriez observer :

- que l’application n’est plus totalement alignée
- qu’un écart a été détecté

À ce moment-là, Git et le cluster ne racontent plus la même histoire.

## Activer `self-heal` et `prune`

Dans une configuration GitOps plus robuste, on active souvent :

- `selfHeal: true`
- `prune: true`

Exercice : complétez le bloc suivant.

%%SOLUTION%%

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

%%SOLUTION%%

## Ce que cela change

Avec cette configuration :

- ArgoCD peut corriger une dérive détectée
- ArgoCD peut supprimer des ressources devenues obsolètes

## Démonstration simple

Le test le plus parlant est le suivant :

1. observez une application `Synced`
2. modifiez manuellement une ressource
3. observez l’état devenir non aligné
4. laissez ArgoCD corriger
5. voyez l’état revenir au bon niveau

Cette démonstration est importante car elle montre que GitOps n’est pas seulement une convention de rangement.
C’est une façon active de garder le cluster cohérent.

## Ce qu’il faut bien comprendre

Quand ArgoCD corrige la dérive, cela signifie :

- le cluster n’est pas la référence
- Git reste la référence

Autrement dit, un changement manuel n’est pas durable s’il ne revient pas dans Git.

## Erreurs fréquentes

### 1. Activer `prune` sans comprendre son effet

Pour éviter cette erreur :

- retenez qu’une ressource absente de Git peut être supprimée du cluster

### 2. Penser qu’un changement manuel durable est compatible avec GitOps

Pour éviter cette erreur :

- retenez qu’en GitOps, la vérité durable doit revenir dans Git

## Résumé

- Le drift correspond à un écart entre Git et le cluster.
- `self-heal` permet de corriger cet écart automatiquement.
- `prune` permet de supprimer ce qui n’est plus attendu.

## Pour la suite

Dans le dernier chapitre, nous prendrons de la hauteur pour organiser le dépôt GitOps d’un projet MLOps de manière plus robuste.
