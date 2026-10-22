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
  food carts spread over the park (hot dog, ice cream, fries), two snack machines open all night, a big playground (swings, nest swing, seesaw,
  carousel, spring animals, slide tower, climbing net, trampoline, balance beam and sandbox, all
  usable; the playground gang Robin, Finja and Mika with their wishes and three games; plan in
  `doc/playground.md`), minigolf course, boule court, chess corner, dog meadow, sled hill,
  grotto, ~80 benches, ~520 trees, a city skyline around it.
- **The Westpark** west of the city park, as big as it (plan in `doc/kirmes.md`): a second park
  with a permanent **Kirmes**: Ferris wheel, carousel, chain swing, swing boats, roller coaster,
  ghost train, bumper cars, an arcade hall, a booth street, food stands, a magician's stage, a
  fortune teller's tent, a pond and five oases of rest. It is built when you walk up to the
  Westtor (loading screen). Its own people: four food stands (candy floss, roasted almonds,
  bratwurst, crêpes), twelve showmen at their booths and rides, Madame Esmeralda and the great
  Zambini, visitors and children. Joy rises by itself at the Kirmes, the oases rest twice as
  fast, an organ waltz plays near the rides. **Ride** all seven rides: the Ferris wheel stops at
  the top with the view over the whole map, the ghost train rolls past five funny frights in
  the dark, the roller coaster goes once round, the bumper cars are a minute of bumping for
  points. A stamp card in the notebook. **Booth games** for tickets, the Kirmes's second
  currency: can throwing, duck fishing, ring toss, balloon darts, whack-a-mole, the wheel of
  fortune, the high striker, plus Los-Lothar's lottery tickets. The prize counter trades
  tickets for useful things only (ore, gems, tools, the Bauchladen with six more bag slots).
  The **arcade hall** has three machines (Schlangenfraß, Astro-Abwehr, Ziegelbrecher) with
  high-score tables to climb. **Stories**: Madame Esmeralda reads a hint a day, the great
  Zambini performs mental arithmetic tricks and lost his rabbit Hoppel (a quest in five steps),
  Gisbert the fair ghost haunts the ghost train at night, Lia lost her teddy, Mandel-Manni needs
  a nap, Muskel-Max wants food from the city park, and a few secrets have no hints at all.
- **The Ritterburg** north of the Westpark and west of the Nordwald (plan in `doc/burg.md`,
  growing in phases): a castle on a hill that runs into the mountain, entered by the Burgpforte
  from the Westpark or the Waldweg from the Nordwald. A tournament ground with lists, stands,
  paddock, sword ring and archery range at the foot, a market with tavern, smithy, herb witch and
  alchemist on the way up, the inner square with jugglers, minstrel, puppet theatre and a
  mysterious magician, the knights' exhibition and a lookout tower at the top, torches at night.
  A secret passage leads through the mountain to the dwarves' mine. Ravens and falcons (they fly
  a short way with the special action) and horses in the paddock.
  **Herbs and potions**: chamomile, elder, woodruff, wild garlic, lavender, St John's wort and
  rose hips grow across the areas; the herb witch and the alchemist brew them into potions for a
  fee (Lauftrank, Kräutertrank, Abbautrank, 8 game hours each), the smith forges from the
  dwarves' ore, and the market sells stew in bread, suckling pig, honey cake and smoked fish.
  **Castle games**: Tjost and Ringstechen on horseback, archery, tug of war against a knight,
  bets on the sword fight, dice with Würfel-Fritz, Meister Morwen's crystal ball (remember the
  colours), the lookout tower; on the hour from 11 to 18 the knights joust as a show.
  **Stories**: Meister Morwen's star staff (with Zambini and Esmeralda at the Kirmes), Hedwig the
  castle ghost and Gisbert, six quests, Lumpen-Ludwig's riddles, the exhibition's boards.
- **The Möwenbucht** south of the city park, through the Südtor (plan in `doc/moewenbucht.md`,
  growing in phases): the world runs into the sea. A promenade with lamps, benches, stands and a
  bandstand, dunes with marram grass and boardwalks, a sand beach with Strandkörbe (seats for
  two), parasols, a lifeguard tower, a volleyball court and a pirate ship to climb, groynes, a
  long pier with a pavilion on its head, a harbour with a fishing cutter, a jetty and a mole with
  a lighthouse (its beam turns at night), rocks in the west, a sandbank with seals, buoys and
  the open sea to the horizon. **Boats**: pedal boats (swans) and rowing boats lie at the jetty;
  drive them like a car (on the water only, inside the buoys), get out at a jetty or the beach.
  Gulls (playable, a short flight) and beach visitors.
  **Fishing** on the pier, the mole, the quay and from a rowing boat (herring, mackerel, plaice,
  cod, rarely a lobster, sometimes an old boot; the surf rod bites sooner), **shells and amber**
  on the beach, and the stands: Fischbude, Eisdiele, Strandkiosk, Souvenirs, Strandbar and the
  fishing cutter, which buy what you catch and find. **Games**: a pedal boat race round the
  buoys against Ole's boats, stone skipping (throw when the needle is in the green), up the
  lighthouse, the coin telescope on the pier, building a sandcastle with Opa Fietje before the
  tide comes, beach volleyball against Piet, Möwenalarm at the fish stand and a fishing contest
  against Gesche. **Stories**: a forty-year-old message in a bottle that leads to Räucher-Fiete at
  the castle, the lighthouse's cracked lens (made new at the castle's smithy), quests for the
  stands, Svenja's sunglasses, Ole's drifted pedal boat and a photo of the seals; 16 achievements.
