NAMESPACE ?= platform
RELEASE ?= platform
CHART := charts/platform
VALUES := -f $(CHART)/values.yaml -f $(CHART)/values.dev.yaml

.PHONY: deps lint template deploy verify grafana build-app

deps:
	helm dependency build $(CHART)

lint: deps
	helm lint $(CHART) $(VALUES)

template: deps
	helm template $(RELEASE) $(CHART) -n $(NAMESPACE) $(VALUES)

deploy: deps
	helm upgrade --install $(RELEASE) $(CHART) -n $(NAMESPACE) --create-namespace $(VALUES)

verify:
	RELEASE=$(RELEASE) NAMESPACE=$(NAMESPACE) ./scripts/verify.sh

grafana:
	RELEASE=$(RELEASE) NAMESPACE=$(NAMESPACE) ./scripts/port-forward-grafana.sh

build-app:
	docker build -t platform/todo-api:dev app
