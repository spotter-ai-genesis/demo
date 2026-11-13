#!/bin/bash
# Launch the SPOTTER-AI x CLIO live attention demo from demo.sif (next to this script).
# When it prints "CLIO is ready: http://127.0.0.1:8100", open that address. Ctrl+C stops everything.
#
# Settings (environment, optional):
#   CLIO_DEMO_STATE     state directory (default: ~/.clio-demo); wiped at every start
#   CLIO_DEMO_KEEP=1    keep sessions and databases from the previous run
#   VLLM_GPU_UTIL       fraction of GPU memory vLLM may use (default 0.85, for a 6 GB card;
#                       0.675 on an 8 GB card reproduces a 6 GB card's budget)
#   VLLM_MAX_MODEL_LEN  context length in tokens (default 8192; lower it if vLLM runs out of memory)
#   VLLM_EXTRA_ARGS     extra vLLM flags
#   CLIO_PORT           CLIO's port (default 8100)
set -euo pipefail
cd "$(dirname "$0")"
[ -f demo.sif ] || { echo "demo.sif not found next to $0 (build it: see README.md)" >&2; exit 1; }
exec apptainer run --nv --cleanenv \
  --env "CLIO_DEMO_STATE=${CLIO_DEMO_STATE:-$HOME/.clio-demo}" \
  --env "CLIO_DEMO_KEEP=${CLIO_DEMO_KEEP:-0}" \
  --env "VLLM_GPU_UTIL=${VLLM_GPU_UTIL:-0.85}" \
  --env "VLLM_MAX_MODEL_LEN=${VLLM_MAX_MODEL_LEN:-8192}" \
  --env "VLLM_EXTRA_ARGS=${VLLM_EXTRA_ARGS:-}" \
  --env "CLIO_PORT=${CLIO_PORT:-8100}" \
  demo.sif
