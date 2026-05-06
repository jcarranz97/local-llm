#!/usr/bin/env bash
# Start llama-server with the args that fit on the 7900 XT.
# Server runs in the foreground — Ctrl+C to stop.

set -euo pipefail

HIP_VISIBLE_DEVICES=0 \
  ~/repos/llama.cpp/build/bin/llama-server \
    -hf unsloth/gemma-4-26B-A4B-it-GGUF \
    --no-mmproj \
    -fa on \
    -ctk q8_0 -ctv q8_0 \
    --host 127.0.0.1 --port 8080
