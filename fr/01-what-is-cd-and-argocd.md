# Chapitre 1 — C'est quoi la livraison continue, et pourquoi ArgoCD ?

---

## Commençons par un problème concret que vous connaissez déjà

En tant qu'ingénieurs MLOps, on passe beaucoup de temps à entraîner des modèles, à ajuster des hyperparamètres, et à évaluer des métriques. Mais voici une question qu'on se pose trop rarement :

**Une fois que votre modèle est prêt, comment arrive-t-il concrètement en production ?**

Aujourd'hui, beaucoup d'équipes le font encore à la main. On se connecte en SSH sur un serveur, on copie le nouvel artefact, on redémarre le service d'inférence, et on espère que rien ne casse. Ça fonctionne une fois. Peut-être deux.

Mais imaginez votre quotidien à grande échelle :
- Vous réentraînez votre modèle chaque nuit sur de nouvelles données
- Vous avez trois environnements : dev, staging, et production
- Votre équipe compte cinq data scientists qui poussent des changements en simultané

Faire des déploiements à la main à ce rythme, c'est lent, c'est source d'erreurs, et franchement épuisant. Un mauvais tag sur une image Docker, un environnement oublié — et votre modèle en production a soudainement trois versions de retard.

C'est exactement le problème que résout la **livraison continue** (ou CD, pour *Continuous Delivery*).

---

## C'est quoi la livraison continue ?

Soyons précis, parce qu'on voit souvent CI et CD utilisés indifféremment — ce n'est pas la même chose.

- La **CI** (*Continuous Integration*) consiste à construire, tester et packager automatiquement votre code ou modèle à chaque changement. C'est l'étape "préparer le colis".
- La **CD** (*Continuous Delivery*) consiste à livrer ce colis automatiquement et de façon fiable vers un environnement cible. C'est l'étape "expédier le colis".

En MLOps, votre pipeline CI pourrait :
1. Lancer les tests unitaires sur le code du modèle
2. Entraîner ou réentraîner le modèle
3. Évaluer les métriques (accuracy, F1, latence)
4. Construire et pousser une image Docker du service d'inférence

Votre pipeline CD — alimenté par **ArgoCD** — prend ensuite cette image Docker et la déploie sur Kubernetes automatiquement.

---

## Pourquoi Kubernetes ? Un rappel rapide

Vous connaissez déjà Docker. Kubernetes, c'est la couche au-dessus.

Docker, c'est "comment on package une app". Kubernetes, c'est "comment on fait tourner et gérer des dizaines de ces apps de manière fiable, avec des health checks, du redémarrage automatique, du scaling, et du rollback".

Pour le MLOps, Kubernetes est particulièrement adapté :
- Faire tourner plusieurs versions d'un modèle simultanément (utile pour l'A/B testing)
- Scaler automatiquement le service d'inférence selon le trafic
- Revenir en arrière instantanément si un nouveau modèle se dégrade en production

On introduira les concepts Kubernetes progressivement tout au long de ce cours. Pas besoin de les maîtriser avant de commencer.

---

## ArgoCD et la philosophie GitOps

ArgoCD est un outil CD conçu pour Kubernetes. Mais ce qui le rend spécial, c'est la philosophie qu'il suit : le **GitOps**.

Voici ce que GitOps veut dire en une phrase :

> Votre dépôt Git est l'unique source de vérité. Ce qui est dans Git, c'est ce qui doit tourner dans votre cluster. ArgoCD surveille votre dépôt et s'assure que la réalité correspond à ce que vous avez écrit.

Pour des ingénieurs MLOps, c'est puissant. Imaginez que votre dépôt ressemble à ça :

```
ml-platform/
├── models/
│   ├── fraud-detection/
│   │   └── deployment.yaml   ← image: mon-registry/fraud-model:v3.1
│   └── recommendation/
│       └── deployment.yaml   ← image: mon-registry/reco-model:v1.8
└── ...
```

Quand votre pipeline CI entraîne un nouveau modèle de détection de fraude et pousse `fraud-model:v3.2` dans le registre, il met aussi à jour `deployment.yaml` dans Git. ArgoCD détecte ce changement et déploie automatiquement `v3.2` — de façon traçable, auditable, et réversible.

---

## Ce que vous gagnez en tant qu'ingénieur MLOps

| Sans GitOps | Avec GitOps + ArgoCD |
|---|---|
| "Qui a déployé ce modèle ?" | Chaque déploiement = un commit Git avec auteur et horodatage |
| Revenir en arrière = SSH + commandes manuelles | Revenir en arrière = `git revert` + ArgoCD synchronise automatiquement |
| Les environnements divergent silencieusement | ArgoCD réconcilie en permanence chaque environnement avec Git |
| Les déploiements font peur | Les déploiements sont ennuyeux — et c'est exactement ce qu'on veut |

---

## Les idées reçues fréquentes à ce stade

- **"ArgoCD va entraîner mon modèle."** Non. ArgoCD ne gère que le côté déploiement. Votre pipeline d'entraînement (Kubeflow, MLflow, GitHub Actions…) est une préoccupation séparée.
- **"Il faut maîtriser Kubernetes avant de commencer."** Non. On introduira les objets Kubernetes au fur et à mesure qu'on en a besoin, étape par étape.

---

## Résumé

- Déployer des modèles ML à la main ne passe pas à l'échelle — les outils CD automatisent ça de façon fiable.
- La **CI** construit et package ; la **CD** livre. ArgoCD est la couche CD.
- ArgoCD suit le **GitOps** : Git définit ce qui doit tourner, ArgoCD le fait exister.
- Chaque déploiement devient un commit Git traçable, auditable et réversible.

---

## La suite

Dans le prochain chapitre, on va parcourir le vocabulaire de base d'ArgoCD — Applications, sync, health, et plus encore. Comprendre ces concepts avant de toucher quoi que ce soit vous évitera beaucoup de confusion par la suite.
