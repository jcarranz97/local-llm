# local-llm

A single-file Bash wrapper (`run-llama.sh`) around `llama.cpp`'s `llama-server`
that holds a registry of GGUF models the user runs locally on their AMD
Radeon RX 7900 XT (20 GB VRAM, ROCm, gfx1100). The point of the wrapper is to
remember the per-model flags needed to fit on that specific GPU — not to
abstract over `llama.cpp`.

The `llama-server` binary itself is expected at
`~/repos/llama.cpp/build/bin/llama-server` (built separately, not part of this
repo).

## Commands

```bash
./run-llama.sh -l               # list registered models
./run-llama.sh <nickname>       # run a model (foreground, Ctrl+C to stop)
./run-llama.sh                  # no args → prints usage + list

# Once running, query the live server in another terminal:
curl -s http://127.0.0.1:8080/props | jq        # n_ctx, model path, build info
curl -s http://127.0.0.1:8080/v1/models | jq    # OpenAI-compatible model list

# Syntax-check the script after editing:
bash -n run-llama.sh
```

There are no tests, no build step, no linter configured.

## Architecture

The whole "system" is the `MODELS` associative array near the top of
`run-llama.sh`. Each entry is:

```bash
[nickname]="<HF repo>|<extra llama-server flags>"
```

The pipe-separated `extra flags` field is the load-bearing piece. Most models
in the list run with empty extras, but `gemma-26b` only fits in 20 GB VRAM
because of `--no-mmproj -c 4096 -fa on -ctk q8_0 -ctv q8_0`. When the user
adds a model that OOMs on load, the fix lives in this field — typical knobs:

- `--no-mmproj` — drop the multimodal/vision projector
- `-c <N>` — cap context (KV cache scales linearly with `n_ctx`)
- `-fa on` + `-ctk q8_0 -ctv q8_0` — Flash Attention with 8-bit KV cache
- `-ngl <N>` — offload fewer layers to GPU (last resort, slower)

Word-splitting on the extras field is intentional (`# shellcheck disable=SC2086`).
If a future model needs a flag value containing spaces, switch that entry to
an array instead of bolting on `eval`.

## When editing

- Keep the script single-file with no external config. The user pushed back on
  earlier versions that introduced env-var overrides, subcommands
  (`start`/`stop`/`info`), and PID/log state directories. The current shape
  ("one model registry, one command, foreground server") is the desired shape.
- Don't add features speculatively. If the user asks for status/memory
  introspection, prefer pointing at `curl /props` and `rocm-smi` over baking
  it into the script.
- README's model table must stay in sync with the `MODELS` array when entries
  are added, removed, or renamed.
