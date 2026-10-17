#!/usr/bin/env bash
# Bloquea cualquier comando de shell que toque un archivo de entorno
# (.env, .env.algo, .envrc). Las reglas deny de permissions cubren la
# herramienta Read; esto cierra el camino por Bash (cat, sed, grep).
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')

if printf '%s\n' "$cmd" | grep -Eq '(^|[^A-Za-z0-9_.-]|/)\.env(rc)?($|[^A-Za-z0-9])'; then
  echo "Regla del repo: los archivos de entorno (.env, .envrc) no se leen." >&2
  exit 2
fi
exit 0
