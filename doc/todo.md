# To-Dos

Open items only, in the order they should be done. The order follows what makes the next step
cheaper: a fast, reliable test net first (every refactoring below leans on it), then the APIs that
every new quest, NPC, item and minigame touches, then areas, actors and structure, performance
last where it needs measuring. Each item names the evidence (file:line as of 2026-10-15).

## 1. Test net: fast and reliable

1. **Release gate.** `release.sh` runs only the unit tests by default, the deploy none. Give
   `scenario.sh` a "changed files" mode (map `git diff` paths to scenario files, e.g.
   `src/vehicles`, `city*` → driving, traffic, mg_city*, drive_ins, city*) and run that subset in
   `release.sh`.
2. **Long life-watching waits into the simulation.** `city_people.gd:25` (150 s),
   `nordwald.gd:62` (120 s), `forest_people.gd:191` (180 s), `world.gd:9/48/58` (60/240/300 s),
   `shops.gd:178` watch NPCs for game hours. The simulation checks the same regions as
   invariants; keep only the precise assertions in the scenarios (vendor opens on time, Egon at
   his door) and add the ⬜ invariants "vendors at stands" and "leash"
   (test-scenarios.md, simulation section). About 400 CPU-s per run.
3. **Park tests after the town loaded.** The Oststadt stays loaded for the rest of a file
   (`scenario.gd`, `city()`), so later park tests run at ~63 ms instead of ~17 ms per frame. Put
   the area to sleep in `reset()` when the test doesn't ask for it, or order such files.
4. **Draw-call budget test**: assert draw calls at fixed camera spots (`perf_*` presets exist
   only as screenshots; MeshKit merges are compared by hand).
5. **Catalogue gaps** (`doc/test-scenarios.md` ⬜): autosave and needs/inventory after loading,
   "Neues Spiel" from the pause menu, virtual joystick, gamepad, swimming and humans kept out of
   water, "Bank besetzt", controlling a vendor or host, storm, night animals, settings sliders;
   no test touches `Sound`, `EnvironmentController`, `TasksScreen`, `TouchControls`.
## 2. Content APIs: quests, NPCs, items, minigames

1. **Quest rings from the options.** `FairStories.has_quest` and `PlaygroundQuests.has_quest`
   repeat the conditions of their `options` (they can't use the default, collecting Lothar's
   options counts a talk). Let an option say itself that it is a quest step
   (`{"text", "action", "quest": true}`) and derive the ring from that.
2. **One quest state API.** Progress is kept as bool flags (`Quests`), string flags
   "" / "active" / "done" read raw (`dwarf_quests.gd`, `fair_stories.gd`, 15×), integer steps in
   stats (`pg_step`, `assistant_step`), plus extra stats only to fire achievements
   (`quests.gd:180`, `fair_stories.gd:440,461,515`). Daily cooldowns three ways: stat
   `Clock.day + 1` (9 sites), a new flag key per day (`troll_today_%d`, `quests.gd:192`: one
   save key per day forever), `Cinema.ticket_day` (not saved). Proposal: `GameState.stage(id)` /
   `set_stage(id, n)` (monotonic ints in stats, achievements keep working) and
   `done_today(key)` / `mark_today(key)`; migrate the old keys (needs 2.3). Not saved at all
   today: `Cinema.ticket_day`, the `DriveIn` order, `Quests.walk_state`.
3. **Save versioning.** `GameState.VERSION` is written but never checked; renaming any stat,
   flag or item id silently drops progress. Check it on load and migrate.
4. **Ids with one definition.** 114 stat keys are written as literals in ~40 files (51 are ever
   read); achievement targets copy module constants (gnomes 7 also as `"(%d/7)"` in three files,
   stamps 16, tricks 4, `pg_step` 6). One Kirmes booth has four spellings (`booth_cans`,
   `BoothGame.booth` "cans", the stamp, `FairLayout.booths["cans"]`), a ride too. Stat/flag
   constants, achievement targets from the module constants, one id per booth and ride.
   `GameState.stats` is written directly in `rally_game.gd:87` (no signal, no achievement check).
5. **One reward path.** "Rucksack ist voll" exists 8× (callers pre-check `can_add` and toast
   themselves), `inventory` is written directly (`world.gd` bottles, `duck_feeding.gd`), reward
   feedback (cheer, heart, sound) is repeated 11×, the end-of-game pattern (best stat, win stat,
   host line, `end_after`) in most games. `Rewards.give(actor, items, money, tickets, reason)`
   and `Minigame.record(best_stat, score, win_stat, won)`.
6. **Data instead of code.** `Shop.setup` is an 85-line `match` of pure data and repeats the
   vendor ids that `Cast` already has (`work.shop`); greetings live in `Conversations.GREETINGS`
   instead of `Cast`; `Food.ITEMS` repeats name and price of 9 `Items`; the Oststadt game spots
   (`Gameplay.setup_city`) and vehicle starts (`city.gd:39-44`) repeat the same coordinates, and
   `HumanBrain._spot` has its own (the switch tower at (95, −238.5) vs (95.4, −238) in
   `gameplay.gd`): all into `ParkLayout`/`CityLayout` places. A `FunctionSpot.make()` factory
   for the four private `_spot` helpers (`gameplay.gd`, `easter_eggs.gd`, `fair_stories.gd`,
   `drive_in.gd`) and the inline copies.
7. **`Cinema` is a `Minigame` outside `Gameplay.minigames`** (created in `city.gd`):
   `Gameplay.any_active()`, the task board and the markers don't see it.

## 3. Areas

