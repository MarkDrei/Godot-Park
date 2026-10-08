# Testing and debugging notes

Practical lessons from working on this project. Each one cost time once; read this before
debugging, and add to it when you learn something new (see `CLAUDE.md`).

## Quick reference

| Goal | Command | Duration |
|---|---|---|
| Unit tests only | `scripts/test.sh unit` | ~1 min |
| Everything (unit, smoke, half-day simulation) | `scripts/test.sh` | 10+ min, run in the background |
| GDScript errors in the whole project | `scripts/check.sh` | ~1 min |
| Parse a single script | `~/.local/opt/godot-park/godot-4.7.2/godot --headless --path . --check-only -s src/x.gd` | seconds |
| Native run with dev options | `godot --headless --path . --quit-after 1500 -- --control=jens --minigame=boule` | ~1 min |
| Browser screenshots | `scripts/web_test.sh <preset> …` (presets in `tests/web/shots.cjs`) | ~3 min incl. export |
| Release | `scripts/release.sh "msg"` | ~3 min |

Look at screenshots in `build/screenshots/*.png` with the Read tool. That is the only way to check
visuals, layout and placement.

## Finding errors

- `check.sh` often shows only the end of a chain of errors ("Could not resolve class BouleGame,
  because of a parser error"), not the cause. To get the real line, parse that script on its own
  with `--check-only -s`. Errors like "Identifier not found: GameState/UI" are expected there,
  because autoloads are missing when a single script is checked.
- "Expected statement, found elif" means new code was inserted in the middle of an
  `if/elif` chain. Put shared per-frame code after the whole chain.
- For behaviour that depends on input or timing, add a temporary `print("DBG …")`, run natively
  with `--quit-after N` and dev options, then grep the output for `DBG`. Remove the prints afterwards
  (`grep -c DBG` should print 0).

## Test suite behaviour

- `test.sh` returns a non-zero exit code on failure. Piping it (`| tail`) hides that, so redirect
  to a log file and check `$?`, or grep for `TESTS FAILED`.
- Unit tests must use the game's constants (e.g. `Food.GOURMET`), not copies of lists. Copies
  break as soon as content is added.
- The half-day simulation is noisy: `stuck_total` varied between 7 and 33 across runs of the
  same code. Most entries are swimming ducks (`fritz/swim`, `gustav/swim`) and the jogger. Never
  judge a change by the total. Compare the `TEST STUCK` breakdown, and run a baseline with
  `git stash` → simulation → `git stash pop` when in doubt.
- The smoke test drives minigames by calling their methods directly (`_player_throw()` …). It
  proves the logic runs, not that input or the camera work.

## Browser (web) tests

- Load time in headless Chromium varies by several seconds, so presets that depend on timing
  (e.g. "screenshot during the throw") are flaky. Prefer static presets (`freeze=1`, `cam=…`) or
  states that last.
- Simulated input does not reliably reach the game in headless Chromium: Playwright clicks and key
  presses, and even `Input.parse_input_event` via the `press=` dev option, did not trigger a boule
  throw there, although the same `press=` works natively. Verify input-driven logic natively.
- The bundled UI font lacks symbols such as ▼ ▲ (they render as boxes). Draw shapes with
  `draw_colored_polygon` instead of using special characters.

## Dev options that help testing

All options are in `src/game/dev_options.gd`. They work as URL query or CLI args after `--`.

- `cam=x,y,z,tx,ty,tz` + `freeze=1`: fixed camera, e.g. to check placement of new props.
- `control=<id>`, `minigame=<id>`: start directly in a minigame.
- `sit=1`: tired player on the nearest bench (fatigue recovery, HUD trend arrows).
- `press=<action>@<s>[@<repeat s>]`: simulated input (native runs).
- `stats=1 speed=6`: simulation statistics, used by `test.sh`.

## Game-specific pitfalls

- Camera override (`camera.set_override`) jumps straight to the new transform once the initial
  blend is done. For smooth camera moves inside a minigame, interpolate eye and look-at yourself
  every frame (see `BouleGame._focus`).
- NPC speech bubbles are huge when the NPC stands close to the camera. Keep minigame hosts out of
  the camera's picture.
- New props near paths: trees and benches avoid `PLACES[id].r`. A small radius lets trees grow
  directly behind a stand. Check new placements with a `cam=` screenshot.
- Speed changes for the player must not count as "running" for needs: `Actor._need_state` compares
  against `walk_speed * _speed_boost()`.

## Deploy and platform

- `scripts/release.sh` runs the unit tests, commits, pushes `main`, waits for the webhook deploy
  in `~/clones/config/logs/deploys.jsonl` and checks the live site, download page and APK.
- The deploy dashboard code lives in `~/clones/config/webhook` (platform repo, owned by the
  orchestrator). Changes there need a webhook restart (`kill` the node process, systemd restarts
  it). That restart is the user's call; the session may not do it.
