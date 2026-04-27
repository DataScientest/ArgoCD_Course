.PHONY: install status run sample-request build-v1 build-v2 load-v1 load-v2 kind-create kind-delete apply-base-dev apply-base-prod apply-appproject apply-app-dev apply-app-prod

install:
	uv python install 3.11
	uv venv --python 3.11
	uv pip install --python .venv/bin/python -r service/requirements.txt

status:
	cd service && ../.venv/bin/python -m pytest -q tests/test_app.py

run:
	cd service && ../.venv/bin/python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000

sample-request:
	curl -s -X POST http://127.0.0.1:8000/predict -H "Content-Type: application/json" -d '{"message_length":420,"customer_tier":"enterprise","waiting_hours":18,"sentiment_score":0.15,"has_sla_breach":true}'

build-v1:
	docker build -t support-priority-api:v1 service

build-v2:
	docker build -t support-priority-api:v2 service

load-v1:
	kind load docker-image support-priority-api:v1 --name argocd-course

load-v2:
	kind load docker-image support-priority-api:v2 --name argocd-course

kind-create:
	kind create cluster --name argocd-course --config scripts/kind-config.yaml

kind-delete:
	kind delete cluster --name argocd-course

apply-base-dev:
	kubectl apply -k k8s/overlays/dev

apply-base-prod:
	kubectl apply -k k8s/overlays/prod

apply-appproject:
	kubectl apply -f k8s/argocd/appproject-support.yaml

apply-app-dev:
	kubectl apply -f k8s/argocd/application-dev.yaml

apply-app-prod:
	kubectl apply -f k8s/argocd/application-prod.yaml
