DOCKER_CMD ?= docker run --rm -i --user "$(shell id -u):$(shell id -g)" -v "$(CURDIR):/data" -w /data ghcr.io/appuio/helm-v4:latest
PATH_HELM_CMD ?= $(if $(DOCKER_CMD),/data/,)
ENV_FILE ?= $(if $(wildcard local-test-env.yaml),local-test-env.yaml,env.yaml)

.ONESHELL:

.PHONY: render render-local
render:
	$(DOCKER_CMD) /bin/bash -s <<'HEREDOC'
	helm dependency update .
	helm template test . --namespace test \
		--values $(PATH_HELM_CMD)values.yaml \
		--values $(PATH_HELM_CMD)values-managed-talos.yaml \
		--values $(PATH_HELM_CMD)values-vshn-llm-routing.yaml \
		--values $(PATH_HELM_CMD)$(ENV_FILE)
	HEREDOC

render-local: DOCKER_CMD :=
render-local: PATH_HELM_CMD :=
render-local: render
