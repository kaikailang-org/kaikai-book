#!/usr/bin/env bash
# Construye el PDF del libro kaikai (edición en español, borrador).
set -euo pipefail

cd "$(dirname "$0")"
ROOT="../.."

BODY="body.md"
BODY_TYP="body.typ"
OUT="kaikai-libro-es.pdf"

# --- 1. Ensamblar markdown -------------------------------------------------
{
  # Prólogo + capítulos numerados, en orden de nombre de archivo
  for f in "$ROOT"/capitulos/cap*.md; do
    echo
    cat "$f"
    echo
  done

  echo
  echo "# Apéndices"
  echo

  for f in "$ROOT"/apendices/ap*.md; do
    echo
    cat "$f"
    echo
  done
} > "$BODY"

# Asegurar que las figuras estén accesibles desde el dir de
# build con el path `figuras/`. Los capítulos las referencian
# como `../figuras/...` desde sus rutas en `capitulos/` y
# `chapters/`; reescribimos a `figuras/` y exponemos el dir
# real (en raíz) vía symlink.
ln -snf "$ROOT/figuras" figuras

# Usamos perl -i porque sed -i es incompatible entre BSD (macOS)
# y GNU (Linux/CI) en el manejo del argumento de backup.
perl -i -pe 's|\.\./figuras/|figuras/|g' "$BODY"

# --- 2. Markdown → typst (cuerpo) -----------------------------------------
# (pandoc invocation below)

# Strip raw HTML <hr/> separators rendered as ``---`` (pandoc emits
# #horizontalrule which typst doesn't define). We map them to a small
# vertical gap instead.

# --- 2. Markdown → typst (cuerpo) -----------------------------------------
pandoc "$BODY" \
  --from=gfm \
  --to=typst \
  --wrap=preserve \
  -o "$BODY_TYP"

# Replace #horizontalrule (unknown to typst) with a visible separator.
perl -i -pe 's|^#horizontalrule$|#v(0.5em) #line(length: 30%, stroke: 0.5pt) #v(0.5em)|g' "$BODY_TYP"

# --- 3. Envolver con plantilla --------------------------------------------
cat > kaikai-libro-es.typ <<'EOF'
#import "template.typ": book
#show: book.with(
  title: "Programación simple con kaikai",
  subtitle: "Un lenguaje para humanos y agentes",
  author: "Eduardo Díaz",
  year: 2026,
)

#include "body.typ"
EOF

# --- 4. Compilar PDF ------------------------------------------------------
typst compile kaikai-libro-es.typ "$OUT"

echo
echo "PDF generado: $(pwd)/$OUT"
ls -lh "$OUT"