1. **An `Area` abstraction.** The park, the Oststadt and the Westpark are wired by hand in ~15
   places: `load_city`/`load_fair` and `_set_city_awake`/`_set_fair_awake` are twins
   (`world.gd`), `area_built`/`area_awake`/`_open`, `home_area`, `HORIZON`, the `is_solid` and
   `in_world` branches and border rows in `ParkMap`, `AreaGates.GATES` plus
   `PlayerController.near_city_gate`, `Game._spawn_city_cast`/`_spawn_fair_cast`, `MapImage`,
   the map screen, `Sound.add_ambient`. One `Area` (id, bounds, grid columns, layout, map/builder/
   runtime factories, backdrop, gates, cast, ambient) and World iterating a list would make the
   next area cheap. Regions vs areas: `home_region` has four values (park, forest, city, fair),
   `World.AREAS` three; `Actor.forest_dweller` duplicates `home_region`.
2. **`BuildKit` for the builders.** `ParkDecorator`, `FairBuilder`, `CityBuilder`,
   `ForestDecorator` each have `add`/`label`/`gy`/`fwd`/`right`/`new_bench`; tree placement
   (`_free_for_tree`, `_plant`) is copied between `Vegetation` and `FairBuilder`; seven bench
   creators with three id schemes (the playground's from `get_child_count()`); picnic-table
   seats copied (`park_decorator.gd`, `fair_builder.gd`), city picnic tables have none; label
   defaults differ (`visibility_range_end` 110 / 90 / none).
3. **Magic coordinates into the layouts**: city decor positions absolute where the lot
   rectangle is at hand (`city_decor.gd`, the city playground), fair centre in `fair.gd` and
   `fair_builder.gd`, park bounds as literals in `vegetation.gd`, Nussi's stash in `world.gd`.
4. **One RNG per builder part.** `park_decorator.gd` keeps unreachable `side == 0` branches and
   throws away a computed side 2 only to keep the shared random sequence; seed each part.
## 4. Actors

1. **Who controls an actor.** A brain/activity, `custom_motion` (written from 5 files), direct
   `anim =` writes (81 outside `Actor`), direct `global_position =` writes, the minigame
   take-over (`brain.suspend()` and `player.input_enabled`), and hiding by hand
   (`inside = true; visible = false` in `game.gd`, `player_controller.gd` next to
   `Actor.set_dormant`; `inside` written from 11 files). One lock API
   (`take_control(owner)` / `release`) and `hide_inside()`.
2. **One way to ride something that moves.** Playground seats (`riders`, `_carry`), Kirmes rides
   (`custom_motion`, `_place_rider`) and cars (`carry_driver`) each carry their rider
   differently: a `MountPoint` (node + local transform) that `Actor` follows.
3. **Species table** (rig, brain, special action, sound, greeting, spawn rule): 43
   `species ==`/`in` checks in 6+ files, `["duck", "duckling", "goose"]` five times.
4. **Split `AnimalBrain`** (877 lines, the union state of ten species) into a base and one class
   per species with public actions.
5. **Low-level code that knows features**: `Actor.sit_on` writes the benches/oases achievement
   sets, `food.gd` five stats, `World` holds Nussi's stash (a mesh, `world.gd`) and pays the
   bottle deposit, `shop.gd` names 18 vendor ids. Signals (`seat_taken`, `food_eaten`) and the
   modules listen.
## 5. Structure

1. **Split the big files**: `world.gd` (area manager, registries, actor index, litter and food),
   `player_controller.gd` (input, focus, driving, sleeping; the two fade sequences are near
   copies), `ui.gd` (toasts, dialog, pause/settings, title, loading), `activities.gd` (one file
   per activity under `src/ai/activities/`), `fair_models.gd` (rides, halls, booths, figures),
   `prop_models.gd` (the old playground set used by the city playground, the legacy backdrop,
   items), `park_decorator.gd` (the horizon builders).
2. **Record classes instead of dictionaries** (1194 string-key subscripts): `Playground.riders`
   and `motions`, `Traffic` lanes and crossings, `World.foods`, the tree dicts, `Gathering` jobs,
   dialog options.
3. **Stricter GDScript warnings** (`untyped_declaration`, `unsafe_property_access`) once 5.2 is
   done.
4. **The `UI` autoload reaches into the scene** (`game.player`, `game.world` in `ui.gd`,
   `hud.gd`): the HUD should get its data through signals.

## 6. Performance (measure first)

1. **`MeshKit.add_mesh`** copies vertex by vertex (four `SurfaceTool` calls each): transform
   packed arrays in bulk; it is most of `load_city`'s decor time and the playground build.
2. **`PlayerController._update_focus`** checks every interactable each frame, those of sleeping
   areas too: a bucket grid like `actors_near`.
3. **`FairBackdrop`** is ~40 separate instances (draw calls), the park's 234 ground chunks have
   no visibility range, `InstanceBatcher` keeps a handle for every grass tuft.
4. **Start-up in GDScript**: `_free_for_tree` scans benches, places and areas linearly for ~20k
   tries, `_fill_grid` fills ~280k cells; bake to resources if the web start gets slow.
5. **The map texture is built twice at start**: the info boards take a view before the trees
   are known (`ParkDecorator._info_board`), `World.build` resets and rebuilds it with trees; the
   boards keep the first texture (~3.4 MB more, boards without trees).
6. Areas sleep but stay in memory (~260 MB with all three): free a sleeping area and rebuild it
   on return if phones run short.

## Animals: hunger
Checked: animals **can** eat (`animal_brain.gd`): ducks, geese, pigeons and dogs forage
(`state == "forage"`, `needs.eat(45)`), others go to the food bowl at the kiosk, and they take
treats from visitors and the duck-feeding minigame. Since they are also rested at midnight
(`Game.rest_animals_at_midnight`), nothing needs to change. Only revisit if animals are seen
starving with no food reachable (e.g. in the Nordwald).
