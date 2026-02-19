# Chapitre 7 — Stratégies de déploiement : Canary, Blue/Green et MLOps

---

## Le problème central : comment savoir si un nouveau modèle est fiable ?

Voici une situation que tout ingénieur MLOps connaît bien.

Vous venez d'entraîner une nouvelle version de votre modèle de détection de fraude. Les métriques hors-ligne sont excellentes : le recall a progressé de 3%, la précision aussi. Votre pipeline d'évaluation donne son feu vert.

Mais voilà l'inconfortable vérité : **les métriques hors-ligne ne garantissent pas le comportement en production.**

La distribution des données d'entraînement ne correspond jamais parfaitement au trafic réel. Des cas limites existent que votre jeu de test n'a pas couverts. La latence du modèle peut exploser sous une vraie charge. Le nouveau modèle peut interagir différemment avec votre feature store.

La seule façon d'en être vraiment sûr, c'est de tester le modèle sur du trafic de production réel — mais on ne peut pas déployer sur 100% des utilisateurs et espérer que tout se passe bien. Si le modèle régresse, tous vos utilisateurs en subissent les conséquences.

C'est là que les stratégies de déploiement deviennent indispensables.

---

## Les trois stratégies

### Stratégie 1 : Recreate (tout ou rien)

C'est ce qu'on a utilisé jusqu'ici. ArgoCD arrête l'ancienne version, démarre la nouvelle.

```
Avant :   [v1] [v1] [v1]
Pendant : (brève interruption)
Après :   [v2] [v2] [v2]
```

**En MLOps :** Acceptable pour les environnements de développement et de staging. Jamais pour des modèles en production où on a besoin d'une validation progressive.

---

### Stratégie 2 : Blue/Green

Deux versions complètes tournent simultanément — la version actuelle (blue) et la nouvelle (green). Le trafic ne pointe que vers l'une des deux à la fois.

```
        Utilisateurs
              │
              ▼
   ┌──────────────┐     ┌──────────────┐
   │  Blue (v1)  │     │  Green (v2)  │
   │  (en ligne) │     │  (en attente)│
   └──────────────┘     └──────────────┘
```

Quand vous êtes prêt, vous basculez le trafic de blue vers green instantanément. Sans interruption.

**En MLOps :** Utile quand on veut valider le nouveau modèle (test de charge, smoke test, appel API de vérification) avant de s'y engager. Le rollback est instantané — on rebascule simplement vers blue.

**Coût :** On fait tourner le double de l'infrastructure pendant que les deux versions coexistent.

---

### Stratégie 3 : Canary (le standard or du MLOps)

On route une *fraction* du trafic de production réel vers le nouveau modèle. Le reste continue sur la version actuelle.

```
100 requêtes d'inférence entrantes
        │
        ├──── 90 requêtes ──▶ [v1 — modèle de fraude actuel]
        └──── 10 requêtes ──▶ [v2 — nouveau modèle de fraude]
```

On observe les métriques de production réelles — recall fraude, taux de faux positifs, latence de prédiction, taux d'erreur — sur cette petite tranche. Si tout se passe bien, on augmente progressivement la part de trafic : 10% → 30% → 50% → 100%.

Si les métriques se dégradent, on ramène le nouveau modèle à 0% immédiatement. Seulement 10% de vos utilisateurs ont été exposés au problème.

**C'est l'approche qui définit une pratique MLOps mature.**

---

## Argo Rollouts : le compagnon d'ArgoCD pour les stratégies avancées

ArgoCD standard gère les déploiements de base. Pour le canary et le blue/green avec un contrôle fin du trafic, on utilise **Argo Rollouts** — un outil compagnon qui s'intègre nativement avec ArgoCD.

> Argo Rollouts remplace l'objet `Deployment` standard de Kubernetes par un objet `Rollout` qui comprend nativement le canary et le blue/green.

ArgoCD applique vos fichiers depuis Git → Argo Rollouts orchestre le déploiement progressif.

### Installer Argo Rollouts

