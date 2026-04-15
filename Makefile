.PHONY: install run status sample-request sample-shadow-request build-image build-v1 build-v2 load-v1 load-v2 kind-create kind-delete apply-namespace apply-services apply-shadow-base apply-shadow-ingress shadow-file canary-file bluegreen-file analysis-file

install:
	uv python install 3.11
	uv venv --python 3.11
	uv pip install --python .venv/bin/python -r service/requirements.txt

run:
	cd service && ../.venv/bin/python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000

status:
	cd service && ../.venv/bin/python -m pytest -q tests/test_app.py

sample-request:
	curl -s -X POST http://127.0.0.1:8000/predict -H "Content-Type: application/json" -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'

sample-shadow-request:
	curl -s -X POST http://127.0.0.1:8081/predict -H "Host: fraud.local" -H "Content-Type: application/json" -d '{"amount":1499.0,"merchant_category":"travel","hour_of_day":2,"country":"FR","is_international":true,"device_risk_score":0.91}'

build-image:
	docker build -t fraud-scoring:v1 service

build-v1:
	docker build -t fraud-scoring:v1 service

build-v2:
	docker build -t fraud-scoring:v2 service

load-v1:
	kind load docker-image fraud-scoring:v1 --name argocd-ml

load-v2:
	kind load docker-image fraud-scoring:v2 --name argocd-ml

kind-create:
	kind create cluster --name argocd-ml --config scripts/kind-config.yaml

kind-delete:
	kind delete cluster --name argocd-ml

apply-namespace:
	kubectl apply -f k8s/namespace.yaml

apply-services:
	kubectl apply -f k8s/services/

apply-shadow-base:
	kubectl apply -f k8s/deployments/fraud-v1.yaml && kubectl apply -f k8s/deployments/fraud-v2.yaml

apply-shadow-ingress:
	kubectl apply -f k8s/ingress/shadow-ingress.yaml

shadow-file:
	python3 -m pathlib k8s/ingress/shadow-ingress.yaml

canary-file:
	python3 -m pathlib k8s/rollouts/canary-rollout.yaml

bluegreen-file:
	python3 -m pathlib k8s/rollouts/bluegreen-rollout.yaml

analysis-file:
	python3 -m pathlib k8s/analysis/prometheus-analysis-template.yaml
