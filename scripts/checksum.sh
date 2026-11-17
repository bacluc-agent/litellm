#!/usr/bin/env bash
# Asserts the config-restart helper pod template rolls on changes to the
# rendered config ConfigMap or the runtime Secrets.
set -euo pipefail

readonly HELM_IMAGE=${HELM_IMAGE:-ghcr.io/appuio/helm-v4}
# renovate: datasource=docker depName=ghcr.io/appuio/helm-v4
DEFAULT_HELM_VERSION=4.3.0
readonly HELM_VERSION=${HELM_VERSION:-$DEFAULT_HELM_VERSION}

render() {
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --volume "$PWD:/app" \
    --env HOME=/tmp/helm-home \
    --workdir /app \
    --entrypoint sh \
    "$HELM_IMAGE:$HELM_VERSION" -eu -c '
      mkdir -p "$HOME"
      helm dep build . >/dev/null
      exec helm template test . -f values.yaml -f values-vshn-llm-routing.yaml "$@"
    ' _ "$@" | grep -E 'checksum/(config-proxy-configmap|runtime-secrets)'
}

before=$(render)
model=$(render --set 'wrapperProxyConfigMap.opencodeModels[0]=changed-model')
secrets=$(render --set 'env.PROXY_MASTER_KEY=rotated')

[[ $before != $model ]] || { echo "FAIL: model config change did not change the helper pod checksums"; exit 1; }
[[ $before != $secrets ]] || { echo "FAIL: runtime secret change did not change the helper pod checksums"; exit 1; }
echo "OK: config-restart helper rolls on config and secret changes"
