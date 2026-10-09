# Testing and debugging notes

Practical lessons from working on this project. Each one cost time once; read this before
debugging, and add to it when you learn something new (see `CLAUDE.md`).

## Quick reference

| Goal | Command | Duration |
|---|---|---|
| Unit tests only | `scripts/test.sh unit` | ~1 min |
| Scenario tests (play with real input) | `scripts/scenario.sh [file[:test]] …` (catalogue: `doc/test-scenarios.md`) | ~2 min all, seconds per file |
| Unit + scenarios | `scripts/test.sh scenarios` | ~3 min |
| Everything (unit, scenarios, smoke, half-day simulation) | `scripts/test.sh` | ~10 min, run in the background |
| GDScript errors in the whole project | `scripts/check.sh` | ~1 min |
| Parse a single script | `scripts/godot.sh --headless --path . --check-only -s src/x.gd` | seconds |
| Native run with dev options | `scripts/godot.sh --headless --path . --quit-after 1500 -- --control=jens --minigame=boule` | ~1 min |
| Browser screenshots (no input) | `scripts/web_test.sh <preset> …` (presets in `tests/web/shots.cjs`) | ~3 min incl. export |
| UI layout checks (desktop, phone, tablet; keyboard and touch) | `scripts/scenario.sh layout` | ~35 s |
| Phone screenshots of a scenario file | `scripts/web_test.sh scenario:layout` → `build/screenshots/layout/` | ~20 min, background |
| Release | `scripts/release.sh "msg"` | ~3 min |

Look at screenshots in `build/screenshots/*.png` with the Read tool. That is the only way to check
visuals, layout and placement.

## Memory (the VPS has ~8 GB, shared with everything else)

- Two sessions crashed because one Godot run took all memory. Start Godot only through
  `scripts/godot.sh`: it runs Godot in a systemd scope with `MemoryMax` (default 3G, `GODOT_MEM`)
  and no swap, so only Godot gets killed (exit code 137). `scenario.sh` uses 1G per process and
  runs 3 files at once; keep all Godot/browser processes together under ~3-4 GB.
- A normal game run needs ~220 MB. `scenario.sh` prints the peak per file and "killed, over the
  memory limit" with the last started test.
- The limit only kills on real heap growth. Under memory pressure from file-backed pages (the
  binary) Godot gets slow instead; a run that times out (124) with a tiny limit is that case.
- Memory exploding within seconds usually means an endless loop that allocates. Example: a
  `while child_count > 5: get_child(0).queue_free()` loop never ends, because `queue_free`
  removes the node only at the end of the frame (`remove_child` first).

## Finding errors

