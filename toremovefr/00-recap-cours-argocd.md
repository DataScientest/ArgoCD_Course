# Recap complet pour preparer un cours sur Argo CD

---

## Objectif de ce fichier

Ce document sert de **feuille de route de cours**.

L'idee est simple : si vous devez faire un cours sur Argo CD, vous pouvez vous appuyer sur cette synthese pour savoir :

- ce qu'il faut expliquer
- dans quel ordre l'expliquer
- quelles demonstrations faire
- quels pieges et questions frequentes anticiper
- quels sujets lies presenter autour d'Argo CD

---

## 1. Le message principal du cours

Si vous deviez resumer tout le cours en une phrase, ce serait :

> **Argo CD est un outil GitOps pour Kubernetes qui compare en permanence ce qui est decrit dans Git avec ce qui tourne vraiment dans le cluster, puis remet le cluster dans l'etat attendu.**

Les trois idees a faire passer tres tot sont :

- Argo CD ne remplace pas Git, il s'appuie dessus
- Argo CD ne remplace pas Kubernetes, il pilote des ressources Kubernetes
- Argo CD ne fait pas la CI, il fait surtout la partie deploiement et reconciliation

---

## 2. Le fil logique recommande pour le cours

Voici un ordre pedagogique tres solide :

1. Expliquer le probleme avant l'outil
2. Introduire CI/CD
3. Introduire Kubernetes tres simplement
4. Introduire GitOps
5. Introduire Argo CD et son vocabulaire
6. Montrer une installation ou un environnement deja pret
7. Faire un premier deploiement simple
8. Montrer la synchronisation et la detection de drift
9. Introduire les environnements multiples
10. Aller vers les sujets avances : securite, strategies de deploiement, observabilite, gouvernance

---

## 3. Ce qu'il faut expliquer avant Argo CD

Avant de parler d'Argo CD, il faut poser les bases.

### A. Pourquoi les deploiements manuels posent probleme

Points a expliquer :

- les erreurs humaines sont frequentes
- les environnements divergent vite
- on perd la tracabilite
- revenir en arriere est plus difficile
- a grande echelle, les scripts maison deviennent fragiles

### B. Difference entre CI et CD

Il faut insister sur la separation :

- **CI** : build, tests, packaging, publication d'image
- **CD** : livraison de ce qui a ete prepare par la CI

Tres bon message a repeter :

> La CI produit un artefact deployable. Argo CD prend cet etat voulu et l'applique au cluster.

### C. Rappels Kubernetes minimaux

Pas besoin de faire tout Kubernetes, mais il faut expliquer :

- cluster
- node
- namespace
- pod
- deployment
- service
- configmap
- secret
- ingress

Le but n'est pas de former entierement a Kubernetes ici, mais de donner assez de contexte pour comprendre ce qu'Argo CD manipule.

---

## 4. Les concepts Argo CD indispensables

### A. GitOps

Point central du cours.

Ce qu'il faut faire comprendre :

- Git devient la source de verite
- le changement passe idealement par commit, merge, review
- le cluster ne devrait pas etre modifie a la main
- Argo CD observe, compare et reconcilie

Points importants a formuler clairement :

- l'etat desire est dans Git
- l'etat reel est dans le cluster
- Argo CD compare les deux
- si les deux divergent, il signale ou corrige selon la configuration

### B. Application

L'objet central dans Argo CD.

Il faut expliquer qu'une Application dit :

- ou se trouve la source (`repoURL`, `path`, `targetRevision`)
- ou deployer (`cluster`, `namespace`)
- comment synchroniser

### C. Sync

Expliquer :

- sync manuel
- sync automatique
- difference entre detecter un changement et l'appliquer
- options de sync

### D. Health

Faire comprendre qu'un deploiement applique n'est pas forcement un deploiement sain.

Statuts utiles a expliquer :

- `Healthy`
- `Progressing`
- `Degraded`
- `OutOfSync`
- `Unknown`
- `Missing`

### E. Drift

Sujet tres important pedagogiquement.

Expliquer le cas classique :

1. quelqu'un modifie une ressource directement dans le cluster
2. cette modification n'existe pas dans Git
3. Argo CD detecte l'ecart
4. Argo CD peut le signaler ou remettre l'etat de Git

### F. Self-heal et prune

Deux concepts a bien distinguer :

