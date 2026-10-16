# To-Dos

Open items only, in the order they should be done. The order follows what makes the next step
cheaper: the test net first (done, leftovers below; every refactoring leans on it), then actors and
structure, performance last where it needs measuring. (The content APIs and the areas are done:
doc/arc42.md §5.4 and §8.8.) Each item names the evidence (file:line as of 2026-10-15).

## 1. Test net: leftovers

The test net is done (doc/arc42.md §8.9): `release.sh` runs the scenario files that cover the
changes (`tests/scenario_map.txt`), life over game hours is checked by the simulation's
invariants, town and Westpark sleep in park tests, `scripts/web_test.sh perf` holds draw-call
budgets. Open:

1. **"Neues Spiel" → "Ja"** is untested: the scene reload frees the scenario runner (a child of
   `Game`) and starts the dev options again. Needs a runner that lives outside the scene.
2. **Draw-call budgets only run in the browser** (`web_test.sh perf`, ~5 min with the export),
   not in `release.sh`: run them after changes to models, MeshKit or batching.

## 2. Actors

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
   bottle deposit. Signals (`seat_taken`, `food_eaten`) and the modules listen.

## 3. Structure

1. **Split the big files**: `world.gd` (area manager, registries, actor index, litter and food),
   `player_controller.gd` (input, focus, driving, sleeping; the two fade sequences are near
   copies), `ui.gd` (toasts, dialog, pause/settings, title, loading), `activities.gd` (one file
   per activity under `src/ai/activities/`), `fair_models.gd` (rides, halls, booths, figures),
   `prop_models.gd` (the old playground set used by the city playground, the legacy backdrop,
   items), `park_decorator.gd` (the horizon builders).
2. **Record classes instead of dictionaries** (1194 string-key subscripts): `Playground.riders`
   and `motions`, `Traffic` lanes and crossings, `World.foods`, the tree dicts, `Gathering` jobs,
   dialog options.
3. **Stricter GDScript warnings** (`untyped_declaration`, `unsafe_property_access`) once 3.2 is
   done.
4. **The `UI` autoload reaches into the scene** (`game.player`, `game.world` in `ui.gd`,
   `hud.gd`): the HUD should get its data through signals.
5. **Area bounds in one place.** The `Area` classes own building, sleeping and cast, but an
   area's extent is still spread out: grid columns (`ParkMap.PARK_X0`, `CITY_X0`, `FAIR_Z0`),
   the branches of `ParkMap.is_solid`/`in_world`/`_fill_grid`, `World.area_of`,
   `MapImage.add_city`/`add_fair` and the map screen's views. Give `Area` its rectangle and
   grid range and let these iterate.

## 4. Performance (measure first)

1. **`MeshKit.add_mesh`** copies vertex by vertex (four `SurfaceTool` calls each): transform
   packed arrays in bulk; it is most of the Oststadt's build time (CityDecor) and the playground build.
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
