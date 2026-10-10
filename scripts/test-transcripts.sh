#!/usr/bin/env bash
# Verifica los transcriptos del libro contra el `kai` instalado.
#
# `test-examples.sh` prueba que los ejemplos compilen y corran: su
# veredicto es el código de salida. Este script prueba lo otro, que es
# la promesa que el libro le hace al lector: que la salida impresa bajo
# un `$ kai ...` sea la que realmente produce ese comando.
#
# Uso:
#   scripts/test-transcripts.sh                   # todo
#   scripts/test-transcripts.sh es|en             # una edición
#   scripts/test-transcripts.sh -v                # muestra el diff de cada FAIL
#   KAI_BACKEND=native scripts/test-transcripts.sh
#
# Un bloque entra a la verificación si:
#   - abre con ``` sin lenguaje (o ```text / ```console / ```sh),
#   - su primera línea es `$ kai <subcomando> ...`, y
#   - el archivo que nombra existe en el repo.
#
# Se saltan a propósito los transcriptos que no son reproducibles por
# construcción: los que citan archivos de ejemplo inexistentes
# (`app.kai`, `main.kai`), los que eliden salida con `...`, y los que
# encadenan más de un comando en el mismo bloque. El reporte dice
# cuántos fueron y por qué, así que el número de SKIP es revisable y no
# un lugar donde esconder cosas.
#
# Un transcripto que no puede calzar nunca —tiempos de `kai bench`,
# salida larga reformateada para la página— se marca en el capítulo con
# un comentario justo antes de la cerca:
#
#     <!-- transcripto: tiempos, cambian en cada corrida -->
#
# El motivo es obligatorio y sale en el reporte con `-v`: un transcripto
# sin verificar y sin razón escrita es exactamente lo que este script
# existe para no dejar pasar.
#
# La comparación ignora los espacios al final de cada línea y las líneas
# en blanco del final, que ni el libro ni un editor conservan de forma
# confiable.
#
# Salida: tabla con OK / FAIL / SKIP.

set -u
export KAI_BACKEND="${KAI_BACKEND:-c}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d -t kaikai-book-transcripts.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

VERBOSE=0
DIRS=("capitulos" "chapters")
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    es) DIRS=("capitulos") ;;
    en) DIRS=("chapters") ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
  esac
done

# ------------------------------------------------------------
# Extracción: un índice de bloques candidatos y, por cada uno, el
# archivo con la salida que el libro promete.
# ------------------------------------------------------------
IDX="$TMP/index"
: > "$IDX"

for dir in "${DIRS[@]}"; do
  for md in "$ROOT/$dir"/*.md; do
    [ -f "$md" ] || continue
    awk -v tmp="$TMP" -v idx="$IDX" -v md="$md" '
      function flush() {
        if (ok) {
          n++
          out = tmp "/" md_tag "." n ".expected"
          for (i = 1; i <= nb; i++) print body[i] > out
          close(out)
          printf "%s\t%d\t%s\t%s\t%s\n", md, start, cmd, out, exempt >> (idx ".full")
        }
      }
      BEGIN {
        md_tag = md; gsub(/[^A-Za-z0-9]/, "_", md_tag)
        inb = 0; n = 0
      }
      # La marca de exención viaja en un comentario antes de la cerca.
      /^<!-- *transcripto:/ {
        pending = $0
        sub(/^<!-- *transcripto: */, "", pending)
        sub(/ *-->.*$/, "", pending)
        next
      }

      # Toda cerca cuenta, con lenguaje o sin él: si solo siguiéramos las
      # que nos interesan, el cierre de un bloque ```kai se leería como
      # la apertura del siguiente y los pares quedarían corridos.
      /^```/ {
        if (inb) { flush(); inb = 0; pending = ""; next }
        lang = $0; sub(/^```/, "", lang)
        inb = 1; nb = 0; ok = 0; first = 1; start = NR
        exempt = pending
        plain = (lang == "" || lang == "text" || lang == "console" || lang == "sh")
        next
      }

      # Cualquier otra línea fuera de un bloque corta la marca pendiente:
      # la exención vale para la cerca que viene inmediatamente después.
      !inb && !/^ *$/ { pending = "" }
      inb {
        if (!plain) next
        if (first) {
          first = 0
          if ($0 ~ /^\$ kai /) { cmd = substr($0, 3); ok = 1 } else { ok = 0 }
          next
        }
        if (!ok) next
        # un segundo comando en el mismo bloque: no es un transcripto simple
        if ($0 ~ /^\$ /) { ok = 0; next }
        nb++; body[nb] = $0
      }
      END { if (inb) flush() }
    ' "$md"
  done
done

# ------------------------------------------------------------
# Verificación
# ------------------------------------------------------------
OK=0; FAIL=0; SKIP=0
declare -a SKIP_REASONS=()

