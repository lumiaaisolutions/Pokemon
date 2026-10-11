#!/usr/bin/env bash
# Corre todas las pruebas en headless con un límite de tiempo por prueba (un error de
# script deja a Godot abierto sin terminar; el límite lo detecta como fallo).
# Uso: tools/run_tests.sh [segundos_por_prueba]   (sale con 0 solo si todo pasa)
set -u
cd "$(dirname "$0")/.."
LIMIT="${1:-420}"
TESTS=(--quit tests/smoke_test.tscn tests/test_world.tscn tests/test_player_movement.tscn tests/test_creatures.tscn tests/test_fights.tscn tests/test_battle.tscn tests/test_capture.tscn tests/test_starter.tscn tests/test_menu.tscn tests/test_town.tscn tests/test_interiors.tscn tests/test_regions.tscn tests/test_camping.tscn tests/test_rocks.tscn)
LOG_DIR="${TMPDIR:-/tmp}/pokemon_tests"
mkdir -p "$LOG_DIR"
status=0
for test in "${TESTS[@]}"; do
  log="$LOG_DIR/$(basename -- "$test" .tscn).log"
  start=$(date +%s)
  # Vigilante: Godot ignora SIGALRM, así que se lanza en segundo plano y se mata
  # con SIGKILL si se pasa del límite.
  godot --headless --path . "$test" > "$log" 2>&1 &
  pid=$!
  timed_out=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ $(( $(date +%s) - start )) -ge "$LIMIT" ]; then
      kill -9 "$pid" 2>/dev/null
      timed_out=1
      break
    fi
    sleep 1
  done
  wait "$pid" 2>/dev/null
  code=$?
  [ $timed_out -eq 1 ] && code=142
  elapsed=$(( $(date +%s) - start ))
  if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
    status=1
    [ $code -eq 142 ] && echo "TIEMPO AGOTADO ($LIMIT s): $test" || echo "FALLÓ ($code, ${elapsed}s): $test"
    grep -E "FALLO|SCRIPT ERROR|Parse Error|ERROR" "$log" | head -6 | sed 's/^/    /'
  else
    echo "ok (${elapsed}s): $test $(grep -E 'fallos' "$log" | tail -1)"
  fi
done
exit $status
