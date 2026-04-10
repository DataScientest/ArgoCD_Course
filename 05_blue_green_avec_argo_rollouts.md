# Chapitre 5 : Blue-Green avec Argo Rollouts

## Préface

Dans le chapitre précédent, vous avez appris à faire un canary manuel avec Argo Rollouts.

Vous savez maintenant :

- ce qu'est un objet `Rollout`
- comment lire son état
- pourquoi les pauses et les promotions sont utiles

Nous allons maintenant voir une autre stratégie très utilisée : le **blue-green**.

## Pourquoi ce chapitre compte

Parfois, vous ne voulez pas faire une montée progressive du trafic.

Vous voulez plutôt :

- préparer la nouvelle version à côté de l'ancienne
- vérifier qu'elle est prête
- puis basculer proprement

C'est le rôle du blue-green.

## Le grand modèle mental

Imaginez deux scènes de théâtre.

- une scène est active devant le public
- l'autre est préparée en coulisse

Quand tout est prêt, on change de scène.

Le blue-green fonctionne de cette manière.

## Principe du blue-green

Le blue-green repose sur deux environnements :

- un environnement **actif**
- un environnement **preview**

L'environnement actif sert le trafic réel.
L'environnement preview héberge la nouvelle version.

Quand vous êtes prêt, vous basculez.

## Concepts techniques à connaître

Dans un rollout blue-green, vous rencontrerez souvent ces notions :

- `activeService`
- `previewService`
- promotion
- retour arrière

### `activeService`

C'est le service qui envoie le trafic vers la version actuellement active.

### `previewService`

C'est le service qui expose la version candidate avant la bascule.

## Comparaison avec le canary

Le blue-green et le canary n'ont pas exactement le même objectif.

### Canary

- progression plus fine
- exposition graduelle au trafic réel
- observation plus détaillée de l'effet du trafic

### Blue-Green

- bascule plus nette
- rollback rapide
- logique souvent plus simple à comprendre côté exploitation

## Tableau mental rapide

```txt
Canary     -> transition graduelle
Blue-Green -> bascule nette entre deux environnements
```

## Intérêt en contexte ML

Le blue-green peut être un bon choix quand :

- vous voulez une bascule propre
- vous voulez garder une version prête en retour arrière
- vous privilégiez la rapidité de rollback

En revanche, il est moins riche qu'un canary pour observer une fraction réelle du trafic utilisateur.

## Démonstration pédagogique attendue

Dans ce module, la démonstration consiste à :

- préparer `v2` en preview
- vérifier qu'elle est prête
- basculer entre `v1` et `v2`

## Livrables du chapitre

- un YAML blue-green minimal
- un tableau comparatif canary vs blue-green

## Projet fil rouge du chapitre

Dans ce chapitre, vous allez compléter le fichier :

`k8s/rollouts/bluegreen-rollout.yaml`

Le template vous laisse deux éléments importants à renseigner :

- `activeService`
- `previewService`

## Exercice

Complétez cette partie du YAML :

```yaml
strategy:
  blueGreen:
    # TODO chapitre 5 : compléter activeService et previewService.
    autoPromotionEnabled: false
```

Prenez le temps d'essayer avant de regarder la solution.

## Solution

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: fraud-bluegreen
  namespace: fraud-detection
spec:
  replicas: 3
  selector:
    matchLabels:
      app: fraud-scoring
  template:
    metadata:
      labels:
        app: fraud-scoring
    spec:
      containers:
        - name: fraud-api
          image: fraud-scoring:v2
          ports:
            - containerPort: 8000
          env:
            - name: MODEL_VERSION
              value: v2
  strategy:
    blueGreen:
      activeService: fraud-stable
      previewService: fraud-preview
      autoPromotionEnabled: false
```

### Ce que vous devez retenir

- `activeService` pointe vers la version actuellement visible
- `previewService` pointe vers la version candidate
- `autoPromotionEnabled: false` laisse une décision manuelle de bascule

## Erreurs fréquentes

### 1. Penser que blue-green et canary sont interchangeables

Pour éviter cette erreur :

- retenez que le canary est progressif
- retenez que le blue-green est une bascule nette

### 2. Choisir blue-green sans réfléchir au coût d'infrastructure

Pour éviter cette erreur :

- rappelez-vous que deux environnements existent en parallèle
- prenez en compte ce coût dans le choix de stratégie

## Résumé

- Le blue-green prépare une nouvelle version à côté de la version active.
- Il permet une bascule nette et un rollback rapide.
- Il est complémentaire du canary, pas équivalent.

## Pour la suite

Dans le prochain chapitre, vous allez franchir une étape majeure : automatiser la décision de promotion ou d'abort avec Prometheus et Grafana.
