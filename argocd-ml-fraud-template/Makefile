.PHONY: install run test build-image kind-create kind-delete apply-namespace apply-services shadow-file canary-file bluegreen-file analysis-file

install:
	pip install -r service/requirements.txt

run:
	cd service && uvicorn app:app --reload --host 0.0.0.0 --port 8000

test:
	cd service && pytest -q

build-image:
	docker build -t fraud-scoring:v1 service

kind-create:
	kind create cluster --name argocd-ml --config scripts/kind-config.yaml

kind-delete:
	kind delete cluster --name argocd-ml

apply-namespace:
	kubectl apply -f k8s/namespace.yaml

apply-services:
	kubectl apply -f k8s/services/

shadow-file:
	python3 -m pathlib k8s/ingress/shadow-ingress.yaml

canary-file:
	python3 -m pathlib k8s/rollouts/canary-rollout.yaml

bluegreen-file:
	python3 -m pathlib k8s/rollouts/bluegreen-rollout.yaml

analysis-file:
	python3 -m pathlib k8s/analysis/prometheus-analysis-template.yaml
