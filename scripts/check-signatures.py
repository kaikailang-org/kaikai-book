#!/usr/bin/env python3
"""Compara las firmas de efectos del apéndice D contra el stdlib instalado.

Uso:
  scripts/check-signatures.py            # verifica ambas ediciones
  scripts/check-signatures.py --list     # imprime las firmas reales del stdlib

El apéndice D es referencia que nadie compila, así que deriva en silencio
cuando el stdlib cambia. Esto lo detecta: por cada bloque ```kai que declare
un `effect X { ... }`, compara el conjunto de operaciones contra la
declaración real y reporta las que sobran, faltan o cambiaron de firma.

Salida 0 si todo calza; 1 si hay diferencias.
"""

import re
import subprocess
import sys
from pathlib import Path

# Efectos que el libro declara con fines didácticos y no vienen en el stdlib.
# Cada entrada necesita una razón: sin ella no se distingue de una omisión.
NOT_IN_STDLIB = {
    "Fail": "patrón de ejemplo; el lector lo declara en su propio código",
    "Io": "efecto inventado para ilustrar varias ops en una declaración",
}

APPENDICES = [
    "apendices/apD-efectos.md",
    "appendices/apD-effects.md",
]


def stdlib_root() -> Path:
    """Localiza el stdlib de la instalación activa de kai."""
    kai = subprocess.run(["which", "kai"], capture_output=True, text=True)
    if kai.returncode != 0:
        sys.exit("no encuentro `kai` en el PATH")
    # ~/.kaikai/bin/kai -> ~/.kaikai/share/kaikai/stdlib
    root = Path(kai.stdout.strip()).resolve().parent.parent / "share" / "kaikai" / "stdlib"
    if not root.is_dir():
        sys.exit(f"no encuentro el stdlib en {root}")
    return root


def parse_effects(text: str, pub_only: bool) -> dict[str, dict[str, str]]:
    """{nombre_efecto: {op: firma}} para cada `effect X { ... }` del texto.

    Se recorre por líneas contando llaves: una regex sobre el bloque entero
    se pasa de largo cuando un efecto anida su bloque `default { }`.
    """
    head = re.compile((r"pub " if pub_only else r"") + r"effect\s+(\w+)(?:\[[^\]]*\])?\s*\{")
    op_re = re.compile(r"(\w+)\s*(?:\[[^\]]*\])?\s*\((.*?)\)\s*:\s*(.+?)\s*(?:#.*)?$")

    out: dict[str, dict[str, str]] = {}
    name: str | None = None
    depth = 0
    ops: dict[str, str] = {}

    for line in text.splitlines():
        if name is None:
            m = head.search(line)
            if m and (pub_only or not line.lstrip().startswith("pub ")):
                name, ops = m.group(1), {}
                # Un efecto sin ops cabe en una línea (`effect Ffi {}`).
                depth = 1 + line[m.end() :].count("{") - line[m.end() :].count("}")
                if depth <= 0:
                    out[name] = ops
                    name = None
            continue

        depth += line.count("{") - line.count("}")
        if depth <= 0:
            out[name] = ops
            name = None
            continue

        # Dentro de `default { }` van handlers, no operaciones.
        if depth > 1:
            continue
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("default"):
            continue
        om = op_re.match(stripped)
        if om:
            ops[om.group(1)] = f"({om.group(2)}) : {om.group(3)}"

    return out


def load_stdlib(root: Path) -> dict[str, dict[str, str]]:
    effects: dict[str, dict[str, str]] = {}
    for f in sorted(root.rglob("*.kai")):
        effects.update(parse_effects(f.read_text(), pub_only=True))
    return effects


def kai_blocks(text: str) -> str:
    """Solo el contenido de los bloques ```kai: una mención de `effect X { … }`
    en medio de un párrafo no es una tabla de firmas."""
    return "\n".join(re.findall(r"^```kai\n(.*?)^```", text, re.S | re.M))


def join_wrapped(text: str) -> str:
    """Une una firma partida en varias líneas: un paréntesis sin cerrar
    continúa en la siguiente."""
    out, buf, depth = [], "", 0
    for line in text.splitlines():
        buf = line if not buf else buf.rstrip() + " " + line.strip()
        depth += line.count("(") - line.count(")")
        if depth <= 0:
            out.append(buf)
            buf, depth = "", 0
    if buf:
        out.append(buf)
    return "\n".join(out)


def check(path: Path, std: dict[str, dict[str, str]]) -> list[str]:
    problems = []
    book = parse_effects(join_wrapped(kai_blocks(path.read_text())), pub_only=False)
    for name, ops in sorted(book.items()):
        if name in NOT_IN_STDLIB:
            continue
        real = std.get(name)
        if real is None:
            problems.append(f"{name}: el libro lo declara, el stdlib no lo tiene")
            continue
        for op in sorted(set(ops) - set(real)):
            problems.append(f"{name}.{op}: no existe (reales: {', '.join(sorted(real)) or 'ninguna'})")
        for op in sorted(set(real) - set(ops)):
            problems.append(f"{name}.{op}: falta en el apéndice")
        for op in sorted(set(ops) & set(real)):
            a, b = norm(ops[op]), norm(real[op])
            if a != b:
                problems.append(f"{name}.{op}: firma distinta\n      libro:  {ops[op]}\n      stdlib: {real[op]}")
    return problems


def norm(sig: str) -> str:
    """Compara firmas ignorando espacios y nombres de parámetros."""
    sig = re.sub(r"\s+", "", sig)
    return re.sub(r"\w+:", "", sig)


def main() -> int:
    root = stdlib_root()
    std = load_stdlib(root)

    if "--list" in sys.argv:
        for name, ops in sorted(std.items()):
            print(f"effect {name} {{")
            for op, sig in sorted(ops.items()):
                print(f"  {op}{sig}")
            print("}\n")
        return 0

    print(f"stdlib: {root}  ({len(std)} efectos)\n")
    failed = False
    for rel in APPENDICES:
        path = Path(__file__).resolve().parent.parent / rel
        if not path.exists():
            print(f"  SKIP  {rel} (no existe)")
            continue
        problems = check(path, std)
        if problems:
            failed = True
            print(f"  FAIL  {rel}")
            for p in problems:
                print(f"    - {p}")
        else:
            print(f"  OK    {rel}")

    if failed:
        print("\nEl apéndice no calza con el stdlib instalado.")
        print("Corrige el apéndice, o agrega el efecto a NOT_IN_STDLIB con su razón.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
