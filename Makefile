ENV_FILE ?= $(if $(wildcard .env),.env,env.yaml)
ENV_VALUES := $(if $(filter .yaml .yml,$(suffix $(ENV_FILE))),$(ENV_FILE),/tmp/litellm-env-values.json)

.PHONY: render
render:
ifeq ($(ENV_VALUES),/tmp/litellm-env-values.json)
	jq -Rn '{env: ([inputs | select(test("^(export )?[A-Za-z_][A-Za-z0-9_]*=")) | sub("^export "; "") | split("=") | {(.[0]): (.[1:] | join("=") | gsub("^[\u0027\"]|[\u0027\"]$$"; ""))}] | add // {})}' $(ENV_FILE) > $(ENV_VALUES)
endif
	helm dependency update .
	helm template test . --namespace test \
		--values values.yaml \
		--values values-managed-talos.yaml \
		--values $(ENV_VALUES) \
		--values values-vshn-llm-routing.yaml
