# Bank frei!

A humorous open-world game in a big city park, made with Godot 4.7 for **Web** and **Android**.
Play people and animals, switch to anybody nearby, keep your character fed, rested and happy,
play minigames, earn money, unlock achievements and find the park's secrets.
The UI is German; code and docs are English. Architecture: [doc/arc42.md](doc/arc42.md).

## Features

- **The park**: 260 × 180 m city park, plus the **Nordwald** of the same size north of it
  (lumber camp, sawmill, forest inn, forest pond, quarry and the dwarves' mine; plan in
  `doc/nordwald.md`): fell trees, mine stone, ore and gems, pick berries, ceps and apples, fish,
  craft tools, goods and food at the workbench and campfire, carry it all in a bag. The city park has a creek, a pond with an island and stepping stones, four
  automatically placed bridges, music pavilion, fountain plaza, food court (donut stand, kiosk),
  food carts spread over the park (hot dog, ice cream, fries), two snack machines open all night, playground, minigolf course, boule court, chess corner, dog meadow, sled hill,
  grotto, ~80 benches, ~520 trees, a city skyline around it.
- **People and animals** (~70): named characters with generated, animated low-poly models –
  e.g. Jogger Jens, Opa Herbert, Touristin Peggy, Pantomime Pierre, Hundesitterin Mia with five
  dogs, Katze Minka, Eichhörnchen Nussi (the donut thief), Ente Frieda with four ducklings,
  Gans Gustav, Reiher Rudi, owl, hedgehog and fox at night.
- **Their own lives**: needs (hunger, fatigue, joy), likes and daily schedules decide what
  everybody does: jogging, sitting, eating, feeding ducks, taking photos, phoning, performing,
  working at the stands, walking dogs, chatting, going home at night. Animals hunt, flee, swim,
  climb trees, steal donuts and sleep. Pathfinding prefers the park paths.
- **Needs for the player too**: very hungry or tired characters slow down, sad ones slump and
  sad smileys rise above them. Sitting on a bench quickly takes away fatigue, a nap on it (Special while sitting) even faster; the HUD bars show
  animated arrows while a need changes. The player moves twice as fast as the NPCs.
- **11 minigames**: Boule, Minigolf (6 holes), Hütchenspiel, Frisbee with Balu (also as the dog),
  holiday photo for Peggy, Pfandjagd, Futterchaos at the pond, giant Tic-Tac-Toe vs. Boris; in the
  Nordwald axe throwing and a wood chopping duel with Holger and the dwarves' switchman game.
- **Jobs & quests**: dog walking for Mia, the mime stuck in an invisible box, the bridge troll's riddles,
  five jobs for the dwarves that reward better tools (iron pickaxe, dwarf axe, dwarf pickaxe, dwarf bag).
- **Nordwald trade**: the sawmill, the dwarves, the farm shop and the inn buy what you gather and make;
  the inn has hot meals and a room for the night, the campfire rests you faster.
  Nearby quest givers and unfound gnomes get a soft gold ring on the ground, open minigames a blue one.
- **Secrets**: 7 hidden garden gnomes, wishing fountain, a duck statue with a secret, Nessie,
  a UFO, Nussi's donut stash, bench plaques … (29 achievements in total).
- **Atmosphere**: day/night, weather (sun, clouds, rain, fog, snow, thunderstorms), four seasons
  (cherry blossom, autumn leaves, bare trees and snow, frozen pond), lamps at night, synthesised
  sounds and ambience.

## Controls

| | Keyboard & mouse | Touch | Gamepad |
|---|---|---|---|
| Walk / run | WASD, arrows / Shift | left joystick / "Rennen" | left stick / LB |
| Camera | drag mouse, wheel | swipe | right stick |
| Action (sit, buy, talk …) | E | "Aktion" | A |
| Switch character | Q / Tab | "Wechseln" | Y |
| Special (bark, quack, climb …; nap when sitting) | F | "Spezial" | X |
| Dance | R | – | B |
| Walk to a spot | left click on the ground | tap | – |
| Map / Notebook / Menu | M / J / Esc | buttons top right | Back / RB / Start |
| Bag ("Rucksack") | I | button in the character panel | – |

