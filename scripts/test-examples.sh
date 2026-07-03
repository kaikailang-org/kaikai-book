#!/usr/bin/env bash
# Corre todos los ejemplos del libro contra el `kai` instalado.
# Uso:
#   scripts/test-examples.sh            # corre todo
#   scripts/test-examples.sh es         # solo edición español
#   scripts/test-examples.sh en         # solo edición inglés
#   scripts/test-examples.sh -v         # verbose (muestra output de cada caso)
#
# Backend C por defecto. Salida: tabla con OK / FAIL / XFAIL / XPASS.
# XFAIL = falla esperada (bug conocido, demo deliberada).
# XPASS = pasó algo que esperábamos que fallara — revisar.

set -u
export KAI_BACKEND=c

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d -t kaikai-book-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

VERBOSE=0
FILTER=""
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    es) FILTER="ejemplos" ;;
    en) FILTER="examples" ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
  esac
done

# ============================================================
# Manifiesto: cada línea es "modo|ruta|expect"
#   modo:   build | run | test | bench | check | project
#   ruta:   relativa a $ROOT (archivo o directorio para project)
#   expect: ok | fail | run_panic
#
# Casos especiales documentados:
#   - cap07/02_assert_*: el test demuestra un assert que falla → expect=fail
#   - cap15/*: holes que abortan en runtime → expect=run_panic
#   - cap14/03,05 + cap17 + cap18: bugs/refactors pendientes en 0.68 → expect=fail
# ============================================================

read -r -d '' MANIFEST <<'EOF' || true
# Capítulo 1 — tour
build|ejemplos/cap01/01_hola.kai|ok
build|ejemplos/cap01/02_fizzbuzz.kai|ok
build|ejemplos/cap01/03_calculadora.kai|ok
build|ejemplos/cap01/04_efecto.kai|ok
build|ejemplos/cap01/05_concurrente.kai|ok
test|ejemplos/cap01/06_pruebas.kai|ok
build|ejemplos/cap01/07_protocolos.kai|ok
build|ejemplos/cap01/08_unidades.kai|ok
build|ejemplos/cap01/09_contratos.kai|ok
build|ejemplos/cap01/10_holes.kai|ok

# Capítulo 3 — tipos básicos
build|ejemplos/cap03/01_aritmetica.kai|ok
build|ejemplos/cap03/02_strings.kai|ok
build|ejemplos/cap03/03_let_if.kai|ok
build|ejemplos/cap03/04_bloques.kai|ok
build|ejemplos/cap03/05_ancho_fijo.kai|ok
build|ejemplos/cap03/06_numeros_grandes.kai|ok

# Capítulo 4 — tipos compuestos
build|ejemplos/cap04/01_records.kai|ok
build|ejemplos/cap04/02_destructuring.kai|ok
build|ejemplos/cap04/03_listas.kai|ok
build|ejemplos/cap04/04_option_result.kai|ok
build|ejemplos/cap04/05_tuplas.kai|ok
build|ejemplos/cap04/06_priv.kai|ok

# Capítulo 5 — pattern matching
build|ejemplos/cap05/01_sumas_basicas.kai|ok
build|ejemplos/cap05/02_recursivos.kai|ok
build|ejemplos/cap05/03_match_guardas.kai|ok
build|ejemplos/cap05/04_uniones.kai|ok
build|ejemplos/cap05/05_evaluador.kai|ok

# Capítulo 6 — funciones
build|ejemplos/cap06/01_funciones.kai|ok
build|ejemplos/cap06/02_lambdas.kai|ok
build|ejemplos/cap06/03_orden_superior.kai|ok
build|ejemplos/cap06/04_pipes.kai|ok
build|ejemplos/cap06/05_recursion_tco.kai|ok
build|ejemplos/cap06/06_pipeline.kai|ok
build|ejemplos/cap06/07_pipe_underscore.kai|ok
build|ejemplos/cap06/08_trailing_y_bloques.kai|ok

# Capítulo 7 — tests / bench / check
test|ejemplos/cap07/01_test_basico.kai|ok
test|ejemplos/cap07/02_assert_falla.kai|fail
check|ejemplos/cap07/03_check_propiedades.kai|ok
bench|ejemplos/cap07/04_bench_basico.kai|ok
test|ejemplos/cap07/05_evaluador_pruebas.kai|ok

