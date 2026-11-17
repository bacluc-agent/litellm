#!/usr/bin/env bash
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
      exec helm template test . -f values.yaml -f values-vshn-llm-routing.yaml -f local-test-env.yaml "$@"
    ' _ "$@"
}

grep_checksums() { grep -E 'checksum/(config-proxy-configmap|runtime-secrets)'; }

before=$(render | grep_checksums)
model=$(render --set 'litellm.wrapperProxyConfigMap.opencodeModels[0]=changed-model' | grep_checksums)
secrets=$(render --set 'litellm.env.ROTATED_KEY=abc' | grep_checksums)

[[ $before != $model ]] || { echo "FAIL: model config change did not change the pod checksum annotations"; exit 1; }
[[ $before != $secrets ]] || { echo "FAIL: runtime secret change did not change the pod checksum annotations"; exit 1; }
echo "OK: pod template checksums react to config and secret changes"
