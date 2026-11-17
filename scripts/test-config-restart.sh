#!/usr/bin/env bash
# Asserts files/config-restart.sh rolls the deployment only when watched
# ConfigMap/Secret content changed, using a stubbed kubectl.
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/kubectl" <<'STUB'
#!/usr/bin/env bash
set -eu
case "$1 $2 $3" in
  "get configmap/litellm-config -o") cat "$work/configmap-litellm-config" ;;
  "get configmap/runtime-env -o") cat "$work/configmap-runtime-env" ;;
  "get secret/runtime-secrets -o") cat "$work/secret-runtime-secrets" ;;
  "get deploy/test-litellm -o") cat "$work/prev-hash" ;;
  "rollout restart deploy/test-litellm") echo restart >> "$work/calls" ;;
  "annotate deploy/test-litellm llm.vshn/config-hash="*)
    echo "annotate $(printf '%s' "$3" | cut -d= -f2)" >> "$work/calls" ;;
  *) echo "unexpected kubectl call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$work/bin/kubectl"

current_hash() {
  cat "$work/configmap-litellm-config" "$work/configmap-runtime-env" "$work/secret-runtime-secrets" | sha256sum | cut -d' ' -f1
}

run_script() {
  : > "$work/calls"
  work="$work" PATH="$work/bin:$PATH" DEPLOYMENT_NAME=test-litellm \
    WATCH_REFS="configmap/litellm-config configmap/runtime-env secret/runtime-secrets" \
    /bin/sh files/config-restart.sh
}

expect_calls() {
  if ! diff <(printf '%s\n' "$1") "$work/calls" > "$work/calls.diff"; then
    echo "FAIL: unexpected kubectl calls:" >&2; cat "$work/calls" "$work/calls.diff" >&2; exit 1
  fi
}

: > "$work/configmap-litellm-config"
: > "$work/configmap-runtime-env"
: > "$work/secret-runtime-secrets"

echo "scenario 1: first run records the hash without restarting"
printf 'model_list: [a]' > "$work/configmap-litellm-config"
: > "$work/prev-hash"
run_script
expect_calls "annotate $(current_hash)"

echo "scenario 2: unchanged watched resources do not restart"
printf '%s' "$(current_hash)" > "$work/prev-hash"
run_script
expect_calls "annotate $(current_hash)"

echo "scenario 3: changed ConfigMap restarts the deployment"
printf 'model_list: [b]' > "$work/configmap-litellm-config"
run_script
expect_calls "$(printf 'restart\nannotate %s' "$(current_hash)")"

echo "scenario 4: changed Secret restarts the deployment"
printf 'masterkey: rotated' > "$work/secret-runtime-secrets"
run_script
expect_calls "$(printf 'restart\nannotate %s' "$(current_hash)")"

echo "OK: config-restart script only rolls on watched content changes"
