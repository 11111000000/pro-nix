#!/usr/bin/env bash
set -e

MODEL="${1:-codellama:7b-instruct-q4_K_M}"

echo "Installing Ollama model: $MODEL"
echo ""
echo "Recommended models for mid-range laptop:"
echo "  - codellama:7b-instruct-q4_K_M  (best for coding, ~4GB)"
echo "  - phi:2.7b-q4_K_M                (smallest, ~1.6GB)"
echo "  - deepseek-coder:6.7b-q4_K_M    (good for code, ~4GB)"
echo ""

ollama pull "$MODEL"
echo ""
echo "Installed models:"
ollama list