if [ "$KAI_BACKEND" != "native" ]; then
  printf 'aviso: los transcriptos del libro están escritos contra el backend\n'
  printf '       native, que es el que obtiene un lector con `kai run`. En %s\n' "$KAI_BACKEND"
  printf '       hay diferencias legítimas (el panic de un hole, por ejemplo,\n'
  printf '       agrega el tipo esperado). Para el veredicto, corre native.\n\n'
fi

printf '%-6s  %-44s  %s\n' "ESTADO" "COMANDO" "ARCHIVO:LÍNEA"
printf '%s\n' "------------------------------------------------------------------------------"

while IFS=$'\t' read -r md line cmd expected exempt; do
  rel="${md#$ROOT/}"
  where="$rel:$line"

  if [ -n "${exempt:-}" ]; then
    SKIP=$((SKIP+1)); SKIP_REASONS+=("$where — exento: $exempt"); continue
  fi

  # comillas, pipes o continuación de línea: no lo parseamos, lo decimos
  case "$cmd" in
    *\\) SKIP=$((SKIP+1)); SKIP_REASONS+=("$where — comando multilínea"); continue ;;
    *\'*|*\"*|*\|*)
      SKIP=$((SKIP+1)); SKIP_REASONS+=("$where — comando con comillas o pipe"); continue ;;
  esac

  # saca el comentario al final de la línea
  cmd="${cmd%%#*}"
  # shellcheck disable=SC2206
  words=($cmd)

  # el objetivo es el primer argumento que parece ruta de ejemplo
  target=""
  for w in "${words[@]}"; do
    case "$w" in
      *.kai) target="$w"; break ;;
    esac
  done

  # Comandos que no nombran un archivo pero son de solo lectura y por lo
  # tanto reproducibles: la salida de `kai --version` es justo la clase
  # de transcripto que envejece sin que nadie se dé cuenta.
  if [ -z "$target" ]; then
    case "${words[1]:-}" in
      --version|env|info) target="" ;;
      *) SKIP=$((SKIP+1)); SKIP_REASONS+=("$where — el comando no nombra un .kai y no es de solo lectura"); continue ;;
    esac
  fi
  if [ -n "$target" ] && [ ! -f "$ROOT/$target" ]; then
    SKIP=$((SKIP+1)); SKIP_REASONS+=("$where — $target no existe (transcripto ilustrativo)"); continue
  fi
  if grep -qE '^\s*\.\.\.\s*$|…' "$expected"; then
    SKIP=$((SKIP+1)); SKIP_REASONS+=("$where — la salida está elidida"); continue
  fi

  # El comando se corre tal como lo escribe el libro: agregarle un `-o`
  # para no dejar binarios en el árbol rompe los modos de reporte
  # (`--holes` rechaza `-o`). Un transcripto de `kai build` que sí
  # produzca binario lleva su propio `-o` en el texto.
  run=("${words[@]}")

  actual="$TMP/actual"
  ( cd "$ROOT" && "${run[@]}" ) > "$actual.raw" 2>&1

  # El compilador imprime rutas absolutas; el libro las escribe
  # relativas. Después se normalizan los espacios de cola y las líneas
  # en blanco finales, en los dos lados.
  normalize() {
    sed -e "s|$ROOT/||g" -e 's/[[:space:]]*$//' "$1" |
      awk '{ lines[NR] = $0 } END { last = 0; for (i = 1; i <= NR; i++) if (lines[i] != "") last = i; for (i = 1; i <= last; i++) print lines[i] }'
  }
  normalize "$actual.raw" > "$actual"
  normalize "$expected"   > "$TMP/expected.norm"
  expected="$TMP/expected.norm"

  if diff -q "$expected" "$actual" > /dev/null 2>&1; then
    OK=$((OK+1))
    printf '  %-4s  %-44s  %s\n' "OK" "${cmd:0:44}" "$where"
  else
    FAIL=$((FAIL+1))
    printf '  %-4s  %-44s  %s\n' "FAIL" "${cmd:0:44}" "$where"
    if [ "$VERBOSE" = 1 ]; then
      diff -u "$expected" "$actual" | sed 's/^/        /'
    fi
  fi
done < "$IDX.full"

printf '%s\n' "=============================================================================="
printf '  OK: %d   FAIL: %d   SKIP: %d\n' "$OK" "$FAIL" "$SKIP"
printf '%s\n' "=============================================================================="

if [ "$SKIP" -gt 0 ] && [ "$VERBOSE" = 1 ]; then
  printf '\nSaltados:\n'
  for r in "${SKIP_REASONS[@]}"; do printf '  %s\n' "$r"; done
fi

[ "$FAIL" -eq 0 ]
