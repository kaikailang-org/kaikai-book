#!/usr/bin/env bash
# Builds the PDF of the kaikai book (English edition, draft).
set -euo pipefail

cd "$(dirname "$0")"
ROOT="../.."

BODY="body-en.md"
BODY_TYP="body-en.typ"
OUT="kaikai-book-en.pdf"

# --- 1. Assemble markdown -------------------------------------------------
{
  # Prologue + numbered chapters, in file-name order
  for f in "$ROOT"/chapters/ch*.md; do
    echo
    cat "$f"
    echo
  done

  echo
  echo "# Appendices"
  echo

  for f in "$ROOT"/appendices/ap*.md; do
    echo
    cat "$f"
    echo
  done
} > "$BODY"

# Make the figures reachable from the build dir under
# `figuras/`. Chapters reference them as `../figuras/...` from
# their paths in `capitulos/` and `chapters/`; we rewrite to
# `figuras/` and expose the real dir (at root) via symlink.
ln -snf "$ROOT/figuras" figuras

# Using perl -i because sed -i is incompatible between BSD
# (macOS) and GNU (Linux/CI) in its handling of the backup arg.
perl -i -pe 's|\.\./figuras/|figuras/|g' "$BODY"

# --- 2. Markdown → typst (body) -------------------------------------------
pandoc "$BODY" \
  --from=gfm \
  --to=typst \
  --wrap=preserve \
  -o "$BODY_TYP"

# Replace #horizontalrule (unknown to typst) with a visible separator.
perl -i -pe 's|^#horizontalrule$|#v(0.5em) #line(length: 30%, stroke: 0.5pt) #v(0.5em)|g' "$BODY_TYP"

# --- 3. Wrap with template ------------------------------------------------
cat > kaikai-book-en.typ <<'EOF'
#import "template-en.typ": book
#show: book.with(
  title: "Effective Programming with kaikai",
  subtitle: "A language for humans and agents",
  author: "Eduardo Díaz",
  year: 2026,
)

#include "body-en.typ"
EOF

# --- 4. Compile PDF -------------------------------------------------------
typst compile kaikai-book-en.typ "$OUT"

echo
echo "PDF generated: $(pwd)/$OUT"
ls -lh "$OUT"
