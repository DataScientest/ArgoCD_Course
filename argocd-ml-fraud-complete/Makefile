.PHONY: install run test build-v1 build-v2 build-v2-buggy kind-create kind-delete apply-base apply-shadow apply-canary apply-bluegreen apply-analysis

install:
	pip install -r service/requirements.txt

run:
	cd service && uvicorn app:app --reload --host 0.0.0.0 --port 8000

test:
	cd service && pytest -q

build-v1:
	docker build -t fraud-scoring:v1 service

build-v2:
	docker build -t fraud-scoring:v2 service

build-v2-buggy:
	docker build -t fraud-scoring:v2-buggy service

kind-create:
	kind create cluster --name argocd-ml --config scripts/kind-config.yaml

kind-delete:
	kind delete cluster --name argocd-ml

apply-base:
	kubectl apply -f k8s/namespace.yaml && kubectl apply -f k8s/services/

apply-shadow:
	kubectl apply -f k8s/ingress/shadow-ingress.yaml

apply-canary:
	kubectl apply -f k8s/rollouts/canary-rollout.yaml

apply-bluegreen:
	kubectl apply -f k8s/rollouts/bluegreen-rollout.yaml

apply-analysis:
	kubectl apply -f k8s/analysis/prometheus-analysis-template.yaml && kubectl apply -f k8s/rollouts/canary-rollout-with-analysis.yaml