- `selfHeal` : re-appliquer l'etat voulu si quelqu'un change le cluster a la main
- `prune` : supprimer du cluster ce qui n'existe plus dans Git

### G. Historique et rollback

Bien preciser la philosophie GitOps :

- le rollback se pense souvent comme un `git revert` ou un retour a une revision precedente
- Argo CD resynchronise ensuite le cluster avec cette revision

---

## 5. Les objets et composants d'Argo CD a presenter

Pour un vrai cours, il faut montrer l'architecture.

### Composants principaux

- `argocd-server` : interface web et API
- `argocd-repo-server` : lecture et rendu des manifests depuis Git
- `argocd-application-controller` : comparaison, suivi, sync
- `argocd-dex-server` : authentification, souvent via SSO/OIDC
- Redis : cache et support interne selon l'installation

### Ressources utiles a expliquer

- `Application`
- `AppProject`
- eventuellement `ApplicationSet`

### Pourquoi `AppProject` est important

Il permet de definir des garde-fous :

- quels repos sont autorises
- quels clusters sont cibles
- quels namespaces sont autorises
- quelles ressources sont autorisees ou interdites

Tres utile pour parler de multi-equipes et de gouvernance.

---

## 6. Les sources de configuration qu'Argo CD peut gerer

Sujet important pour montrer qu'Argo CD ne se limite pas a un seul format.

Il faut presenter :

- manifests YAML Kubernetes bruts
- Helm charts
- Kustomize
- parfois Jsonnet ou plugins selon le contexte

Le message pedagogique :

> Argo CD ne genere pas toujours lui-meme les manifests. Il peut aussi s'appuyer sur des outils de templating deja connus dans l'ecosysteme Kubernetes.

Tres utile de montrer un exemple de chaque si le temps le permet.

---

## 7. Le cycle complet a raconter pendant le cours

Voici le scenario de reference a expliquer plusieurs fois.

1. Le developpeur modifie l'application
2. La CI lance les tests
3. La CI construit l'image Docker
4. L'image est poussee dans un registre
5. Un commit met a jour la version d'image dans le repo GitOps
6. Argo CD detecte le changement
7. Argo CD compare etat desire et etat reel
8. Argo CD synchronise
9. Kubernetes redeploie les pods
10. Argo CD observe la sante de l'application

Cette boucle suffit a donner une vision tres claire de la chaine de livraison moderne.

---

## 8. Les demonstrations les plus utiles

Si vous devez faire un cours vivant, voici les meilleures demos.

### Demo 1. Installation et connexion

Montrer :

- installation d'Argo CD sur un cluster local ou de demo
- acces a l'UI
- premiere connexion
- lecture rapide du tableau de bord

### Demo 2. Premiere application

Montrer :

- un repo Git simple
- creation d'une Application
- choix du repo, du path, du namespace, de la revision
- premier sync
- visualisation des ressources creees

### Demo 3. Changement dans Git

Exemple simple :

- changer le nombre de replicas
- changer le tag d'image
- pousser le commit
- montrer qu'Argo CD passe `OutOfSync`
- lancer ou laisser faire le sync
- observer le retour a `Healthy`

### Demo 4. Drift manuel

Tres pedagogique.

Montrer :

- modification manuelle dans le cluster avec `kubectl`
- retour dans Argo CD
- detection du drift
- correction automatique ou manuelle

### Demo 5. Prune

Montrer :

- suppression d'une ressource dans Git
- effet de `prune`
- importance de bien comprendre ce que l'on supprime

### Demo 6. Multi-environnements

Montrer :

- `dev`, `staging`, `prod`
- un overlay Kustomize ou des values Helm distinctes
- differences de replicas, image tag, ressources, variables d'environnement

### Demo 7. Echec de deploiement

Tres utile pour apprendre le diagnostic.

Montrer :

- image inexistante
- probe incorrecte
- erreur de manifest
- lecture des evenements et du statut Argo CD

---

## 9. Les grandes strategies de structuration Git a expliquer

Il faut parler de l'organisation des depots, car c'est souvent ce qui decide si un usage GitOps reste lisible ou non.

### Option A. Un repo applicatif + un repo GitOps separe

Avantages :

- responsabilites separees
- meilleur controle des changements d'infrastructure/deploiement
- souvent prefere en entreprise

### Option B. Tout dans le meme repo

Avantages :

- plus simple pour apprendre
- facile pour une petite equipe

### Structurations classiques a presenter

