# local-llm

A small wrapper script for launching `llama.cpp`'s `llama-server` with a
preset list of GGUF models. Avoids re-typing long command lines and remembers
the per-model flags needed to fit on the local GPU.

## Hardware target

- AMD Radeon RX 7900 XT (20 GB VRAM, gfx1100)
- ROCm build of `llama.cpp`

The defaults assume one GPU at `HIP_VISIBLE_DEVICES=0`.

## Prerequisites

- `llama.cpp` built with ROCm support at `~/repos/llama.cpp/build/bin/llama-server`
- A working `huggingface-cli` login if any of the models are gated
- Network access for the first run of each model (weights are pulled via `-hf`
  and cached under `~/.cache/llama.cpp/` or the HF cache)

## Usage

```bash
./run-llama.sh -l               # list available models
./run-llama.sh <model-name>     # start the server with that model
./run-llama.sh                  # no args → prints help + list
```

The server runs in the foreground at `http://127.0.0.1:8080`. Stop it with
`Ctrl+C`.

While it's running you can query it from another terminal:

```bash
curl -s http://127.0.0.1:8080/props | jq          # runtime info (n_ctx, etc.)
curl -s http://127.0.0.1:8080/v1/models | jq      # OpenAI-compatible model list
```

The web UI is also available at `http://127.0.0.1:8080`.

## Using it from opencode

`llama-server` exposes an OpenAI-compatible API at `/v1`, so any client that
speaks OpenAI works.

The model **key** under `models` in `opencode.json` must be the exact ID the
server advertises at `/v1/models` — not the script's nickname. Start the
server first, then check the real ID:

```bash
curl -s http://127.0.0.1:8080/v1/models | jq '.data[].id'
# e.g. "unsloth/gemma-4-26B-A4B-it-GGUF"
```

Use that string verbatim in `~/.config/opencode/opencode.json`:

```json
{
  "provider": {
    "llama-local": {
      "name": "llama.cpp (Local)",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "unsloth/gemma-4-26B-A4B-it-GGUF": {
          "name": "Gemma 4 26B (local)",
          "tool_call": true
        },
        "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF": {
          "name": "Qwen3 Coder 30B (local)",
          "tool_call": true
        }
      }
    }
  }
}
```

Notes:

- `baseURL` must match `HOST:PORT` in `run-llama.sh` (defaults to
  `127.0.0.1:8080`). If you change either, update both.
- This script runs one model per server instance. You can list every model
  in `opencode.json`, but only the one whose server is currently running will
  respond — the others fail until you Ctrl+C and relaunch with that
  nickname.
- `tool_call: true` only works for models that actually support tool calling
  (the Qwen3-Coder family does; check the model card for others).

## Available models

| Nickname          | HF repo                                          | Notes                          |
| ----------------- | ------------------------------------------------ | ------------------------------ |
| `gemma-e2b`       | `ggml-org/gemma-4-E2B-it-GGUF`                   | small, runs with defaults      |
| `qwen3.6-35b`     | `lmstudio-community/Qwen3.6-35B-A3B-GGUF`        | MoE, runs with defaults        |
| `qwen3-coder-30b` | `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF`     | MoE, runs with defaults        |
| `gemma-26b`       | `unsloth/gemma-4-26B-A4B-it-GGUF`                | needs memory-saving flags      |

`gemma-26b` is launched with extra flags so it fits in 20 GB VRAM:

- `--no-mmproj` — skip the multimodal/vision projector (LLM-only)
- `-c 4096` — cap context to 4K (model trains far higher; KV cache scales with `n_ctx`)
- `-fa on` — Flash Attention
- `-ctk q8_0 -ctv q8_0` — quantize the K and V cache to 8-bit

Without these, the model OOMs at load time on the 7900 XT.

## Adding a new model

Edit `run-llama.sh` and add an entry to the `MODELS` associative array:

```bash
[my-nickname]="org/repo-GGUF|<extra flags or empty>"
```

The part after `|` is whatever extra `llama-server` args that model needs
(memory tuning, sampler defaults, chat template overrides, etc.). Leave it
empty if defaults work.

## File layout

```
local-llm/
├── README.md
└── run-llama.sh
```

The script is intentionally a single file with no external state — the model
list lives at the top, alongside the binary path and host/port.

## Alternatives

If you find yourself wanting a model registry, auto-pull, hot-swap, or a
daemon that hosts multiple models at once, look at
[Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai) — both wrap
`llama.cpp` and add that layer. This script stays close to `llama.cpp` so
per-model flags (especially VRAM tuning) remain explicit and easy to change.
