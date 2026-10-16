# Testing and debugging notes

Practical lessons from working on this project. Each one cost time once; read this before
debugging, and add to it when you learn something new (see `CLAUDE.md`).

## Quick reference

| Goal | Command | Duration |
|---|---|---|
| Unit tests only | `scripts/test.sh unit` | ~1 min |
| Scenario tests (play with real input) | `scripts/scenario.sh [file[:test]] …` (catalogue: `doc/test-scenarios.md`) | ~5 min all, 10–80 s per file |
| Scenario files that cover your changes (since `origin/main`, incl. uncommitted) | `scripts/scenario.sh --changed` (`LIST=1` only prints them; map: `tests/scenario_map.txt`) | 0–5 min |
| Unit + scenarios | `scripts/test.sh scenarios` | ~7 min |
| Everything (unit, scenarios, half-day simulation next to them) | `scripts/test.sh` | ~7 min, run in the background |
| GDScript errors in the whole project | `scripts/check.sh` | ~1 min |
| Parse a single script | `scripts/godot.sh --headless --path . --check-only -s src/x.gd` | seconds |
| Native run with dev options | `scripts/godot.sh --headless --path . --quit-after 1500 -- --control=jens --minigame=boule` | ~1 min |
| Browser screenshots (no input) | `scripts/web_test.sh <preset> …` (presets in `tests/web/shots.cjs`) | ~3 min incl. export |
| UI layout checks (desktop, phone, tablet; keyboard and touch) | `scripts/scenario.sh layout` | ~35 s |
| Phone screenshots of a scenario file | `scripts/web_test.sh scenario:layout` → `build/screenshots/layout/` | ~20 min, background |
| Release | `scripts/release.sh "msg"` (unit tests + `scenario.sh --changed`; `FULL=1` for everything) | 1–6 min + the deploy (1–10 min) |
| Draw-call budgets at fixed spots (browser) | `scripts/web_test.sh perf` (`budget` of the `perf_*` presets in `tests/web/shots.cjs`) | ~5 min incl. export |
| Frame rate, frame/script time, draw calls on a device | Einstellungen → "Leistung anzeigen" (overlay bottom left) | – |

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
- Shaders compile in headless runs too: a broken shader prints `SHADER ERROR` with the line,
  and `scenario.sh` fails on it (it did not before, a car shader with `return` in `fragment()`
  slipped through a green run). `return` is not allowed in `fragment()`: set variables instead.
- "Expected expression for match pattern": a `match` as the last statement of an inline lambda
  that is an argument (`put(p, yaw, func(kit) -> void: match …`) with the closing `)` on the
  last arm. Move the body into a method and pass `method.bind(args)`.
- "Cannot infer the type of x" (parse error) on a value from an untyped Dictionary or a
  `Variant`: write the type, `var cam: CameraRig = d["camera"]`.
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
- `--fixed-fps 30` runs much faster than real time (a play-through went 528 s → 201 s). With
  `Engine.time_scale` above ~4 at 30 fps the physics needs more than 8 steps per frame and falls
  behind: use 60 fps for speed 6 (the simulation does).
- The simulation fails on `TEST INVARIANT` lines (money, needs range, NaN, outside the park,
  human in the water, seats). Add new rules in `DevOptions._invariants_loop`.
- "N ObjectDB instances were leaked at exit" (`AudioStreamWAV`, `AudioStreamPlaybackWAV`) after
  the simulation: ambient loops still playing when the run quits; the count changes from run to
  run with the same code (0, 8, 15). Harmless, `test.sh` does not fail on it.
- `test.sh` imports once and passes `SKIP_IMPORT=1` to `scenario.sh` and `run_headless.sh`;
  run alone, they import themselves. The simulation runs next to the scenario files (four Godot
  processes, ~2 GB together).
- Gameplay code must not use the wall clock (`Time.get_ticks_msec`) or `create_timer` without
  `process_always = false` for anything the game decides: under `--fixed-fps` the wall clock
  depends on the machine's load, so a run behaved differently with three parallel jobs than
  alone (pedestrians dodging the taxi). Use `Clock.now()` (seconds of play) for cooldowns.
