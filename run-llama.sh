#!/usr/bin/env bash
# Start llama-server with one of the models below.
# Server runs in the foreground — Ctrl+C to stop.
#
# Usage:
#   ./run-llama.sh -l              list available models
#   ./run-llama.sh <name>          run that model

set -euo pipefail

LLAMA_BIN="$HOME/repos/llama.cpp/build/bin/llama-server"
HOST=127.0.0.1
PORT=8080

# nickname  =>  "<HF repo>|<extra args needed for it to fit / behave>"
declare -A MODELS=(
  [gemma-e2b]="ggml-org/gemma-4-E2B-it-GGUF|"
  [qwen3.6-35b]="lmstudio-community/Qwen3.6-35B-A3B-GGUF|"
  [qwen3-coder-30b]="unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF|"
  [gemma-26b]="unsloth/gemma-4-26B-A4B-it-GGUF|--no-mmproj -c 4096 -fa on -ctk q8_0 -ctv q8_0"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [-l|--list] | <model-name>

Available models:
EOF
  list_models
}

list_models() {
  for name in $(printf '%s\n' "${!MODELS[@]}" | sort); do
    printf "  %-18s  %s\n" "$name" "${MODELS[$name]%%|*}"
  done
}

case "${1:-}" in
  ""|-h|--help)
    usage
    exit 0
    ;;
  -l|--list)
    list_models
    exit 0
    ;;
  *)
    name="$1"
    if [[ -z "${MODELS[$name]+x}" ]]; then
      echo "Unknown model: $name" >&2
      echo >&2
      list_models >&2
      exit 1
    fi
    repo="${MODELS[$name]%%|*}"
    extra="${MODELS[$name]#*|}"
    echo "Starting '$name'  ($repo)"
    echo "Server: http://$HOST:$PORT"
    echo
    # shellcheck disable=SC2086    # we want word-splitting on $extra
    HIP_VISIBLE_DEVICES=0 exec "$LLAMA_BIN" \
      -hf "$repo" \
      --host "$HOST" --port "$PORT" \
      $extra
    ;;
esac