- par application
- par environnement
- par equipe
- par cluster

Tres bonne discussion a inclure :

- mono-repo vs multi-repo
- qui a le droit de changer quoi
- qui declenche les promotions entre environnements

---

## 10. Les environnements multiples et promotions

Sujet central pour un cours realiste.

Ce qu'il faut expliquer :

- pourquoi `dev`, `staging`, `prod` existent
- comment separer les configurations entre environnements
- comment promouvoir une version
- pourquoi il faut limiter les differences entre environnements

Approches a presenter :

- branches differentes
- dossiers differents
- overlays Kustomize
- values Helm par environnement

Le point important :

> La promotion ideale est un changement trace dans Git, pas une manipulation manuelle dans le cluster.

---

## 11. Securite et controle d'acces

Souvent oublie dans les introductions, mais essentiel dans un cours complet.

Points a couvrir :

- authentification a l'UI et a l'API
- SSO avec OIDC ou SAML selon les environnements
- roles et permissions RBAC
- separation par projets (`AppProject`)
- acces aux clusters cibles
- gestion des secrets

Tres important :

- Argo CD ne doit pas devenir un endroit ou l'on stocke des secrets en clair
- introduire des outils comme Sealed Secrets, External Secrets Operator, Vault, ou SOPS selon le contexte

---

## 12. Observabilite, audit et exploitation quotidienne

Un bon cours doit aussi montrer la vie reelle apres l'installation.

Ce qu'il faut voir :

- lecture du dashboard
- historique des synchronisations
- logs des composants Argo CD
- evenements Kubernetes
- suivi des erreurs de sync
- alerting eventuel
- audit des changements via Git

Questions utiles a poser aux apprenants :

- comment savoir pourquoi une app est `Degraded` ?
- comment differencier un probleme Argo CD d'un probleme Kubernetes ?
- comment savoir quel commit a provoque le changement ?

---

## 13. Les sujets avances a mentionner

Selon le temps disponible, voici les extensions naturelles du cours.

### A. ApplicationSet

Tres utile pour generer plusieurs Applications automatiquement.

Exemples :

- une app par cluster
- une app par environnement
- une app par client ou tenant

### B. Deploiements progressifs

Parler du lien avec :

- Argo Rollouts
- canary deployments
- blue/green deployments

Important de preciser :

- Argo CD gere l'etat desire
- Argo Rollouts gere des strategies de rollout avancees

### C. Webhooks et refresh

Expliquer :

- polling Git
- webhooks GitHub/GitLab
- rafraichissement plus reactif

### D. Multi-cluster

Sujet tres utile en entreprise.

Expliquer :

- un Argo CD peut piloter plusieurs clusters
- enjeux de permissions, reseau, gouvernance

### E. Sync waves, hooks, ordering

Pour expliquer l'ordre de deploiement de ressources dependantes.

Tres utile quand il faut deployer :

- CRDs avant les CRs
- base de donnees ou operateurs avant applications dependantes

---

## 14. Les erreurs et confusions frequentes a anticiper

Voici les plus classiques a traiter pendant le cours.

### Confusion 1. Argo CD fait la CI

Correction : non. Il consomme le resultat de la CI.

### Confusion 2. Argo CD remplace Kubernetes

Correction : non. Il orchestre l'application de manifests sur Kubernetes.

### Confusion 3. Argo CD stocke l'application elle-meme

Correction : il suit une source Git et applique ce qu'elle decrit.

### Confusion 4. Un sync reussit = application fonctionnelle

Correction : non. Il faut regarder la sante, les pods, les logs et le comportement reel.

### Confusion 5. On peut continuer a modifier le cluster a la main

Correction : techniquement oui, mais cela casse la logique GitOps et cree du drift.

### Confusion 6. `prune` est sans risque

Correction : `prune` est puissant mais peut supprimer des ressources. Il faut le comprendre avant de l'activer partout.

---

## 15. Les questions que les apprenants vont souvent poser

Bonnes questions a preparer a l'avance :

- Quelle difference entre Argo CD et Flux ?
- Quelle difference entre Argo CD et Jenkins/GitHub Actions/GitLab CI ?
- Est-ce qu'Argo CD deploie sans Docker ?
- Peut-on l'utiliser sans Kubernetes ?
- Comment gerer les secrets ?
- Comment faire un rollback ?
- Comment gerer plusieurs environnements ?
- Comment eviter qu'une mauvaise configuration parte en production ?
- Peut-on faire du blue/green ou du canary avec Argo CD ?
- Quelle difference entre Helm, Kustomize et Argo CD ?

