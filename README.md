# SPOTTER-AI × CLIO live attention demo

One Apptainer image runs the whole demo on a single NVIDIA GPU (6 GB is enough):
CLIO with the **Barebone** agent (the model sees only the conversation), vLLM serving
Qwen3-4B-Instruct-2507 (AWQ 4-bit, greedy decoding) with the SPOTTER-AI attention
connector, and Flowcept (Valkey + MongoDB + collector) recording the provenance CLIO
reads the attention back from. It runs offline: the model is baked in.

## Three images

Each is built on the previous one, from the least to the most often rebuilt:

| Image | Definition | Holds | Rebuild when |
|---|---|---|---|
| `base.sif` | `base.def` | Ubuntu 24.04, uv, Node, pnpm, Python 3.14, Valkey, MongoDB, vLLM with Flowcept's dependencies, the start-up scripts | rarely: a tool, vLLM or a script changes |
| `model.sif` | `model.def` | the model: Qwen3-4B-Instruct-2507, AWQ 4-bit (`cyankiwi/Qwen3-4B-Instruct-2507-AWQ-4bit`), and its vLLM tool-call parser | the model changes |
| `demo.sif` | `demo.def` | SPOTTER-AI's attention connector and Flowcept fork, CLIO (agent + web UI), the demo prompts (`prompts/`) | a pin in `demo.def` changes |

`demo.sif` is the one that runs and ships: it contains the two below it.
All pins are at the top of each definition's `%post`; `apptainer exec demo.sif cat /opt/clio-demo/VERSIONS` lists them.

## Build

Requires Apptainer ≥ 1.3 with `--fakeroot`, about 40 GB of free disk while building, and network.

```bash
apptainer build --fakeroot base.sif base.def      # rarely
apptainer build --fakeroot model.sif model.def    # when the model changes
apptainer build --fakeroot demo.sif demo.def      # whenever the work changes
```

Measured on the build machine with a warm package cache:

| Image | File size | Adds on top of the layer below | Build time |
|---|---|---|---|
| `base.sif` | 4.8 GB | vLLM environment 9.4 GB unpacked, tools 0.5 GB, Python 0.2 GB | 2 min |
| `model.sif` | 7.8 GB | +2.9 GB: the model (3.3 GB unpacked) | 7 min (from a local snapshot) |
| `demo.sif` | 8.9 GB | +1.1 GB: CLIO (2.5 GB unpacked), connector, Flowcept fork | 3.5 min |

A cold build also downloads vLLM and its CUDA libraries (several GB).

Optional, to reuse what is already on the machine:
`--bind <dir>:/cache` keeps uv/npm/pnpm package caches across builds, and
`--bind <snapshot>:/model-cache:ro` (on the `model.sif` build) copies the model from a local
Hugging Face snapshot of exactly the pinned revision instead of downloading it, e.g.
`~/.cache/huggingface/hub/models--cyankiwi--Qwen3-4B-Instruct-2507-AWQ-4bit/snapshots/<rev>`.

## Run

Requires Linux x86_64, an NVIDIA GPU (≥ 6 GB) with a driver for CUDA 13 (≥ 580), Apptainer ≥ 1.3
(no root), and free local ports 8100, 18000, 16379, 37017, 18008.

```bash
./launch.sh          # runs demo.sif from the same folder
```

It starts the databases, the Flowcept collector, vLLM (about a minute), then CLIO, and prints
`CLIO is ready: http://127.0.0.1:8100`. Open it (if asked for a service, use that address).
Ctrl+C stops everything. Every start is clean. Settings are environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `CLIO_DEMO_STATE` | `~/.clio-demo` | databases, captures, logs, CLIO state, demo prompts |
| `CLIO_DEMO_KEEP` | 0 | 1 = keep sessions across restarts |
| `VLLM_GPU_UTIL` | 0.85 | share of GPU memory for vLLM (0.675 on an 8 GB card gives a 6 GB card's budget) |
| `VLLM_MAX_MODEL_LEN` | 8192 | context length; lower it if vLLM runs out of memory |
| `VLLM_EXTRA_ARGS` | | extra vLLM flags |
| `CLIO_PORT` | 8100 | CLIO's port |

e.g. `VLLM_GPU_UTIL=0.675 ./launch.sh`. Logs: `~/.clio-demo/logs`.
`launch.sh` is a wrapper; the image also runs directly:
`apptainer run --nv --cleanenv --env VLLM_GPU_UTIL=0.675 demo.sif`.

## The demo

OPAL chain `exp78-chain-0004-low`, three rounds on a cadmium dose series. In the corrupted
variant one digit of round 1's tool output was changed (Fv/Fm at 50 mg/kg: 0.512 → 0.612).

| Variant | Prompts (`~/.clio-demo/demo/exp78/`) | Round 1 | Round 2 | Round 3 |
|---|---|---|---|---|
| clean | `clean_round1..3.txt` | 100 | Ecm14 | 100; AGREES |
| corrupted | `r1t50_round1..3.txt` | **50** | Ecm14 | **50; AGREES** |

1. New session: the **+** next to the *default* workspace; choose the **Barebone** agent and the
   **vLLM / Qwen3-4B-Instruct-2507-AWQ** model before the first message.
2. Paste `r1t50_round1.txt`, wait for the answer, then rounds 2 and 3.
3. Select `50` in round 3's answer and choose **Understand attention**: the hottest line is
   round 1's stored answer. Select `50` there: the tool table lights up, the tampered row among
   the hottest lines.

Heat: green = text, red = tool calls (the `>>>` blocks, shown as console tables), one 0–9 scale,
every heated segment underlined. If no heat can be shown, a notice under the attention bar says
why (for instance a tokenizer that cannot line up with the captured tokens, and its likely cause).