# Capítulo 8 — módulos (proyectos multi-archivo)
project|ejemplos/cap08/01_un_archivo|ok
project|ejemplos/cap08/02_dos_archivos|ok
project|ejemplos/cap08/02b_selectivo|ok
project|ejemplos/cap08/03_qualified|ok
project|ejemplos/cap08/04_alias|ok
project|ejemplos/cap08/05_proyecto|ok
project|ejemplos/cap08/06_priv|ok

# Capítulo 9 — protocolos
build|ejemplos/cap09/01_protocolo_basico.kai|ok
build|ejemplos/cap09/02_eq_ord.kai|ok
build|ejemplos/cap09/03_derive.kai|ok
build|ejemplos/cap09/04_protocolo_propio.kai|ok

# Capítulo 10 — unidades
build|ejemplos/cap10/01_unidades_basicas.kai|ok
build|ejemplos/cap10/02_algebra_unidades.kai|ok
build|ejemplos/cap10/03_alias.kai|ok
build|ejemplos/cap10/04_genericas.kai|ok
build|ejemplos/cap10/05_branded.kai|ok
build|ejemplos/cap10/06_cartera.kai|ok

# Capítulo 11 — contratos
build|ejemplos/cap11/01_contratos_basicos.kai|ok
build|ejemplos/cap11/02_violacion.kai|ok
build|ejemplos/cap11/03_cuenta_bancaria.kai|ok
build|ejemplos/cap11/04_refinements.kai|ok

# Capítulo 12 — efectos
build|ejemplos/cap12/01_log_basico.kai|ok
build|ejemplos/cap12/02_dos_handlers.kai|ok
build|ejemplos/cap12/03_ask.kai|ok
build|ejemplos/cap12/04_fail.kai|ok
build|ejemplos/cap12/05_state.kai|ok
build|ejemplos/cap12/06_composicion.kai|ok
build|ejemplos/cap12/07_alias.kai|ok
build|ejemplos/cap12/08_parser_config.kai|ok
build|ejemplos/cap12/09_wrapper_default.kai|ok
build|ejemplos/cap12/10_var_local.kai|ok
build|ejemplos/cap12/11_instancias.kai|ok

# Capítulo 13 — fibras
build|ejemplos/cap13/01_dos_fibras.kai|ok
build|ejemplos/cap13/02_nursery.kai|ok
build|ejemplos/cap13/03_cancel.kai|ok
build|ejemplos/cap13/04_race.kai|ok
build|ejemplos/cap13/05_worker_pool.kai|ok
build|ejemplos/cap13/06_eco_concurrente.kai|ok

# Capítulo 14 — actores
build|ejemplos/cap14/01_with_mailbox.kai|ok
build|ejemplos/cap14/02_spawn_actor.kai|ok
build|ejemplos/cap14/03_request_reply.kai|ok
build|ejemplos/cap14/04_mailbox_policy.kai|ok
build|ejemplos/cap14/05_supervisor.kai|ok

# Capítulo 15 — holes (compilan, abortan en runtime al llegar al hole)
run|ejemplos/cap15/01_hole_basico.kai|run_panic
build|ejemplos/cap15/02_programa_parcial.kai|ok
build|ejemplos/cap15/03_hole_compartido.kai|ok
build|ejemplos/cap15/04_hole_en_patron.kai|ok
build|ejemplos/cap15/05_diseno_top_down.kai|ok

# Capítulo 16 — FFI
build|ejemplos/cap16/ffi/01_libc_abs.kai|ok
build|ejemplos/cap16/ffi/02_renombre.kai|ok
project|ejemplos/cap16/ffi/03_shim|ok|app.kai|-include shim.h shim.c

# Capítulo 17 — caso notas
project|ejemplos/cap17/notas|ok

# Capítulo 18 — caso ledger
project|ejemplos/cap18/ledger|ok

# ===== Edición inglés =====

# Chapter 1
build|examples/ch01/01_hello.kai|ok
build|examples/ch01/02_fizzbuzz.kai|ok
build|examples/ch01/03_calculator.kai|ok
build|examples/ch01/04_effect.kai|ok
build|examples/ch01/05_concurrent.kai|ok
test|examples/ch01/06_tests.kai|ok
build|examples/ch01/07_protocols.kai|ok
build|examples/ch01/08_units.kai|ok
build|examples/ch01/09_contracts.kai|ok
build|examples/ch01/10_holes.kai|ok

# Chapter 3
build|examples/ch03/01_arithmetic.kai|ok
build|examples/ch03/02_strings.kai|ok
build|examples/ch03/03_let_if.kai|ok
build|examples/ch03/04_blocks.kai|ok
build|examples/ch03/05_fixed_width.kai|ok
build|examples/ch03/06_big_numbers.kai|ok

