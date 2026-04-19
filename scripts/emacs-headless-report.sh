#!/usr/bin/env bash
set -e

# Отчет о работе emacs headless
echo "Emacs headless report: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Emacs version: $(emacs --version | head -1)"
echo "Report completed successfully"