#!/usr/bin/env bash
# Runs scenario tests (tests/scenarios/*.gd) natively and headless, one process per file
# (JOBS=n runs n files at once). Exit code != 0 on failure. Catalogue: doc/test-scenarios.md.
#   scripts/scenario.sh                 # all scenario files
#   scripts/scenario.sh bench boule     # some files
#   scripts/scenario.sh bench:test_nap_via_touch_button   # one test
#   scripts/scenario.sh --changed       # the files that cover what changed since origin/main
#   scripts/scenario.sh --changed=HEAD  # … since another commit (working tree and untracked
#                                       # files count); map: tests/scenario_map.txt
#   LIST=1 scripts/scenario.sh --changed   # only print the files it would run
#   JOBS=1 SEED=7 scripts/scenario.sh   # parallel processes (default 3), seed (default 1)
# Memory: a run needs ~220 MB; each process is capped at GODOT_MEM (default 1G here), so
# even 3 runaway processes stay within 3 GB.
#   VERBOSE=1 scripts/scenario.sh bench # also print the game's other output lines
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/scripts/godot.sh"   # memory-limited (see godot.sh)
JOBS="${JOBS:-3}"
export GODOT_MEM="${GODOT_MEM:-1G}"
SEED="${SEED:-1}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# The scenario files that cover the changed paths (tests/scenario_map.txt); "*" = all files.
changed_specs() {
  local base="$1" path line g f hit all=0 globs files
  local -A want=()
  base="$(git -C "$ROOT" merge-base "$base" HEAD)" || { echo "*"; return; }
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ "$path" == tests/scenarios/*.gd ]]; then
      [[ -f "$ROOT/$path" ]] && want[$(basename "$path" .gd)]=1
      continue
    fi
    hit=0
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
      read -ra globs <<<"${line%% : *}"   # read -a: no pathname expansion of the globs
      read -ra files <<<"${line#* : }"
      for g in "${globs[@]}"; do
        # shellcheck disable=SC2053  # $g is a glob
        if [[ "$path" == $g ]]; then
          hit=1
          for f in "${files[@]}"; do
            case "$f" in
              "*") all=1 ;;
              -) ;;
              *) want[$f]=1 ;;
            esac
          done
          break
        fi
      done
    done <"$ROOT/tests/scenario_map.txt"
    [[ $hit == 0 ]] && { echo "  no rule in tests/scenario_map.txt for $path: running all files" >&2; all=1; }
  done < <(git -C "$ROOT" diff --name-only "$base"; git -C "$ROOT" ls-files --others --exclude-standard)
  if [[ $all == 1 ]]; then echo "*"; elif [[ ${#want[@]} -gt 0 ]]; then printf "%s\n" "${!want[@]}" | sort; fi
}

specs=()
for a in "$@"; do
  if [[ "$a" == --changed* ]]; then
    base="origin/main"; [[ "$a" == --changed=* ]] && base="${a#--changed=}"
    mapfile -t picked < <(changed_specs "$base")
    if [[ "${picked[0]:-}" == "*" ]]; then
      echo "changed since $base: all scenario files"
      specs=(); break
    fi
    if [[ ${#picked[@]} == 0 ]]; then
      echo "changed since $base: no scenario files"; exit 0
    fi
    echo "changed since $base: ${picked[*]}"
    specs+=("${picked[@]}")
  else
    specs+=("$a")
  fi
done
if [[ ${#specs[@]} == 0 ]]; then
  for f in "$ROOT"/tests/scenarios/*.gd; do specs+=("$(basename "$f" .gd)"); done
fi
[[ "${LIST:-0}" == 1 ]] && { printf '%s\n' "${specs[@]}"; exit 0; }
[[ "${SKIP_IMPORT:-0}" == 1 ]] || timeout 300 "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

run_one() {
  local spec="$1" log="$OUT/${1//:/_}.log"
  /usr/bin/time -f "%M %e" -o "$log.mem" timeout 900 "$GODOT" --headless --path "$ROOT" --fixed-fps 30 -- \
    --scenario="$spec" --seed="$SEED" --time=11 --season=1 --weather=0 >"$log" 2>&1
  echo $? >"$log.rc"
}
export -f run_one
export GODOT ROOT OUT SEED
t0=$(date +%s)
printf '%s\n' "${specs[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}

fail=0
for spec in "${specs[@]}"; do
  log="$OUT/${spec//:/_}.log"
  if [[ "${VERBOSE:-0}" == 1 ]]; then cat "$log"; else grep -E "^SCENARIO|^    |SCRIPT ERROR|SHADER ERROR|^ERROR|^\s+at: .*res://" "$log"; fi
  grep -q "^SCENARIO DONE .* 0 failed" "$log" || fail=1
  grep -q "SCRIPT ERROR" "$log" && { echo "  (script errors in $spec)"; fail=1; }
  grep -q "SHADER ERROR" "$log" && { echo "  (shader errors in $spec)"; fail=1; }
  rc=$(cat "$log.rc")
  read -r kb secs < <(tail -1 "$log.mem" 2>/dev/null || echo "0 0")
  mem=$(( ${kb:-0} / 1024 ))
  [[ $rc == 137 ]] && echo "  $spec: killed, over the memory limit (scripts/godot.sh)"
  [[ $rc != 0 ]] && echo "  last test started: $(grep "^  > " "$log" | tail -1)"
  [[ $rc == 124 ]] && echo "  $spec: timeout"
  echo "  $spec: ${secs%.*} s, peak memory ${mem} MB"
  [[ $rc == 0 ]] || fail=1
done
echo "scenarios: ${#specs[@]} files in $(( $(date +%s) - t0 )) s, $([[ $fail == 0 ]] && echo ok || echo FAILED)"
exit $fail
