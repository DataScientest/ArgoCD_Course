# Chapitre 2 — Les concepts clés : le vocabulaire d'ArgoCD

---

## Pourquoi on apprend le vocabulaire en premier

Quand vous commencez à utiliser ArgoCD, vous allez tomber sur des mots comme *Application*, *sync*, *source*, *destination*, *health*. Ces mots ont des significations très précises dans ArgoCD.

Si on les comprend avant de toucher quoi que ce soit, tout le reste s'assemblera beaucoup plus vite. Alors allons-y un par un, en ancrant chaque concept dans ce qu'on connaît en tant qu'ingénieurs MLOps.

---

## Concept 1 : l'Application

Dans ArgoCD, une **Application** est l'objet central. C'est une configuration qui répond à deux questions :

1. **Où se trouve mon état souhaité ?** — le dépôt Git qui contient vos fichiers de config
2. **Où doit-il être déployé ?** — le cluster Kubernetes et le namespace cible

Imaginez-la comme un contrat de déploiement :
> "Prends la configuration du service d'inférence depuis ce dossier Git et fais-le tourner dans ce namespace Kubernetes."

Dans notre monde MLOps, on aura typiquement une Application par modèle ou par service — par exemple `fraud-detection-app`, `recommendation-app`, `feature-store-app`.

---

## Concept 2 : Source et Destination

Chaque Application ArgoCD a une **source** et une **destination**.

- **Source** = votre dépôt Git. C'est là que vous stockez les fichiers qui décrivent *comment* votre app doit être déployée : quelle image Docker utiliser, combien de réplicas, les limites de ressources, les variables d'environnement, etc.
- **Destination** = votre cluster Kubernetes et le **namespace** où l'app vivra.

> **Namespace ?** Pensez-y comme un dossier dans Kubernetes. Il regroupe des workloads liés pour qu'ils ne se perturbent pas mutuellement. On aura typiquement des namespaces comme `fraud-detection-dev`, `fraud-detection-prod`, etc.

```
Dépôt Git (source)                       Cluster Kubernetes (destination)
┌────────────────────────────┐           ┌───────────────────────────────────┐
│ models/fraud-detection/    │  ──▶     │ namespace: fraud-detection-prod   │
│   deployment.yaml          │          │   en cours : fraud-model:v3.2     │
│   service.yaml             │          └───────────────────────────────────┘
└────────────────────────────┘
```

---

## Concept 3 : État souhaité vs. état réel

C'est le cœur de la façon dont ArgoCD fonctionne — et ça correspond directement à la façon dont on pense le versionnage de modèles.

- **État souhaité** = ce que votre dépôt Git dit qui devrait tourner. Pour nous, c'est "modèle v3.2 avec 3 réplicas et 2 Go de mémoire."
- **État réel** = ce qui tourne effectivement dans le cluster en ce moment. Peut-être que c'est encore le modèle v3.1.

ArgoCD compare en permanence ces deux états. S'ils correspondent — parfait. Sinon — ArgoCD peut corriger ça automatiquement.

C'est exactement le même modèle mental que : *"l'expérience que je veux lancer"* vs. *"l'expérience en cours d'exécution."*

---

## Concept 4 : La synchronisation (Sync)

**Synchroniser**, c'est l'acte de faire correspondre l'état réel à l'état souhaité.

Quand votre pipeline CI met à jour le tag de l'image Docker dans Git — disons de `fraud-model:v3.1` à `fraud-model:v3.2` — l'état souhaité change. ArgoCD détecte ça et peut **synchroniser** : il applique la nouvelle config au cluster, tire la nouvelle image et redémarre les pods d'inférence.

Vous pouvez déclencher un sync manuellement, ou laisser ArgoCD le faire automatiquement à chaque push Git. On configurera ça au chapitre 5.

---

## Concept 5 : La santé (Health)

ArgoCD ne se contente pas de déployer — il surveille aussi si votre app est **en bonne santé** après le déploiement.

Pour un service d'inférence ML, c'est crucial. Un déploiement réussi ne veut pas dire que votre modèle répond correctement. ArgoCD vérifie :
- Les conteneurs ont-ils démarré ?
- Tous les pods attendus tournent-ils ?
- Le service répond-il aux probes de disponibilité ?

ArgoCD donne à votre app l'un de ces statuts :

| Statut | Ce que ça veut dire dans notre contexte MLOps |
|---|---|
| `Healthy` | Votre service d'inférence est opérationnel et répond |
| `Progressing` | Les pods démarrent — la nouvelle image du modèle est en cours de téléchargement |
| `Degraded` | Quelque chose ne va pas — pods qui crashent, OOM, mauvais démarrage |
| `Missing` | La ressource n'existe pas encore dans le cluster |
| `Unknown` | ArgoCD ne peut pas joindre le cluster pour vérifier |

---

## Tout assembler — la boucle de déploiement MLOps

Voici la vue d'ensemble de ce qui se passe quand on pousse une nouvelle version de modèle :

```
La CI entraîne fraud-model:v3.2 et pousse vers le registre Docker
        │
        ▼
La CI met à jour deployment.yaml dans Git : tag image → v3.2
        │
        ▼
ArgoCD détecte le changement Git (état souhaité mis à jour)
        │
        ▼
ArgoCD compare état souhaité ↔ état réel
        │
        ▼
Différence détectée → ArgoCD synchronise (applique deployment.yaml à Kubernetes)
        │
        ▼
Kubernetes tire fraud-model:v3.2 et redémarre les pods d'inférence
        │
        ▼
ArgoCD surveille la santé — les nouveaux pods sont-ils en bonne santé ?
```

---

## Les idées reçues fréquentes

- **"Sync" n'est pas "build".** Synchroniser ne réentraîne pas et ne reconstruit pas votre modèle. Ça ne fait qu'appliquer une config déjà construite à Kubernetes.
- **Le dépôt Git ne stocke pas les poids du modèle ni les images Docker.** Il stocke des *fichiers de configuration* qui référencent les images par leur tag. Les images vivent dans votre registre de conteneurs (ECR, Docker Hub, GCR…). Les poids du modèle vivent dans votre registre de modèles (MLflow, S3, etc.).

---

## Résumé

- Une **Application** relie une source Git à une destination Kubernetes.
- ArgoCD compare l'**état souhaité** (Git) à l'**état réel** (cluster).
- **Synchroniser**, c'est appliquer l'état Git au cluster.
- La **santé** nous indique si notre service d'inférence tourne correctement après un sync.

---

## La suite

Maintenant qu'on parle le langage d'ArgoCD, il est temps de l'installer. Dans le prochain chapitre, on va mettre en place ArgoCD sur un cluster Kubernetes local pour que vous puissiez commencer à expérimenter concrètement.