- Never `rng.randomize()` in game code: the taxi job drew its fares from a randomized RNG, so
  `mg_city::test_arrow_leads_to_the_target` got another fare in every run and failed now and then
  ("21 m left"). `Minigame.rng` is seeded from the global RNG at every start; other systems seed
  theirs with `randi()` (follows `seed=`).

## Scenario tests (`tests/scenario.gd`)

- `scenario.sh --changed` picks files by `tests/scenario_map.txt` (glob → files, `*` = all,
  `-` = none). A changed path without a line runs every file and is named in the output: add a
  line when you add a source file. Files the whole game goes through (actor, world, player
  controller, autoloads, park builders, `tests/scenario.gd`) run everything on purpose.

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
- Every test draws its own random numbers: `reset()` reseeds the global RNG, `Clock`, `World`,
  `City` and `Fair` from `seed=` and the test's name, so a test gets the same numbers alone and
  in its file. A test that still passes alone but fails in a file depends on leftover state
  (duck hats, Nessie, a minigame's delayed result, inventory, where NPCs and AI cars are). Make
  `reset()` clear it instead of reordering.
- `wait_until` checks once per frame, right when the frame starts; several physics steps run
  between two checks. Something that lives less than a frame (bread a duck eats at once) is
  never seen: count it through a signal (`world.food_eaten`).
- A lambda that captures a node and runs later (timer, tween) fails with "Lambda capture at index
  0 was freed" when the node is gone, before any `is_instance_valid` inside it runs. Capture a
  `weakref(node)` and check `get_ref()` (`ChopGame._split_fx`).
- `reset()` puts the Oststadt and the Westpark to sleep when the previous test did not ask for
  them (`city()`, `fair()`; `in_car`/`new_car` call `city()`). A test that reads `world.city` or
  `world.fair` must call `city()`/`fair()` first, or it sees a hidden, unprocessed area. Waking an
  area places all its people anew (`Game.place_by_schedule`), which is why town files keep it awake.
- A change to where people stand at the start (e.g. vendors at their stands) breaks tests that
  relied on the old random spots: "Aktion" sat the player on a bench next to Mia instead of
  talking, a vendor's advert sat under the craft screen, an AI scooter drove off before the bump.
  Put the people a test needs where it needs them (`hold_npc(id, at)`, `_mia_on_the_meadow`), and
  hold still what would move away (the other scooters: `fair.process_mode` off for the push).
- New simulation invariants find start artifacts first: right after the start every vendor was
  "away" because `place_by_schedule` put them on random paths. Trace one actor with a `DBG` line
  in `_invariants_loop` (distance, activity, `_lead_hours()`) before loosening the rule.
- `world.fair` is set only once the Westpark is complete (`FairArea._build` awaits between its build
  steps); code running in between sees `null` (FairStories crashed on half-built props).
- Helpers for common setups live in `tests/scenario.gd`: `hold_npc(id, at)` (brain paused for
  10 min), `open_menu`/`buy` (shops), `car_to` (car placed standing), `traffic_off(near)` (AI
  cars aside, back in `teardown`). Add new ones there, not as copies in the files.
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

- Driving with real input along a route (`mg_city::test_arrow_leads_to_the_target`): steer
  for `RouteArrow.info["aim"]` only. An extra "keep right" offset on an aim that starts at the
  car adds up every step and drifts the car onto the parking strip, where it sticks at a parked
  car. Move the AI traffic aside (`traffic_off()`), or a car in the way decides the test. Count
  its time in game seconds from the physics frames: a `drive(gas, 0.12)` step takes two frames
  (0.2 s), so adding 0.12 per step gave it ~250 s instead of the 150 s it claimed.

- A screenshot preset that shows only dark green circles (`pavilion`, looked like the title
  backdrop): the `cam=` point sits inside a tree crown, after the trees were planted anew. Find
  trees near the camera from a throw-away scenario (`world.trees`, `"pos"`, `"height"`) and move the
  camera to a spot with free view.

- Scenario screenshots in the park (`web_test.sh scenario:playground…`) can need more than
  Playwright's default 30 s per `page.screenshot` with software rendering ("Timeout 30000ms
  exceeded … fonts loaded"); `shots.cjs` allows 120 s for them and for the presets.

- A driving test that "passes" in one build and fails in the next without a driving change:
  look for an AI car standing in the lane (`world.city.cars` near the test car); park them with
  `traffic_off(near)` (`city_people::test_petra_sees_a_red_light`).

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
- `city=1`: loads the Oststadt at the start (`at=` east of the park and `drive=` do it too);
  `drive=<kind>` puts the player into a car (`small`, `taxi`, `tow` …, `CarSpecs.KINDS`). In
  the browser the town takes several seconds to build: city presets wait ~20 s, or the
  screenshot shows the loading screen. Scenario tests call `await city()` / `in_car()`.
- `fair=1`: loads the Westpark with the Kirmes at the start (`at=` west of the park does it too).
  Scenario tests call `await fair()`. Presets `fair_*` and `map_fair` (they wait ~16 s for it).
- `areas=split|all`: setting "Bereiche" (only the player's area awake, or everything built).
  Scenario runs default to `all`; a test asks for split
  with `world.set_split(true)` (see `areas.gd`, which restores `all` in `teardown`). In split
  mode `put_player` into the other area swaps the areas (loading screen, no gate question).
  Presets `split_town_west`, `all_town_west`, `split_gate`.
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

- Driving tests near a curb: the parking strips (2.5 m along each curb) hold seeded parked cars
  and street trees (car obstacles). A car spawned there overlaps one and cannot move at all
  (`pose_blocked` is not "" at the start): check the start pose, or move parked cars away.
- Turning a car about its centre swings the tail into the curb; corrections turn it about the
  rear axle (`Car._about_rear_axle`). When the nose touches something, turning pushes the front
  corner forward by width/2 × angle: back off at least that much.
- "Aktion" (`press("interact")`) prefers things: next to an NPC who stands at a stand or a
  minigame spot (Jacques at boule, Thrain at the switch tower) it uses the thing, not the NPC.
  Talk with `press("talk")`; `talk_prompt()` shows whom "Ansprechen" would address.
- Surface patterns (`surface.gdshader`) look fine up close but vanish a few metres away: the
  `detail(p, size)` fade is too strict for that pattern (gravel needed 0.14, not 0.05). Judge at
  playing distance with `web_test.sh path_gravel path_trail bridge_wood`, not from a close-up.
- `web_test.sh` presets with `fair=1` need `wait: 22000` when the camera is close: at 16 s the
  "Auf zur Kirmes …" loading overlay can still be in the shot. A batch of ~10 presets takes over
  10 minutes: run it in the background.
- Every MeshKit surface is a draw call per instance: nine finishes on a booth cost +80 draw calls
  on the booth street (`perf_fair_all` prints them; compare with a `git worktree` of HEAD). Put
  variants of one finish on one surface with a vertex-alpha flag (`MeshKit.use(surface, alpha)`),
  and give parts that exist many times (gondolas, seats, horses, cars) a single surface.
- `InstanceBatcher` costs a draw call per mesh, per surface and per 65 m chunk: 15 tree and prop
  kinds in the town's yards cost +60 draw calls although each is one MultiMesh. Merge scenery
  that never moves into one mesh per area (`MeshKit.add_mesh`, `CityDecor`): then variety is
  free and only the materials count (keep an area to solid, bark, foliage: cherry blossoms,
  flowering bushes and evergreen hedges are three more). Measure with `perf_city`/`perf_city_south`
  against a `git worktree` of HEAD (Oststadt looks: 284/200 before, 284/181 after, with a car as one draw call).
- Fair finishes (`fair.gdshader`): the sky reflection is emission, so a dark lacquer still shows a
  sheen in the shade; judge colours by day and at night (`fair_stalls`, `fair_stalls_night`).
- `ShaderMaterial.get_shader_parameter()` returns `null` for a uniform that was never set, not
  its default from the shader; compare with `in [null, 0]` in tests.
- `MeshKit.tri_uv`/`quad_uv` and plain `tri` must not share a surface: SurfaceTool fixes the
  vertex format at the first vertex, so switch surfaces with `kit.use()` (curbs vs. path strips).
- The grid is 780 × 360 since the Westpark, with `ORIGIN` at x = −390: park cells start at column
  `ParkMap.PARK_X0` (260), the town at `CITY_X0` (520). Never loop from column 0 for the park.
  `in_world` covers park, Nordwald, town and Westpark; the 1.2 m strip along the fence between
  park and Westpark is outside both, so walking checks use `ParkMap.in_bounds` (that strip is
  walkable, the fence is an obstacle row with the Westtor gap).
- `walk_to` plans its path once: towards an area that is not built yet (Westpark, Oststadt) the
  path ends at the fence and the walker stops there. Walk up to the gate, wait for
  `world.fair` / `world.city`, then walk on.
- Load time grows with the grid: a per-cell GDScript loop over all plazas/areas took 1.3 s
  natively on the park part alone, several seconds in the browser. Time the build steps with a
  `DBG` print in `World._step` (each print shows the step before it) and loop over bounding
  boxes (`ParkMap._fill_box`) instead of every cell; `BANKFREI READY in … ms` prints the total.
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
- A ride that ends inside `ride_update` (the coaster, back in the station) must not run the
  rest of `Ride._process`: `_place_rider` and `look` put the player back on the car and took the
  camera again after `end()`, so the player was stuck on the track. Check `active` after any
  call that may end a minigame.
- Scenario runs go faster than real time: per-frame steps are several times bigger than in
  play. Judge motion per metre (the coaster's turn in °/m), not per frame. Far from the
  camera `Fair._process` moves things only every 6th frame.
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
- `ParkMap.path_dist_at` returns the value of the nearest 1 m cell, off by up to half a metre.
  Main-path curbs used it to detect joining paths and came out as dashes. For anything finer than
  a cell, interpolate between cell centres (`TerrainBuilder._path_dist_smooth`).
- `bridge_deck(b, p)` at an exact bridge end can return NAN: `t` comes out a hair above 1.0.
  Tests that check the ends compute the deck from `h0`, `h1` and `ParkMap.deck_lift`.
- Ground cells are 1 m squares. Anything with a curved or diagonal edge (paths) needs its own
  mesh on top, with the cells under it drawn like the surrounding ground; otherwise the edge is
  a staircase.
- Bruno the bridge troll is not sent home at 4:00 (`role != "troll"` in
  `HumanBrain._should_interrupt`): he leaves only when his performance times out (up to 7 game
  hours). Waiting for `inside` in a test timed out even after 480 s; send him home directly
  (`suspend`, `inside = true`, `visible = false`).
- `Seat.approach_point()` lies 0.65 m in front of the bench, inside the bench's own obstacle
  cell, so `map.is_solid()` there is true for every bench. Check reachability ~1.3 m in front.
- Talking to an NPC in a test: Action picks the nearest interactable, so a dog or another NPC
  standing closer gets greeted instead (prompt "Mops Krümel begrüßen"). Where NPCs live changes
  with any change to the map, so suspend and move bystanders away (`quests::test_marker_on_quest_giver`).

- A follow-up dialog from a dialog option's action: `UI.dialog_then(...)` opens it in the next
  frame, after the input that chose the option is done.
- The park's outer fence was never an obstacle: the `in_world` margin was the wall. With the
  Oststadt the world reaches x = 390, so the east fence is an obstacle row with gaps at the two
  gates (`ParkDecorator._city_fence`); the town's cells stay solid until it is built (`World.load_area("city")`).
- Yaw 0 faces +z, yaw PI/2 faces +x: a growing yaw turns *left*. The right-hand side of a
  heading f is `Car.right_of(f) = (-f.y, f.x)` (lanes: eastbound at z + 1.75, southbound at
  x − 1.75).

- Westpark placement: `scenario` code can paint the grid into an `Image` (ground, `path_dist`,
  `is_solid`, bench positions) and save a PNG to look at; that showed a booth on a path end, a
  path through the swing boat and benches at junctions. `fair::test_furniture_off_the_paths`
  guards it now.

- `Activity.walked()` is true as soon as the actor stands still, also after a test teleported it
  away mid-walk. An activity that then starts something "at the target" does it at the wrong
  place: Lena flew from the great meadow towards the climbing net and missed her greeting
  (`characters::test_human_waves_and_neighbour_waves_back`, only in the full file). Check the
  distance before starting (`Playground.use` needs the actor at `start_point`).
- `TEST INVARIANT visitor_in_forest` for a Nordwald person at (131, −160): they come and go
  through the forest entrances, whose outside point lies in the Oststadt strip. The invariant
  allows the forest entrances like the park gates; any change that shifts the simulation's random
  course can make such a gap show up.
- Playground riders are placed every frame by `Playground._carry`, motions by
  `_run_motions`: `Actor.teleport` stops both, other position changes do not stick while an
  actor rides or moves on a device.

## Performance

- Phone frame rate is bound by the CPU (GDScript) more than by the GPU. Measure CPU headless: a
  temporary scenario that waits ~120 frames and divides the wall clock (`Time.get_ticks_usec`)
  by the frame count; `--fixed-fps 30` makes a frame cost exactly its processing time. Split by
  wrapping calls with `Time.get_ticks_usec()` into a `static var PERF := {}` and print it.
  Remove the probes afterwards; compare the same positions before and after a change.
- Wrapping an `if` body with a probe line after the block breaks a following `elif`
  ("Expected statement, found elif"): put the probe inside the branch.
- `Actor.lod_distance` existed for years but was never set (always 0), so no LOD ran. If a
  distance-based shortcut seems to have no effect, check that its input is really updated.
- The cost was "everybody checks everybody": ~170 cars (most parked) × walkers, 104 actors ×
  cars. Use `World.actors_near` / `City.cars_near` (bucket grids), never `for a in world.actors`
  in per-frame code. Driving moves cars with `Car._set_pose` (no grid reset); `Car.place` and
  `Actor.teleport` reset the grids so a test sees the new position at once.
- Skipping `Rig.animate` for actors off screen also stopped `update_overlays`: speech bubbles
  never ran out and `is_speaking()` stayed true (layout test "speech of harry … hidden").
  Per-frame bookkeeping (timers, overlays) must keep running when a visual step is skipped.
- Test runs (`save=<name>`, set by `scenario=` and the simulation) have their own settings file
  `user://settings_<name>.cfg`, fresh with the defaults: a test that changes settings doesn't
  change them for the parallel or later runs, nor for playing.
- Sleeping areas (split) are hidden and disabled, not freed: `OS.get_static_memory_usage()` stays
  the same; compare draw calls/triangles and `Actor.ticks` per frame instead.
- The loading screen sets the UI modal; hiding it used to clear the modal even when the settings
  were still open underneath (game input went through the pause menu). `hide_loading` gives the
  pause menu its modal back.
- `pkill -f "<pattern>"` also matches the Bash command that runs it (exit 144, the shell is
  killed). Kill by PID from `ps` instead. The same holds for `while pgrep -f "<pattern>"; do
  sleep …` as a wait: it finds itself and never ends. Wait for the PID (`wait $pid`) instead.

- The saved game is loaded at start-up, before the title screen (the park behind it shows the
  saved state). "Neues Spiel" therefore has to reset everything a save restores: `Clock.reset()`,
  `Actor.reset_for_new_game()` and `Game.place_by_schedule` for everybody (`Game._new_game`).
  Autoloads (`Clock`, `GameState`) survive `reload_current_scene`.

## Deploy and platform

- `scripts/release.sh` runs the unit tests and the scenario files that cover the changes
  (`scenario.sh --changed`), commits, pushes `main`, waits for the webhook deploy
  in `~/clones/config/logs/deploys.jsonl` and checks the live site, download page and APK.
- The deploy dashboard code lives in `~/clones/config/webhook` (platform repo, owned by the
  orchestrator). Changes there need a webhook restart (`kill` the node process, systemd restarts
  it). That restart is the user's call; the session may not do it.