```bash
kubectl create namespace argo-rollouts

kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

Installez le plugin kubectl pour la visualisation :

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

---

## Déploiement canary pour un modèle de détection de fraude

Construisons ensemble un rollout canary réaliste pour notre service de détection de fraude. On vient d'entraîner `fraud-model:v3.3` et on veut le tester prudemment avant un déploiement complet.

### Le manifest Rollout

```yaml
# rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout                         # remplace "Deployment"
metadata:
  name: fraud-detection-api
  namespace: fraud-detection-production
spec:
  replicas: 10                        # 10 instances au total
  selector:
    matchLabels:
      app: fraud-detection
  template:
    metadata:
      labels:
        app: fraud-detection
    spec:
      containers:
      - name: inference-server
        image: my-registry/fraud-model:v3.3   # nouvelle version du modèle
        resources:
          requests:
            memory: "4Gi"
            cpu: "1"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 45     # temps de chargement du modèle
  strategy:
    canary:
      steps:
      - setWeight: 10                 # étape 1 : 10% du trafic vers v3.3
      - pause: {}                     # attendre une approbation manuelle
      - setWeight: 30                 # étape 2 : passer à 30%
      - pause: {duration: 15m}        # pause automatique — observer 15 minutes
      - setWeight: 60                 # étape 3 : passer à 60%
      - pause: {duration: 15m}        # observer à nouveau
      - setWeight: 100                # étape 4 : déploiement complet — v3.3 en production
```

Chaque étape est un point de décision :
- `setWeight: 10` — 1 pod sur 10 sert v3.3, les 9 autres servent encore v3.2
- `pause: {}` — le rollout s'arrête et attend qu'un humain approuve
- `pause: {duration: 15m}` — le rollout s'arrête automatiquement 15 minutes, le temps d'observer les métriques

---

## Observer et contrôler le rollout

Committez ce fichier dans Git, et ArgoCD l'appliquera à votre cluster.

Regardez le rollout en temps réel :

```bash
kubectl argo-rollouts get rollout fraud-detection-api \
  --namespace fraud-detection-production \
  --watch
```

Résultat :
```
Name:            fraud-detection-api
Status:          ॐ Paused
Step:            1/7
SetWeight:       10
ActualWeight:    10

REVISION  IMAGE                            REPLICAS  READY
2         my-registry/fraud-model:v3.3     1         1     ← 10% (1 pod sur 10)
1         my-registry/fraud-model:v3.2     9         9     ← 90%
```

Un seul pod sert le nouveau modèle. Votre monitoring affiche :
- Recall fraude : 94,1% (production actuelle : 91,8%) ✓
- Taux de faux positifs : 6,2% (actuel : 7,1%) ✓
- Latence p99 : 42ms (actuelle : 38ms) — légèrement plus élevée, acceptable ✓

Tout se passe bien. On approuve manuellement pour passer à l'étape suivante :

```bash
kubectl argo-rollouts promote fraud-detection-api \
  --namespace fraud-detection-production
```

Si au contraire vous observez une hausse des faux positifs ou une régression de latence, abandonnez immédiatement :

```bash
kubectl argo-rollouts abort fraud-detection-api \
  --namespace fraud-detection-production
```

ArgoCD reviendra à v3.2 sur les 10 pods. Votre modèle de production est indemne.

---

## Analyse automatisée — le niveau supérieur

Dans une plateforme MLOps mature, on ne veut pas qu'un humain approuve chaque étape canary. On veut que le système décide en se basant sur les métriques.

Argo Rollouts propose `AnalysisTemplate` pour ça :

```yaml
# analysis-fraud-model.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: fraud-model-metrics
  namespace: fraud-detection-production
spec:
  metrics:
  - name: fraud-recall
    interval: 2m                          # vérification toutes les 2 minutes
    successCondition: result[0] >= 0.90   # le recall doit rester au-dessus de 90%
    failureLimit: 2                        # 2 échecs autorisés avant abandon
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(fraud_predictions_correct_total[5m]))
          /
          sum(rate(fraud_predictions_total[5m]))

  - name: api-error-rate
    interval: 1m
    successCondition: result[0] <= 0.01   # moins de 1% d'erreurs
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_errors_total[5m]))
          /
          sum(rate(http_requests_total[5m]))