- `check.sh` often shows only the end of a chain of errors ("Could not resolve class BouleGame,
  because of a parser error"), not the cause. To get the real line, parse that script on its own
  with `--check-only -s`. Errors like "Identifier not found: GameState/UI" are expected there,
  because autoloads are missing when a single script is checked.
- "Expected statement, found elif" means new code was inserted in the middle of an
  `if/elif` chain. Put shared per-frame code after the whole chain.
- For behaviour that depends on input or timing, add a temporary `print("DBG …")`, run natively
  with `--quit-after N` and dev options (or `VERBOSE=1 scripts/scenario.sh file:test`), then grep
  the output for `DBG`. Remove the prints afterwards (`grep -c DBG` should print 0).
- Godot buffers stdout into pipes: when a run is killed (timeout, memory), the last lines are
  lost. Capture with a pseudo terminal: `script -qfc "scripts/godot.sh …" out.log`. The scenario
  runner prints `  > file::test` before each test, so the log shows where it stopped.
- "Cannot infer the type of x" (parse error): `game` is an untyped `Node`, so
  `var cam := game.camera` cannot be inferred. Write `var cam: CameraRig = game.camera`.
- GDScript lambdas capture local variables by value: `n = 5` inside a lambda does not change the
  outer `n`. Return the value, or use an Array/Dictionary as a container.

## Test suite behaviour

- `test.sh` returns a non-zero exit code on failure. Piping it (`| tail`) hides that, so redirect
  to a log file and check `$?`, or grep for `TESTS FAILED`.
- Unit tests must use the game's constants (e.g. `Food.GOURMET`), not copies of lists. Copies
  break as soon as content is added.
- The simulation is reproducible now: `--fixed-fps` (fixed frame time) plus `--seed=N` gives the
  identical `TEST STATS` for the same code. Before, `stuck_total` varied between 7 and 33. A
  change in the numbers is caused by the code change, but one seed is one sample: compare a few
  seeds (`SEED=2 scripts/test.sh`) before judging a trend. Most stuck entries are swimming ducks
  and the jogger.
- `--fixed-fps 30` runs much faster than real time (smoke test 528 s → 201 s). With
  `Engine.time_scale` above ~4 at 30 fps the physics needs more than 8 steps per frame and falls
  behind: use 60 fps for speed 6 (the simulation does).
- The simulation fails on `TEST INVARIANT` lines (money, needs range, NaN, outside the park,
  human in the water, seats). Add new rules in `DevOptions._invariants_loop`.
- The smoke test drives minigames by calling their methods directly (`_player_throw()` …). It
  proves the logic runs, not that input or the camera work. Scenario tests use real input.

## Scenario tests (`tests/scenario.gd`)

- A script error inside a test aborts the test function; the runner may still print
  "SCENARIO ok" for it, but `scenario.sh` greps "SCRIPT ERROR" and fails the file. Always read
  the error lines above a green test. A parse error in a scenario file is reported as "script does not load"; parse
  it with `--check-only -s` to see the line.
- Headless windows are 64×64 px. The runner sets `root.size` to 1280×720, otherwise touch taps
  and button positions are wrong.
- Real input works natively: `Input.parse_input_event` with `InputEventAction`, `InputEventKey`
  (set `keycode` for code that reads keys directly), `InputEventMouseButton`,
  `InputEventScreenTouch/Drag`. A touch on a button in a headless desktop run is consumed by the
  button; the phone bug where it also reached the 3D view did not reproduce here, so touch bugs
  still need a real device.
- Tests that pass alone but fail in a file depend on leftover state from earlier tests (duck hats,
  Nessie, a minigame's delayed result, inventory). Make `reset()` clear it instead of reordering.
- `RenderingServer.frame_post_draw` never fires headless; code that awaits it hangs (the photo
  minigame now uses a blank image when `DisplayServer.get_name() == "headless"`).
- NPC timing bugs (stands opening late) only show over game hours, and only in some RNG states:
  a test passed alone and failed inside its file. Trace one NPC with a `DBG` line every 10 game
  minutes (`brain.doing()`, distance, needs). People walk only ~66 m per game hour, so any walk
  across the park costs hours.
- `open_shop` sets the vendor's hunger to 30: after a long test a hungry vendor goes eating
  instead of to work.
- The world has no physics colliders (navigation is a grid in `ParkMap`); raycasts find nothing.
  Check blocking with `world.map.is_solid()`, visibility with browser screenshots.
- Expect tests to find real bugs: in their first week they found nine (list at the end of
  `doc/test-scenarios.md`).

## Layout checks and phone screenshots

- `shot(label, targets)` in a scenario runs `check_layout`: boxes on screen, no overlaps, targets
  (world positions) visible and not under UI. Natively it resizes the headless window to each of
  `Scenario.SCREENS`; the project stretches with `canvas_items` + `expand`, so every screen is
  720 canvas px high and only the width changes (phone 1558, tablet 1280×960).
- In the browser run (`web_test.sh scenario:<file>`, WebTests export with `tests/` included) the
  game prints `SHOT <label>`, pauses, and waits until the page sets `window.__shot`. Software
  rendering gives ~1 test per minute; time runs at real speed there (toasts fade after 4 s).
- Godot imports every PNG inside the project folder, including screenshots in `build/` (14 MB in
  `.godot/imported`). The scripts keep `build/.gdignore`; recreate it if `build/` is deleted.
- Things placed with `position = …` after one frame (dialog, switch menu) stay where they are
  when the window size changes; `UI._on_resized` re-centres them.

## Browser (web) tests

- Browser runs are for screenshots only; `shots.cjs` sends no clicks or keys any more. Test
  behaviour with scenario tests.
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

- `items=log:5,apple:2` puts items into the bag, `ui=bag` / `ui=chest` / `ui=workbench` /
  `ui=campfire` opens that screen
  (screenshot presets `bag`, `bag_touch`, `hud_items`).
- `at=x,z`: puts the controlled character there, e.g. `at=-30,-150` (Nordwald); with
  `ui=map` the map opens on the Nordwald view. Presets `forest_*` in `tests/web/shots.cjs`.
- `cam=x,y,z,tx,ty,tz` + `freeze=1`: fixed camera, e.g. to check placement of new props.
- `control=<id>`, `minigame=<id>`: start directly in a minigame.
- `sit=1`: tired player on the nearest bench (fatigue recovery, HUD trend arrows).
- `press=<action>@<s>[@<repeat s>]`: simulated input (native runs).
- `touch=1`: phone layout (joystick, round buttons) in the desktop browser.
- `stats=1 speed=6`: simulation statistics and invariants, used by `test.sh`.
- `seed=N`: fixed random seed (global RNG, clock weather, world); same seed = same simulation.
- `save=<name>`: own save file `user://save_<name>.json`, deleted at start. Parallel test runs
  must not share `user://save.json` (scenario runs use `save=scenario_<file>` automatically).
- `scenario=<file>[:<test>]`: runs `tests/scenarios/<file>.gd` (what `scenario.sh` does).

## Game-specific pitfalls

- Load time grows with the grid (260 × 360 cells since the Nordwald): a per-cell GDScript loop
  over all plazas/areas took 1.3 s natively, several seconds in the browser. Time the build
  steps with a `DBG` print in `World._step` (each print shows the step before it) and loop over
  bounding boxes (`ParkMap._fill_box`) instead of every cell. Load was 2.3 s, is 2.8 s.
- A Label inside a freshly created Button with `set_anchors_preset(BOTTOM_RIGHT)` and a
  `position` lands one tile too far: the button has no size yet when the anchors are applied.
  Set only `position` for children of not-yet-laid-out controls.
- Trees are MultiMesh instances (`InstanceBatcher`): `add()` returns a handle, the tree dict
  keeps it as `"inst"`, and `world.tree_batch.set_instance_visible(handle, false)` hides a felled
  tree. Gathering spots regrow by absolute game hours (`Clock.day * 24 + hour`); a test that
  wants regrowth must advance `Clock.day`, `set_time` alone does not count days.
- People of the Nordwald (`"forest": true` in `Cast.FOREST`) never go into the park and park
  people never into the forest (`World.allowed`). They come and go by `World.home_of(actor)`:
  the forest gate or the Waldtor nearest their work, the dwarves by the mine portal. Their way
  to work is long: a vendor who arrived too early wandered off and opened late; their visit
  hours start an hour before work.
- Skipping the night (bench, inn) first sends everybody home who is out of hours or on the way
  home (`PlayerController._send_home_for_the_night`); otherwise they stood far away at sunrise.
- `next_to(id)` keeps the NPC still for 5 s (`think`) and waits 0.25 s, because the player picks
  a new focus only every 0.15 s and an NPC out of its hours walks home through the next gate at
  once (Lukas at the south gate: "options []").
- A `x if c else [y]` with a typed `Array[Vector3]` fails at runtime ("Trying to assign an array
  of type Array"): the literal is untyped. Assign in two steps or cast with `as Array[Vector3]`.
- `stuck_total` in the simulation jumped from ~10 to 53 after unrelated changes (other bushes,
  other routes): Sabine walked into a playground prop. Walkers switch waypoints early and cut
  corners by ~0.6 m, so path shortcuts (`Navigator._shortcut_ok`) need 0.65 m room on both sides;
  a stuck walker also plans once more from where it stands. Find who is stuck with
  `PARK_DEBUG_STUCK=1 scripts/godot.sh …` (prints `STUCKDBG`), and who starves with the
  `TEST STARVING` line.
- A leashed dog follows in a straight line and got stuck at the pond shore while the player
  walked around it; a dog more than 8 m behind its owner now catches up at once.
- Vendors work all day and starved by the evening; they eat a packed lunch at the stand.
- `sign` is a built-in GDScript function: a method named `sign(...)` fails with "Too many
  arguments for sign() call".
- Park visitors and park animals must not walk into the Nordwald: use `World.allowed(actor, p)`
  for any new target picker (seats, places), `random_tree()` only returns park trees and
  `nearest_tree()` stays on the side of the fence it is asked from.

- `get_theme_stylebox()` on a control that is not in the tree yet returns Godot's default
  (dark) style, not `UiTheme`. Build styles from `UiTheme.button(state)` directly. This made the
  round touch buttons dark with unreadable text; check them with the `touch=1` screenshot.

- Input events reach every node's `_unhandled_input` until one calls
  `get_viewport().set_input_as_handled()`. Without it, M opened the map in `PlayerController`
  and `UI` closed it again with the same key press (same for J and Esc).
- A mouse press on a UI element (map) can be followed by a release on the 3D view: only treat a
  release as a click when the press was on the view too (`PlayerController._pressed_on_view`).
- Minigames end after a short pause (`end_after`), guarded by `session`; a bare
  `await timer; end()` ended the next game when the player quit and restarted quickly.
- Touch input: `InputEventScreenTouch` reaches `_unhandled_input` even when the finger is on a
  button (Godot buttons only consume the emulated mouse events). Without a `UI.point_blocked`
  check, every button press also counts as a tap on the 3D view. Example: on a bench, pressing
  "Spezial" stood the player up first, so the special action became a wave instead of a nap.
  Touch bugs like this don't show up with mouse or keyboard testing.

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