---

## 16. Comparaisons utiles a inclure

### Argo CD vs pipeline CI/CD classique base sur scripts

- scripts : plus libre, mais plus fragile
- Argo CD : plus declaratif, plus visible, plus auditable

### Argo CD vs Flux

- les deux sont GitOps
- Argo CD est souvent apprecie pour son UI et son experience utilisateur
- Flux est souvent percu comme tres natif Kubernetes et tres modulaire

### Argo CD vs Helm

- Helm genere des manifests
- Argo CD deploie et surveille l'etat de l'application
- les deux peuvent etre utilises ensemble

---

## 17. Les prerequis techniques a annoncer aux apprenants

Pour que le cours se passe bien, il est utile que les apprenants connaissent deja un minimum :

- Git de base
- Docker de base
- notions minimales de Kubernetes
- YAML
- idee generale du cycle de vie d'une application

Si le public est debutant, il faut ralentir sur :

- namespace
- pod
- deployment
- service
- image Docker

---

## 18. Proposition de plan de cours complet

Voici un plan de cours directement reutilisable.

### Partie 1. Pourquoi Argo CD ?

- problemes des deploiements manuels
- CI vs CD
- pourquoi Kubernetes change la facon de deployer
- introduction a GitOps

### Partie 2. Les concepts fondamentaux

- Application
- source et destination
- etat desire vs etat reel
- sync
- health
- drift

### Partie 3. Installation et prise en main

- installation d'Argo CD
- interface web
- CLI
- connexion au cluster

### Partie 4. Premier deploiement

- creation d'une application simple
- sync manuel
- sync automatique
- lecture du resultat dans l'UI

### Partie 5. Organisation reelle d'un projet

- repo GitOps
- Helm ou Kustomize
- multi-environnements
- promotions

### Partie 6. Exploitation quotidienne

- troubleshooting
- rollback
- audit
- bonnes pratiques d'equipe

### Partie 7. Sujets avances

- ApplicationSet
- multi-cluster
- securite
- Argo Rollouts

---

## 19. Bonnes pratiques a recommander explicitement

- garder Git comme source unique de verite
- eviter les changements manuels en production
- versionner clairement les changements de deploiement
- separer les responsabilites applicatives et environnementales si besoin
- utiliser des reviews Git avant promotion
- tester d'abord en `dev` ou `staging`
- surveiller les statuts de sante et les erreurs de sync
- traiter les secrets avec des outils adaptes
- documenter la structure GitOps choisie

---

## 20. Ce qu'il faut absolument montrer en pratique

Si le temps est court, les quatre demonstrations prioritaires sont :

1. creation d'une Application
2. changement Git puis sync
3. drift detecte puis corrige
4. difference entre sync reussi et application saine

Avec seulement ces quatre demonstrations, les apprenants comprennent deja l'essentiel d'Argo CD.

---

## 21. Resume ultra-court a dire a l'oral

Si vous voulez conclure simplement a l'oral :

> Argo CD sert a decrire les deploiements dans Git, a surveiller ce qui tourne sur Kubernetes, et a faire en sorte que le cluster corresponde toujours a ce qui a ete valide dans le depot. C'est la mise en pratique du GitOps pour rendre les deploiements plus fiables, visibles et reproductibles.

---

## 22. Pistes pour enrichir encore le cours

Si vous voulez aller plus loin, vous pouvez ajouter :

- un schema d'architecture Argo CD
- un lab guide pas a pas
- un TP avec un repo de demo
- un comparatif Argo CD vs Flux
- un chapitre special sur les secrets
- un chapitre special sur Argo Rollouts
- un chapitre special sur ApplicationSet
- une fiche de troubleshooting rapide

---

## Conclusion

Pour faire un bon cours sur Argo CD, il ne faut pas seulement expliquer des commandes.

Il faut surtout faire comprendre :

- le probleme que GitOps resout
- la place d'Argo CD dans une chaine CI/CD moderne
- la difference entre etat desire et etat reel
- l'importance de Git comme source de verite
- les bonnes pratiques d'exploitation en equipe

Si ces idees sont comprises, les commandes et l'outil deviennent beaucoup plus faciles a retenir.
