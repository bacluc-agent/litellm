DOCKER_CMD ?= docker run --rm -i --user "$(shell id -u):$(shell id -g)" -v "$(CURDIR):/data" -w /data ghcr.io/appuio/helm-v4:latest

.PHONY: render
render:
	$(DOCKER_CMD) /bin/bash -ec '\
	helm dependency update .; \
	helm template test . --namespace test \
		--values values.yaml \
		--values values-managed-talos.yaml \
		--values values-vshn-llm-routing.yaml \
		--values local-test-env.yaml \
	'