## Build, run, test

Everything installs without root into `~/.local/opt/godot-park` (Godot 4.7.2, export templates,
JDK 17, Android SDK; Chromium for web tests).

```bash
scripts/export.sh            # installs the toolchain if needed, exports web + Android debug APK
scripts/export.sh web        # only build/web
scripts/export.sh android    # only build/android/godot-park.apk
scripts/test.sh              # unit + scenario tests + scripted play-through + half-day simulation
scripts/scenario.sh [file]   # scenario tests: play the game with real input (doc/test-scenarios.md)
WEB=1 scripts/test.sh        # … plus web export and browser screenshots (build/screenshots)
scripts/web_test.sh pond     # screenshots of single presets (see tests/web/shots.cjs)
scripts/web_test.sh scenario:layout   # phone-sized screenshots at every shot() of a scenario file
scripts/android_test.sh      # boots an Android emulator (via Docker if needed), runs the APK
scripts/check.sh             # re-import and list GDScript errors
scripts/release.sh "Message" # unit tests, commit all, push main, wait for deploy, verify live
```

Debugging and testing lessons: [doc/testing-notes.md](doc/testing-notes.md). Test catalogue (every
feature and its test): [doc/test-scenarios.md](doc/test-scenarios.md). Scripts start Godot through
`scripts/godot.sh`, which caps its memory (3 GB, `GODOT_MEM`); use it for manual runs too.

Play the web build locally: `python3 -m http.server -d build/web 8000` → http://localhost:8000.
Install on a phone: `~/.local/opt/godot-park/android-sdk/platform-tools/adb install -r build/android/godot-park.apk`.
Open in the editor (desktop): `~/.local/opt/godot-park/godot-4.7.2/godot --path .`.

### Deployment

Live: https://godot-park.ironstrike.de – pushing `main` deploys via the VPS webhook.
The `Dockerfile` installs Godot headless with only the web export templates, exports the
project and serves `build/web` with nginx on port 3000 (gzip: the 40 MB engine ships as ~10 MB).
Other branches get preview deploys.
The image also contains the Android app: **https://godot-park.ironstrike.de/download** (page) and
`/bank-frei.apk`. It is signed with `deploy/bank-frei.keystore` (committed on purpose, so every build
has the same signature and updates install over older versions; versionCode = build time in minutes).

### Dev options

Command line (`godot --path . -- --time=22 --season=3`) or URL query on the web
(`index.html?time=22&season=3`): `time`, `season` (0–3), `weather` (0–5), `control=<actor id>`,
`minigame=<id>`, `cam=x,y,z,tx,ty,tz`, `freeze=1`, `speed=N`, `lineup=id,id,…`, `ui=map|tasks`,
`stats=1`, `smoke=1`, `sit=1` (tired player on the nearest bench), `press=interact@5` (simulated input), `touch=1` (phone layout),
`seed=N` (reproducible randomness), `save=<name>` (own, fresh save file), `scenario=<file>[:<test>]` (runs a scenario test), `items=id:n,…` (items into the bag), `ui=bag|chest`, `at=x,z` (puts the controlled character there, e.g. `at=-30,-150` in the Nordwald). See `src/game/dev_options.gd`.

## Layout

```
src/autoload   Controls, Clock, GameState, Sound
src/core       park layout, park map + navigation, cast, achievements
src/models     mesh kit, materials, nature and prop models
src/shaders    terrain, foliage, water, sky, glow
src/world      world building, environment (sun, weather, seasons)
src/actors     actors, needs, procedural rigs
src/ai         human and animal brains, activities
src/interact   benches, shops, food, bottles, interactables
src/game       bootstrap, player control, conversations, quests, easter eggs
src/minigames  the eleven minigames
src/ui         HUD, touch controls, map, notebook, menus
tests          unit tests, scenario tests, smoke test, web screenshot script
doc            arc42 architecture
```