```

Intégrez-le dans le Rollout :

```yaml
  strategy:
    canary:
      analysis:
        templates:
        - templateName: fraud-model-metrics   # analyse lancée à chaque étape
      steps:
      - setWeight: 10
      - pause: {duration: 10m}               # observation automatique
      - setWeight: 30
      - pause: {duration: 10m}
      - setWeight: 100
```

Désormais : si le recall fraude passe sous 90% ou si les erreurs API dépassent 1%, Argo Rollouts abandonne automatiquement le rollout et revient au modèle précédent. Aucune intervention humaine nécessaire.

C'est du MLOps de niveau production.

---

## Blue/Green pour la validation de modèle

Quand vous voulez valider un nouveau modèle *avant* que du trafic utilisateur le touche :

```yaml
  strategy:
    blueGreen:
      activeService: fraud-detection-active     # service live actuel
      previewService: fraud-detection-preview   # prévisualisation du nouveau modèle
      autoPromotionEnabled: false               # promotion manuelle obligatoire
      prePromotionAnalysis:                     # analyse avant bascule du trafic
        templates:
        - templateName: fraud-model-metrics
```

Avec cette configuration :
1. Vous déployez v3.3 — il tourne mais ne reçoit aucun trafic utilisateur (service preview)
2. Vous lancez votre suite de validation contre le service preview
3. ArgoCD exécute automatiquement les métriques de l'`AnalysisTemplate`
4. Si tout passe, vous promouvez manuellement — le trafic bascule instantanément de v3.2 vers v3.3
5. v3.2 reste en ligne pendant une période de grâce au cas où vous auriez besoin de revenir en arrière

---

## Guide de choix de stratégie

| Situation | Stratégie recommandée |
|---|---|
| Environnement de développement | Recreate — la vitesse compte, pas la stabilité |
| Environnement de staging | Blue/Green — valider avant tout trafic utilisateur |
| Production, mise à jour à faible risque (changement de config, correction de bug) | Blue/Green avec analyse automatisée |
| Production, nouvelle version de modèle | Canary — bascule de trafic progressive avec analyse de métriques |
| Production, rollback critique nécessaire | Abandonner le rollout → retour immédiat à la version précédente |

---

## Erreurs fréquentes à ce stade

- **Utiliser un `Deployment` standard à la place d'un `Rollout`.** Argo Rollouts ne fonctionne qu'avec son propre objet `Rollout`. Si vous gardez un Deployment standard, vous n'avez aucun contrôle canary ou blue/green.
- **Mettre `pause: {}` et oublier de promouvoir.** Le rollout restera en pause indéfiniment. Ajoutez `duration` si vous souhaitez qu'il progresse automatiquement après observation.
- **Ne pas mettre en place Prometheus ou tout autre monitoring.** Un canary sans observation de métriques n'est qu'un déploiement partiel. L'observabilité est ce qui rend le canary utile.
- **Confondre le statut de sync ArgoCD avec la progression du rollout.** ArgoCD affichera `Synced` dès que l'objet Rollout est appliqué — mais le rollout peut encore être en cours. Vérifiez `kubectl argo-rollouts get rollout` pour l'état réel du déploiement.

---

## Résumé

- **Recreate :** simple, interruption totale, inadapté aux modèles en production.
- **Blue/Green :** deux versions en parallèle, bascule de trafic instantanée, idéal pour la pré-validation.
- **Canary :** bascule progressive avec données utilisateurs réelles — le standard or du MLOps.
- **Argo Rollouts** est l'outil qui apporte ces stratégies à ArgoCD.
- **AnalysisTemplate** automatise la décision go/no-go en se basant sur vos métriques de production.

---

## Et ensuite

Dans le prochain chapitre, on abordera le troubleshooting — les commandes et les réflexes à adopter quand quelque chose se passe mal en production. Parce que ça finira par arriver, et on veut que vous soyez rapide et serein quand ça surviendra.