# Chapter 4
build|examples/ch04/01_records.kai|ok
build|examples/ch04/02_destructuring.kai|ok
build|examples/ch04/03_lists.kai|ok
build|examples/ch04/04_option_result.kai|ok
build|examples/ch04/05_tuples.kai|ok
build|examples/ch04/06_priv.kai|ok

# Chapter 5
build|examples/ch05/01_basic_sums.kai|ok
build|examples/ch05/02_recursive.kai|ok
build|examples/ch05/03_match_guards.kai|ok
build|examples/ch05/04_unions.kai|ok
build|examples/ch05/05_evaluator.kai|ok

# Chapter 6
build|examples/ch06/01_functions.kai|ok
build|examples/ch06/02_lambdas.kai|ok
build|examples/ch06/03_higher_order.kai|ok
build|examples/ch06/04_pipes.kai|ok
build|examples/ch06/05_recursion_tco.kai|ok
build|examples/ch06/06_pipeline.kai|ok
build|examples/ch06/07_pipe_underscore.kai|ok
build|examples/ch06/08_trailing_blocks.kai|ok

# Chapter 7
test|examples/ch07/01_basic_test.kai|ok
test|examples/ch07/02_assert_fails.kai|fail
check|examples/ch07/03_check_properties.kai|ok
bench|examples/ch07/04_basic_bench.kai|ok
test|examples/ch07/05_evaluator_tests.kai|ok

# Chapter 8
project|examples/ch08/01_one_file|ok
project|examples/ch08/02_two_files|ok
project|examples/ch08/02b_selective|ok
project|examples/ch08/03_qualified|ok
project|examples/ch08/04_alias|ok
project|examples/ch08/05_project|ok
project|examples/ch08/06_priv|ok

# Chapter 9
build|examples/ch09/01_basic_protocol.kai|ok
build|examples/ch09/02_eq_ord.kai|ok
build|examples/ch09/03_derive.kai|ok
build|examples/ch09/04_own_protocol.kai|ok

# Chapter 10
build|examples/ch10/01_basic_units.kai|ok
build|examples/ch10/02_unit_algebra.kai|ok
build|examples/ch10/03_alias.kai|ok
build|examples/ch10/04_generic.kai|ok
build|examples/ch10/05_branded.kai|ok
build|examples/ch10/06_wallet.kai|ok

# Chapter 11
build|examples/ch11/01_basic_contracts.kai|ok
build|examples/ch11/02_violation.kai|ok
build|examples/ch11/03_bank_account.kai|ok
build|examples/ch11/04_refinements.kai|ok

# Chapter 12
build|examples/ch12/01_log_basic.kai|ok
build|examples/ch12/02_two_handlers.kai|ok
build|examples/ch12/03_ask.kai|ok
build|examples/ch12/04_fail.kai|ok
build|examples/ch12/05_state.kai|ok
build|examples/ch12/06_composition.kai|ok
build|examples/ch12/07_alias.kai|ok
build|examples/ch12/08_config_parser.kai|ok
build|examples/ch12/09_wrapper_default.kai|ok
build|examples/ch12/10_local_var.kai|ok
build|examples/ch12/11_instances.kai|ok

# Chapter 13
build|examples/ch13/01_two_fibers.kai|ok
build|examples/ch13/02_nursery.kai|ok
build|examples/ch13/03_cancel.kai|ok
build|examples/ch13/04_race.kai|ok
build|examples/ch13/05_worker_pool.kai|ok
build|examples/ch13/06_task_queue.kai|ok

# Chapter 14
build|examples/ch14/01_with_mailbox.kai|ok
build|examples/ch14/02_spawn_actor.kai|ok
build|examples/ch14/03_request_reply.kai|ok
build|examples/ch14/04_mailbox_policy.kai|ok
build|examples/ch14/05_supervisor.kai|ok

# Chapter 15 — holes
run|examples/ch15/01_basic_hole.kai|run_panic
build|examples/ch15/02_partial_program.kai|ok
build|examples/ch15/03_shared_hole.kai|ok
build|examples/ch15/04_hole_in_pattern.kai|ok
build|examples/ch15/05_top_down_design.kai|ok

# Chapter 16
build|examples/ch16/ffi/01_libc_abs.kai|ok
build|examples/ch16/ffi/02_rename.kai|ok
project|examples/ch16/ffi/03_shim|ok|app.kai|-include shim.h shim.c

