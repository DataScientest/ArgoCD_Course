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

## La philosophie derrière

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

Comme pour le canary, une démonstration propre ne démarre pas directement avec `v2`.

Le bon déroulé est :

1. appliquer d'abord un rollout blue-green en `v1`
2. mettre ensuite le rollout à jour vers `v2`
3. observer `v2` dans le `previewService`
4. promouvoir la nouvelle version pour basculer le trafic

## Livrables du chapitre

- un YAML blue-green minimal
- un tableau comparatif canary vs blue-green

Dans le dépôt du projet, le fichier `k8s/rollouts/bluegreen-rollout.yaml` vous laisse deux éléments importants à renseigner :

- `activeService`
- `previewService`

Complétez cette partie du YAML :

```yaml
strategy:
  blueGreen:
    # TODO chapitre 5 : compléter activeService et previewService.
    autoPromotionEnabled: false
```

Prenez le temps d'essayer avant d'ouvrir le bloc suivant.

%%SOLUTION%%

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
          image: fraud-scoring:v1
          ports:
            - containerPort: 8000
          env:
            - name: MODEL_VERSION
              value: v1
  strategy:
    blueGreen:
      activeService: fraud-stable
      previewService: fraud-preview
      autoPromotionEnabled: false
```

%%SOLUTION%%

Ce que vous devez retenir :

- `activeService` pointe vers la version actuellement visible
- `previewService` pointe vers la version candidate
- `autoPromotionEnabled: false` laisse une décision manuelle de bascule

## Mettre en place et tester le blue-green

Comme pour le canary, modifier le YAML ne suffit pas.
Il faut aussi lancer le rollout et observer ce qu'il change réellement.

### 1. Nettoyer l'étape précédente

Si vous venez du chapitre 4, retirez d'abord le rollout canary :

```bash
make cleanup-canary
```

### 2. Appliquer le rollout blue-green en `v1`

Avant d'appliquer le rollout, assurez-vous que les services utilisés par le blue-green ne gardent pas d'anciens labels spécifiques au shadow.

En particulier, `fraud-stable` et `fraud-preview` doivent rester compatibles avec le `selector` du rollout.

```bash
make apply-bluegreen
kubectl argo rollouts get rollout fraud-bluegreen -n fraud-detection
```

À ce stade, `v1` doit encore être la version active.

### 3. Mettre à jour le rollout vers `v2`

```bash
make update-bluegreen-to-v2
kubectl argo rollouts get rollout fraud-bluegreen -n fraud-detection
```

Cette fois, Argo Rollouts doit conserver `v1` comme version active et préparer `v2` comme version candidate.

### 4. Vérifier la version active et la version preview

Dans un premier terminal, faites un port-forward vers le service actif :

```bash
kubectl port-forward -n fraud-detection svc/fraud-stable 8082:80
```

Dans un second terminal, faites un port-forward vers le service preview :

```bash
kubectl port-forward -n fraud-detection svc/fraud-preview 8083:80
```

Puis envoyez une requête à chaque service.

Service actif :

```bash
curl -s -X POST http://127.0.0.1:8082/predict \
  -H "Content-Type: application/json" \
  -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
```

Service preview :

```bash
curl -s -X POST http://127.0.0.1:8083/predict \
  -H "Content-Type: application/json" \
  -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'
```

Ce que vous devez observer :

- le service actif doit encore répondre avec `model_version: "v1"`
- le service preview doit répondre avec `model_version: "v2"`

Cette étape est très importante, car elle montre que la nouvelle version est prête sans avoir encore remplacé l'ancienne.

### 5. Promouvoir le blue-green

Quand vous êtes satisfait de la version preview, vous pouvez promouvoir le rollout :

```bash
kubectl argo rollouts promote fraud-bluegreen -n fraud-detection
kubectl argo rollouts get rollout fraud-bluegreen -n fraud-detection
```

### 6. Observer l'impact de la bascule

Après la promotion, relancez les port-forward si nécessaire, puis renvoyez les mêmes requêtes.

Cette fois, vous devez voir que le service actif renvoie `v2`.

Autrement dit :

- avant promotion : `v1` est active, `v2` est en preview
- après promotion : `v2` devient active

### 7. Ce que ce test valide réellement

Dans ce chapitre, le test du blue-green valide surtout :

- que la version candidate peut être préparée à côté de la version active
- que le `previewService` permet d'observer cette version avant la bascule
- que la promotion change concrètement la version servie par le service actif

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
