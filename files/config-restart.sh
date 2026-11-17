set -eu
# Roll the deployment when, and only when, the watched ConfigMaps/Secrets
# changed content since the previous run of this job. The hash is kept as the
# llm.vshn/config-hash annotation on the deployment itself, which is safe to
# patch on a running deployment (it does not change the pod template).
key="llm.vshn/config-hash"
current=$(
  for ref in $WATCH_REFS; do
    kubectl get "$ref" -o jsonpath='{.data}' --ignore-not-found
  done | sha256sum | cut -d' ' -f1
)
previous=$(kubectl get "deploy/$DEPLOYMENT_NAME" -o jsonpath="{.metadata.annotations.llm\.vshn/config-hash}" --ignore-not-found)
if [ -n "$previous" ] && [ "$current" != "$previous" ]; then
  kubectl rollout restart "deploy/$DEPLOYMENT_NAME"
fi
kubectl annotate "deploy/$DEPLOYMENT_NAME" "$key=$current" --overwrite