- **The Oststadt** east of park and Nordwald, as big as both (plan in `doc/oststadt.md`): a flat
  little town with low houses, a closed street grid with crosswalks, market square, church,
  petrol station, garage, driving school, kart track, scrapyard and garbage depot. It is built
  when you walk up to the Osttor (loading screen). **Drive** any standing car (keys W/A/S/D,
  touch joystick plus Gas/Bremse, gamepad triggers; E gets out, F honks): nobody can be run
  over (people jump aside, cars brake on their own), bumps are soft, and you don't get tired
  in a car. Two drive-ins: the burger drive-in "Zum Durchfahrer" (with a memory game for the
  family order) and the drive-in cinema with an evening film. Traffic with traffic lights
  (AI cars wait at red, keep their distance and stop for people), ten residents (Taxi-Tanja,
  Meister Kurt, Tankwart Toni, Burger-Bodo, Kino-Karla, Fahrlehrer Friedrich, Schrott-Siggi,
  Eismann Gianni, Polizistin Petra, Opa Egon) plus passers-by and children; traders at the
  petrol station, the drive-in counter and the scrapyard (funny horns). Twelve town minigames:
  taxi, tow truck, burger delivery, parking practice, driving test, car wash, petrol pump to the
  cent, kart race, ice cream van, garbage collection, scrapyard crane and the oldtimer rally.
- **People and animals** (~70): named characters with generated, animated low-poly models –
  e.g. Jogger Jens, Opa Herbert, Touristin Peggy, Pantomime Pierre, Hundesitterin Mia with five
  dogs, Katze Minka, Eichhörnchen Nussi (the donut thief), Ente Frieda with four ducklings,
  Gans Gustav, Reiher Rudi, owl, hedgehog and fox at night.
- **Their own lives**: needs (hunger, fatigue, joy), likes and daily schedules decide what
  everybody does: jogging, sitting, eating, feeding ducks, taking photos, phoning, performing,
  working at the stands, walking dogs, chatting, going home at night. Animals hunt, flee, swim,
  climb trees, steal donuts and sleep. Pathfinding prefers the park paths.
- **Needs for the player too**: a very hungry or tired player slows down (NPCs keep their pace), sad ones slump and
  sad smileys rise above them. Sitting on a bench quickly takes away fatigue, a nap on it (Special while sitting) even faster; the HUD bars show
  animated arrows while a need changes. The player moves twice as fast as the NPCs.
- **23 minigames** (and 8 more at the Ritterburg) (11 in park and Nordwald, 12 in the Oststadt): Boule, Minigolf (6 holes), Hütchenspiel, Frisbee with Balu (also as the dog),
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
| Action (sit, buy, get in …; talks when nothing else is in reach) | E | "Aktion" | A |
| Talk to the person in front (in a car: get out) | T | "Ansprechen" (car: "Aussteigen") | B |
| Switch character | Q / Tab | "Wechseln" (top bar) | Y |
| Special (bark, quack, climb …; nap when sitting) | F | "Spezial" | X |
| Dance | R | – | D-pad up |
| Walk to a spot | left click on the ground | tap | – |
| Map / Notebook / Menu | M / J / Esc | buttons top right | Back / RB / Start |
| Bag ("Rucksack") | I | button in the character panel | – |
| Drive: gas / brake / steer | W / S, Space / A, D | Gas, Bremse / joystick | RT / LT / left stick |

## Build, run, test

Everything installs without root into `~/.local/opt/godot-park` (Godot 4.7.2, export templates,
JDK 17, Android SDK; Chromium for web tests).

```bash
scripts/export.sh            # installs the toolchain if needed, exports web + Android debug APK
scripts/export.sh web        # only build/web
scripts/export.sh android    # only build/android/godot-park.apk
scripts/test.sh              # unit + scenario tests + half-day simulation (~7 min)
scripts/scenario.sh [file]   # scenario tests: play the game with real input (doc/test-scenarios.md)
scripts/scenario.sh --changed  # only the scenario files that cover what changed since origin/main
WEB=1 scripts/test.sh        # … plus web export and browser screenshots (build/screenshots)
scripts/web_test.sh pond     # screenshots of single presets (see tests/web/shots.cjs)
scripts/web_test.sh scenario:layout   # phone-sized screenshots at every shot() of a scenario file
scripts/web_test.sh perf     # draw calls at fixed spots against their budgets
scripts/android_test.sh      # boots an Android emulator (via Docker if needed), runs the APK
scripts/check.sh             # re-import and list GDScript errors
scripts/bake_map.sh          # bake the whole map (assets/map/world.png; release.sh does it when needed)
scripts/release.sh "Message" # unit + changed scenario tests, commit all, push main, wait for deploy, verify live
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
`minigame=<id>`, `cam=x,y,z,tx,ty,tz`, `freeze=1`, `speed=N`, `lineup=id,id,…` (with `lineup_zoom=N` closer, `lineup_y=h` at eye level h), `ui=map|tasks`,
`stats=1`, `sit=1` (tired player on the nearest bench), `press=interact@5` (simulated input), `touch=1` (phone layout),
`seed=N` (reproducible randomness), `save=<name>` (own, fresh save file), `scenario=<file>[:<test>]` (runs a scenario test), `items=id:n,…` (items into the bag), `ui=bag|chest`, `at=x,z` (puts the controlled character there, e.g. `at=-30,-150` in the Nordwald, `at=-200,5` in the Westpark), `fair=1` (builds the Westpark at the start), `burg=1` (the Ritterburg), `coast=1` (the Möwenbucht). See `src/game/dev_options.gd`.

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
tests          unit tests, scenario tests, web screenshot script
doc            arc42 architecture
```