# Chapter 17
project|examples/ch17/notes|ok

# Chapter 18
project|examples/ch18/ledger|ok
EOF

# ============================================================
# Ejecución
# ============================================================

OK=0; FAIL=0; XFAIL=0; XPASS=0; SKIP=0
FAILED_LINES=""
XPASS_LINES=""

run_case() {
  local mode="$1" path="$2" expect="$3" entry="${4:-main.kai}" cflags="${5:-}"
  local cwd target out rc
  local key="$path"

  case "$mode" in
    project)
      cwd="$ROOT/$path"
      target="$entry"
      ;;
    *)
      cwd="$ROOT/$(dirname "$path")"
      target="$(basename "$path")"
      ;;
  esac

  if [ ! -e "$cwd/$target" ]; then
    SKIP=$((SKIP+1))
    printf "  %-7s %-60s %s\n" "SKIP" "$key" "(no existe)"
    return
  fi

  case "$mode" in
    build|project)
      out=$(cd "$cwd" && CFLAGS="$cflags" kai build "$target" -o "$TMP/bin" 2>&1); rc=$?
      ;;
    run)
      out=$(cd "$cwd" && kai run "$target" 2>&1); rc=$?
      ;;
    test)
      out=$(cd "$cwd" && kai test "$target" 2>&1); rc=$?
      ;;
    bench)
      out=$(cd "$cwd" && kai bench --iters 1 "$target" 2>&1); rc=$?
      ;;
    check)
      out=$(cd "$cwd" && kai check "$target" 2>&1); rc=$?
      ;;
  esac

  rm -f "$TMP/bin"

  local status
  case "$expect" in
    ok)
      if [ $rc -eq 0 ]; then status="OK"; OK=$((OK+1))
      else status="FAIL"; FAIL=$((FAIL+1)); FAILED_LINES+="$key|$out"$'\n---\n'
      fi
      ;;
    fail)
      if [ $rc -ne 0 ]; then status="XFAIL"; XFAIL=$((XFAIL+1))
      else status="XPASS"; XPASS=$((XPASS+1)); XPASS_LINES+="$key (esperábamos fail)"$'\n'
      fi
      ;;
    run_panic)
      if [ $rc -ne 0 ] && echo "$out" | grep -q "unfilled hole"; then
        status="XFAIL"; XFAIL=$((XFAIL+1))
      elif [ $rc -eq 0 ]; then
        status="XPASS"; XPASS=$((XPASS+1)); XPASS_LINES+="$key (esperábamos hole panic)"$'\n'
      else
        status="FAIL"; FAIL=$((FAIL+1)); FAILED_LINES+="$key|$out"$'\n---\n'
      fi
      ;;
  esac

  printf "  %-7s %-60s [%s]\n" "$status" "$key" "$mode"
  if [ "$VERBOSE" -eq 1 ] && [ -n "$out" ]; then
    echo "$out" | sed 's/^/         /'
  fi
}

echo "kaikai: $(kai --version | head -1)"
echo "backend: $KAI_BACKEND"
echo ""

while IFS= read -r line; do
  # saltar comentarios y vacías
  case "$line" in
    ''|\#*) continue ;;
  esac
  if [ -n "$FILTER" ] && ! echo "$line" | grep -q "|$FILTER/"; then
    continue
  fi
  IFS='|' read -r mode path expect entry cflags <<< "$line"
  run_case "$mode" "$path" "$expect" "$entry" "$cflags"
done <<< "$MANIFEST"

echo ""
echo "=============================================================="
printf "  OK: %d   XFAIL: %d   FAIL: %d   XPASS: %d   SKIP: %d\n" \
  "$OK" "$XFAIL" "$FAIL" "$XPASS" "$SKIP"
echo "=============================================================="

if [ -n "$XPASS_LINES" ]; then
  echo ""
  echo "XPASS (revisar — pasaron casos marcados como fallidos):"
  echo "$XPASS_LINES" | sed 's/^/  /'
fi

if [ -n "$FAILED_LINES" ]; then
  echo ""
  echo "FAIL (inesperadas):"
  echo "$FAILED_LINES" | sed 's/^/  /'
fi

# Exit 0 si no hay FAIL ni XPASS; los XFAIL son aceptables.
if [ "$FAIL" -gt 0 ] || [ "$XPASS" -gt 0 ]; then
  exit 1
fi
exit 0
