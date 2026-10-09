# Test scenarios

Catalogue of everything a player can do in "Bank frei!", and whether an automated scenario test
covers it. Scenario tests run the real game natively and headless (no browser) and play it like a
player: real input actions (`interact`, `special`, `move_*` …), keys, mouse clicks, touch taps on
buttons, dialog choices. They check the game state afterwards.

```bash
scripts/scenario.sh                         # all files (3 in parallel, ~2 min)
scripts/scenario.sh shops bench             # some files
scripts/scenario.sh bench:test_nap_via_touch_button   # one test
VERBOSE=1 scripts/scenario.sh secrets       # with the game's own output
```

Files: `tests/scenarios/<area>.gd`, base class and helpers: `tests/scenario.gd`.
`scripts/test.sh` runs them after the unit tests.

**Keep this file up to date:** when you add a feature, add its rows here; when you add a test, set
its status. A feature is only "done" with a ✅ row.

## Legend

| Status | Meaning |
|---|---|
| ✅ | Scenario test with real input (keys, clicks, taps, dialog choices) |
| 🔶 | Tested, but through a shortcut: a start state set directly, or an internal call instead of the input (reason in the row) |
| ⬜ | Not tested yet; the row says how to test it |

## Start states and reach tests

Tests may start directly at the interesting point instead of walking there. Every shortcut needs
a **reach test** that gets to the same point by playing, so the way there stays covered.

| Start state (helper in `tests/scenario.gd`) | What it skips | Reach test |
|---|---|---|
| `reset(who, hour)`: fresh game, `who` on the great meadow, rested, camera behind, 11:00 sunny | title screen, choosing a character | `screens::test_title_new_game_with_starter`, `screens::test_title_continue` |
| `in_minigame(id)`: game started directly (no fee, host present) | walking to the game, paying | `minigames_reach::*` (all 8 games, fee, no money, host away) |
| `on_bench(fatigue)`: seated on the nearest free bench | walking to a bench, sitting down | `bench::test_reach_bench_and_sit` |
| `open_shop(id)` + `at_shop(id)`: vendor at work, player at the counter | waiting for opening hours, walking there | `shops::test_reach_donut_stand_and_buy` |
| `next_to(id)`: player teleported next to an NPC | finding and walking to the NPC | `quests::test_dog_walk` (walks to the meadow and back to Mia), `minigames_reach::test_*_by_talking_*` |
| `put_player(pos)`: player teleported to a spot (gnome, fountain, statue …) | walking there | `secrets::test_find_all_gnomes_by_walking`, `secrets::test_nussi_stash` |
| Direct state for rare outcomes: `m.board` (ttt), `m.total`/`m.strokes` (minigolf), `m.time_left`/`m.score` (ducks), `GameState.add_stat` for "x times" achievements | dozens of games or a lucky shot | the normal game flow is tested in the same file (full game by input) |

Other helpers: `press(action)`, `hold(action, s)`, `move(dir, s, run)`, `key(KEY_x)`,
`type_text("quak")`, `click_at(pos)`, `click_button(text)`, `tap_button(text)` (real touch event),
`tap_screen(pos)`, `choose(option)`, `dialog_text()`, `prompt()`, `toasted(text)`,
`walk_to(pos)` (pathfinding, like tap-to-walk), `wait(s)`, `wait_until(cond, s)`,
`play_until_done(minigame, step, s)`.

## 1. Movement and camera — `movement.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Walk with WASD/arrows (camera-relative) | ✅ | `test_walk_with_keys` |
| Run with Shift, faster than walking | ✅ | `test_run_is_faster_than_walking` |
| Player 2× NPC speed without counting as "running" for needs | ✅ | `test_player_walk_does_not_tire_like_running` |
| Touch "Rennen" toggle | ✅ | `test_touch_run_toggle` |
| Tap on the ground walks there | ✅ | `test_tap_to_walk` |
| Left click on the ground walks there | ✅ | `test_click_to_walk_with_mouse` |
| Tap on the sky does nothing | ✅ | `test_tap_on_sky_does_nothing` |
| Unreachable target shows "?" | ⬜ | Pathfinding always finds the nearest open cell (8 m search), so no pond point is unreachable. Needs a closed-off area; a script error in this path was fixed (`actor.rig.emote_text`) |
| Tap on a character: talk (< 3 m) or walk to it | ⬜ | `tap_screen(camera.unproject_position(npc head))`, check dialog / `is_moving()` |
| Virtual joystick (touch) | ⬜ | Touch + drag inside the joystick base (bottom left), check `player.touch_move` and movement |
| Joystick > 92 % = running | ⬜ | Same, drag to the edge, check `actor.running` |
| Gamepad sticks and buttons | ⬜ | `InputEventJoypadMotion`/`JoypadButton` via `Input.parse_input_event` |
| Mouse wheel zoom | ✅ | `test_mouse_wheel_zoom` |
| Touch zoom buttons +/-, limits 0.45–3.5 | ✅ | `test_touch_zoom_buttons_and_limits` |
| Pinch zoom with two fingers, no walking | ✅ | `test_pinch_zoom` |
| Camera keys `,` `.` | ✅ | `test_camera_keys_turn` |
| Camera drag with mouse / one finger | ⬜ | `InputEventMouseMotion` with button mask / `InputEventScreenDrag`, check `camera.yaw` changes and no walking |
| Camera follows behind a moving player after 2.5 s | ⬜ | Orbit away, walk, check yaw returns to `actor.yaw + PI` |
| Swimming (ducks, goose) | ⬜ | Control `erwin`, move into the pond, check `actor.swimming` |
| Humans cannot enter water | ⬜ | Walk towards the pond with keys, check position stays on land |

## 2. Benches, sitting, nap, sleep — `bench.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Walk to a bench, prompt "Hinsetzen", sit with Aktion, stand up with Aktion | ✅ | `test_reach_bench_and_sit` |
| Bench counted for Bankdrücker | ✅ | `test_reach_bench_and_sit`, `secrets::test_bench_presser` |
| Sitting lowers fatigue (84/h) | ✅ | `test_sitting_recovers_fatigue` |
| Nap with Spezial, prompt "Aufwachen", wake with Aktion, still seated | ✅ | `test_nap_with_special_and_wake_with_action` |
| Nap ends by itself when rested ("Ausgeschlafen!") | ✅ | `test_nap_ends_when_rested` |
| Walking away ends the nap | ✅ | `test_walking_away_ends_nap` |
| Phone: Spezial button naps (bug from 4d5025a), Aktion button wakes | ✅ | `test_nap_via_touch_button` |
| Night sleep: nap after dark → fade, morning 06:00, rested, stat `nights_on_bench` | ✅ | `test_night_sleep_until_morning` |
| Hunger rises over the night (max 85) | ⬜ | In `test_night_sleep_until_morning`: set hunger 50 before, check 50 < hunger ≤ 85 |
| "Bank besetzt" when all seats are taken | ⬜ | Seat NPCs on all seats of a bench, check prompt |
| Bench plaque toast | ✅ | `secrets::test_bench_plaque` |
| Other seats: picnic tables, swings, chess stools, blankets | ⬜ | `put_player` at `world.benches` with `kind` table/swing/stool/blanket, Aktion, check `seat.kind`; swing moves |
| Animals can sit on benches | ⬜ | Decide first whether that is wanted (`Bench.can_interact` ignores species) |

## 3. Food, stands, money — `shops.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Walk to a stand, prompt "Einkaufen: …", menu dialog, buy | ✅ | `test_reach_donut_stand_and_buy` |
| Every menu item of all five stands and both snack machines has the right price | ✅ | `test_every_menu_item_of_every_stand` |
| Snack machines (west and east gate): open at night without a vendor, "Klonk!" toast | ✅ | `test_snack_machine_at_night` (screenshot `snack_machine_night`) |
| Vendors stand behind the carts; inside donut stand and kiosk behind the open window | 🔶 | `test_vendors_behind_the_counter` checks positions; visibility only in the browser screenshots `vendor_*` |
| Food effects on hunger, fatigue, joy (hot dog, fries, coffee) | ✅ | `test_food_effects_on_needs` |
| Closed stand: prompt "(geschlossen)", toast, no menu | ✅ | `test_closed_stand` |
| Not enough money: toast, nothing bought | ✅ | `test_not_enough_money` |
| Duck bread from the kiosk (+5) | ✅ | `test_duck_bread_from_kiosk` |
| Water gives a deposit bottle; kiosk takes it back (25 ct) | ✅ | `test_water_gives_deposit_bottle_and_kiosk_takes_it_back` |
| Balloon and newspaper are held | ✅ | `test_balloon_and_newspaper_are_held` |
| Feinschmecker (5 snacks) | ✅ | `test_gourmet_achievement` |
| Zuckerschock (5 donuts in a row, coffee resets) | ✅ | `test_sugar_rush` |
| Dog begs at the hot dog stand | ✅ | `test_dog_begs_at_hotdog_stand` |
| Begging cooldown "Du schon wieder? Nein!" | ⬜ | Beg twice without resetting `_beg_cooldown`, check `vendor.last_said` |
| Stands close after working hours | ✅ | `world::test_stands_close_at_night` |
| Stands open on time: a strolling vendor goes to the stand when work starts | ✅ | `test_stand_opens_on_time_after_a_stroll` |
| After a night on a bench every stand opens by its start hour (vendors come early, at the gate near the stand, no trip to eat right before work) | ✅ | `test_stands_open_after_a_night` |
| Vendor adverts when a human is near | ⬜ | Stand near an open stand for 45 s, check `vendor.last_said` in `Shop.ADVERTS` |
| Nussi steals a donut from a seated player | ⬜ | Buy donut, sit on a bench near Nussi's tree, wait; check toast "Nussi hat dein Essen geklaut!" and no hunger effect |
| HUD money label | ✅ | `screens::test_hud_shows_money_and_clock` |

## 4. Characters, switching, special actions — `characters.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Q opens the switch menu, choose a character | ✅ | `test_switch_with_key_and_menu` |
| Cancel the menu; nobody near → toast | ✅ | `test_switch_menu_cancel_and_nobody_near` |
| Switch by talking ("Zu … wechseln") | ✅ | `test_switch_by_talking` |
| Touch button "Wechseln" | ✅ | `test_touch_switch_button` |
| Verwandlungskünstler (10 characters) | 🔶 | `test_shape_shifter_achievement` switches via `player.control()`; the menu path is tested above |
| Human waves, neighbour waves back | ✅ | `test_human_waves_and_neighbour_waves_back` |
| Dog barks, cat and pigeon flee | ✅ | `test_dog_bark_scares_cat_and_pigeon` |
| Cat grooms; pounces on mice; Katz und Maus | ✅ | `test_cat_and_mouse_achievement` |
| Squirrel climbs a tree, F climbs down; Kletterass | ✅ | `test_squirrel_climbs_trees` |
| Squirrel: no tree → toast | ✅ | `test_squirrel_climbs_trees` (first press) |
| Duck, duckling, goose, mouse, pigeon, hedgehog, fox specials | ✅ | `test_duck_goose_mouse_pigeon_hedgehog_fox_specials` |
| Dance (R); Regentänzer in the rain | ✅ | `test_dance_and_rain_dancer` |
| Dog rolls on R | ✅ | `test_dog_rolls_on_emote` |
| F while the squirrel is still climbing up is ignored | ⬜ | Decide whether it should climb down; today only works at the top |
| Controlling a vendor closes the stand; controlling a host disables the game | ⬜ | `control(present("dora"))`, check `shop.is_open()` false; spot prompt "(… ist nicht da)" |

## 5. Minigames

Reach tests for all games: `minigames_reach.gd` (spot + Aktion for boule, minigolf, shell, ttt,
ducks, bottles; talking for frisbee, photo, shell; fees 2 € for minigolf and shell; no start
without money; "(… ist nicht da)" when the host is away).

### 5.1 Boule — `boule.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Start at the court / via Jacques | ✅ | `test_reach_by_walking_to_the_court`, `test_reach_by_talking_to_jacques` |
| Aim with held keys, `<`/`>` buttons, clamp ±25° | ✅ | `test_aim_with_keys_and_buttons` |
| Power bar on the player's turn, throw with Aktion | ✅ | `test_throw_with_action` |
| Camera close-up while the ball rolls, back to the overview | ✅ | `test_camera_follows_throw` |
| Full game (6 balls, petanque turn order), result dialog, money on a win | ✅ | `test_full_game_by_pressing_action` |
| Esc quits | ✅ | `test_quit_with_pause` |
| Throw by mouse click on the view | ⬜ | `click_at(center)` on the player's turn, check `player_left` |
| Swaying aim line (±6°) | ⬜ | Sample `_sway()` over time, check range and that the thrown direction includes it |
| Jacques sometimes shoots at the player's ball | ⬜ | Seed + many AI throws, check a player ball moved |
| Boule-König (3 wins) | ⬜ | 🔶 possible: `GameState.add_stat("boule_wins")` ×3; better: win 3 games with a seed that wins |

### 5.2 Minigolf — `mg_minigolf.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Aim with keys and buttons | ✅ | `test_aim_keys_and_buttons` |
| Putt with Aktion, ball rolls and stops | ✅ | `test_putt_with_action` |
| Full round of six holes by pressing Aktion, result dialog | ✅ | `test_full_round_by_pressing_action` |
| Hole-in-one counts (Ass!) | 🔶 | `test_hole_in_one_counts` calls `_holed()` with 1 stroke (a real ace needs exact power timing) |
| Under par: money and Minigolf-Profi | 🔶 | `test_under_par_pays_and_unlocks_pro` sets `total` |
| Water on the bridge hole: +1 penalty, ball back | ⬜ | `m.hole = 5; m._start_hole()`, aim off the bridge, putt, check `strokes` +2 and `ball.p == _last_safe` |
| Windmill blocks the ball | ⬜ | Hole 3, putt while `windmill_closed(t)`, check the ball bounces |
| Six strokes max per hole | ✅ | Covered by `test_full_round_by_pressing_action` (round always ends) |
| Putt by mouse click | ⬜ | `click_at(center)` in aim state |

### 5.3 Hütchenspiel — `mg_shell.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Nut shown, then shuffled | ✅ | `test_shows_nut_then_shuffles` |
| Pick with keys 1–3, right cup wins 4 € | ✅ | `test_right_pick_with_key_wins` |
| Pick with the buttons, wrong cup loses, streak reset | ✅ | `test_wrong_pick_with_button_loses` |
| Pick by clicking a cup | ✅ | `test_pick_by_clicking_the_cup` |
| Adlerauge (3 wins in a row) | ✅ | `test_eagle_eye_after_three_wins` |
| No picking while shuffling | ✅ | `test_no_pick_while_shuffling` |

### 5.4 Tic-Tac-Toe — `mg_ttt.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Key places a cross (numpad layout), Boris answers, occupied cells ignored | ✅ | `test_key_places_cross_and_boris_answers` |
| Click on the board | ✅ | `test_click_on_board` |
| Win: 4 €, Großmeister | 🔶 | `test_win_pays_four_euro` starts one move before winning |
| Draw: 1 € | 🔶 | `test_draw` starts one move before a draw |
| Full game with keys | ✅ | `test_full_game_with_keys` |
| Esc quits | ✅ | `test_quit_with_pause` |
| Boris wins | ⬜ | Board where Boris wins next, player move elsewhere |

### 5.5 Futterchaos — `mg_ducks.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Move the target with keys, throw bread with Aktion | ✅ | `test_move_target_and_throw` |
| Hungry duck eats → +1 | 🔶 | `test_feeding_a_hungry_duck_scores` aims at the duck by setting `target` (keys move it too, see above) |
| Goose steals → −1 | ⬜ | Put Gustav next to the target, throw, check `score` and info text |
| Time runs out: result, money 20 ct per duck, best score | 🔶 | `test_time_runs_out` sets `time_left`/`score` |
| Own bread is restored afterwards | ✅ | `test_bread_inventory_restored` |
| Aim with the mouse / click to throw | ⬜ | Mouse motion over the water, check `target` |
| Futterchaos achievement (15) | ⬜ | `m.score = 15`, let time run out |

### 5.6 Pfandjagd — `mg_bottles.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| 14 bottles spawn, free walking | ✅ | `test_collect_and_return_bottles` |
| Walk to bottles, "Pfandflasche aufheben", return at the machine, 25 ct each | ✅ | `test_collect_and_return_bottles` |
| Esc opens the pause menu, game keeps running | ✅ | `test_esc_pauses_instead_of_quitting` |
| "Beenden" button; time up → result | ✅ | `test_beenden_button_and_timeout` |
| 10+ bottles: 1 € bonus; Pfandkönig (50) | ⬜ | Return 10 in the game (`add_item("empty_bottle", 10)` + machine), check bonus; 50 via machine |
| Litter appears near benches over the day, gardener Kalle collects it | ⬜ | Simulation: count `world.bottles` over game hours |

### 5.7 Frisbee — `mg_frisbee.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Aim and throw, Balu runs | ✅ | `test_throw_and_balu_runs` |
| Five throws end the game, catches saved | ✅ | `test_five_throws_end_the_game` |
| Play as Balu: Lukas throws, run to the disc, catch | 🔶 | `test_play_as_balu_and_catch` runs with `go_to(land)` (pathfinding) instead of the stick |
| Wind in rain/storm | ⬜ | Weather STORM, check `wind.length() > 1` and landing offset |
| Frisbee-Profi (5 catches) | ⬜ | As Balu, catch all five |

### 5.8 Foto für Peggy — `mg_photo.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Look around with keys, zoom buttons, shoot with Aktion, busy while shown | ✅ | `test_look_zoom_and_shoot` |
| Three photos end the game, money ≥ 1 € | ✅ | `test_three_photos_end_the_game` |
| A second game with Peggy works | ✅ | `test_play_twice` (regression) |
| Scoring: Peggy in frame, landmark, smile | ⬜ | Point the camera at Peggy and the landmark (set `yaw`/`pitch`), wait for `smile`, shoot; check `best >= 90` and Starfotograf |
| Mouse drag to look, wheel zoom, touch drag | ⬜ | Mouse motion with right button, `InputEventScreenDrag` |
| Polaroid image | ⬜ | Only with rendering (browser screenshot); headless uses a blank image |

### 5.9 Axtwerfen, Holzhacken, Stellwerk (Nordwald) — `mg_forest.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Axe throwing: crosshair wanders, Action throws, wind, five throws, 30 points to win | ✅ | `test_axe_throw_full_game` |
| Rings score 10/8/6/4/2, a wild throw misses | ✅ | `test_axe_miss_scores_nothing` (wind set for a sure miss) |
| Wood chopping duel: Action in the green zone splits, beat Holger, firewood into the bag | ✅ | `test_chop_duel` |
| A miss costs a moment | ✅ | `test_chop_miss_costs_time` |
| Switchman: flip the switch per cart, 15 right wins (Thrain's job) | ✅ | `test_switchman` |
| Three wrong carts end the shift | ✅ | `test_switch_mistakes_end_shift` |
| Start spots at the target, the block and the signal box; fee 1 € for axe throwing | ✅ | `test_reach_forest_games` |
| Layout on all screens | ✅ | `layout::test_mg_axes`, `test_mg_chopping`, `test_mg_switch`; screenshots `mg_axes`, `mg_chopping`, `mg_switch` |

## 6. Quests and jobs — `quests.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Dog walk: accept at Mia, walk to the dog meadow, dog plays, bring it back, 4 € | ✅ | `test_dog_walk` |
| Switching character cancels the walk, dog back to Mia | ✅ | `test_dog_walk_cancelled_by_switching` |
| Only humans get the job | ✅ | `test_dog_walk_only_for_humans` |
| Gassi-Profi (5 walks) | 🔶 | `test_dog_walker_achievement` adds the stat |
| Mime gets stuck (hourly, 50 %), hint from Pierre, key from Lena, free him | ✅ | `test_mime_quest` |
| Troll riddle at night: right answer → Brückenrätsel, no more riddles | ✅ | `test_troll_riddle_right` |
| Wrong answer blocks the rest of the night | ✅ | `test_troll_riddle_wrong_blocks_the_day` |
| Notebook: the running quest is the first row, highlighted | ✅ | `test_running_quest_on_top_of_the_notebook` |
| Task board shows each quest step ("Bring … zurück zu Mia") | ⬜ | Open J in each walk state, check the row text |
| Gold ring under a quest giver with an open quest, only near (< 18 m), none while the job runs | ✅ | `test_marker_on_quest_giver` (screenshot `ring_mia`) |
| Gold ring under Pierre and Lena (mime stuck) and troll Bruno (riddle open) | ✅ | `test_markers_on_mime_quest_and_troll` |
| Gold ring at unfound garden gnomes, gone once found | ✅ | `test_marker_on_gnome_until_found` |
| Blue ring at minigames whose notebook goal is open | ✅ | `test_marker_on_minigame_until_done` |

## 7. Secrets and easter eggs — `secrets.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| 7 garden gnomes, walk to each, Zwergenjäger | ✅ | `test_find_all_gnomes_by_walking` |
| Gnome found twice → "schon gefunden" | ✅ | `test_gnome_found_twice` |
| Wishing fountain (20 ct, stat, Wunschbrunnen) | ✅ | `test_wishing_fountain` |
| Fountain without money | ✅ | `test_wishing_fountain_without_money` |
| Animals look into the fountain | ✅ | `test_animal_looks_into_fountain` |
| Wish outcomes: sun, confetti, 2 €, pigeons, quack | ⬜ | Seed per outcome, check weather / money / pigeons' state |
| Pet the duck statue 5× → duck hats, Quak! | ✅ | `test_pet_duck_statue_five_times` |
| Type "quak" → hats on, again → off | ✅ | `test_type_quak` |
| Nessie in fog, seen from the shore | ✅ | `test_nessie_in_fog` |
| No Nessie on a sunny day | ✅ | `test_no_nessie_on_a_sunny_day` |
| Nessie at night 23:00–04:30 | ⬜ | Like the fog test at 23:30 |
| UFO at 00:30, looking up over the great meadow | ✅ | `test_ufo_at_night` |
| Nussi's stash: walk there, "Astloch untersuchen", Diebesgut | ✅ | `test_nussi_stash` |
| Bench plaques | ✅ | `test_bench_plaque` |
| Info boards open the map | ✅ | `test_info_board_opens_map` |
| Nachteule at midnight | ✅ | `test_night_owl_at_midnight` |
| Vier Jahreszeiten | 🔶 | `test_all_seasons` calls `Clock.set_season` (a real year is 12 game days) |
| Sparschwein (50 €) | 🔶 | `test_saver` adds money directly |
| Bankdrücker (25 benches) | ✅ | `test_bench_presser` (teleport to each bench, Aktion) |

## 8. Achievements (36)

| Achievement | Status | Where |
|---|---|---|
| Entenflüsterer (20 ducks fed) | ⬜ | Buy bread, "Brot zuwerfen" at a duck 5×, check `ducks_fed`; rest via stat |
| Zuckerschock | ✅ | `shops::test_sugar_rush` |
| Bankdrücker | ✅ | `secrets::test_bench_presser` |
| Boule-König | ⬜ | see 5.1 |
| Ass! | 🔶 | `mg_minigolf::test_hole_in_one_counts` |
| Minigolf-Profi | 🔶 | `mg_minigolf::test_under_par_pays_and_unlocks_pro` |
| Adlerauge | ✅ | `mg_shell::test_eagle_eye_after_three_wins` |
| Frisbee-Profi | ⬜ | see 5.7 |
| Starfotograf | ⬜ | see 5.8 |
| Pfandkönig | ⬜ | see 5.6 |
| Gassi-Profi | 🔶 | `quests::test_dog_walker_achievement` |
| Futterchaos | ⬜ | see 5.5 |
| Großmeister | 🔶 | `mg_ttt::test_win_pays_four_euro` |
| Verwandlungskünstler | 🔶 | `characters::test_shape_shifter_achievement` |
| Nachteule | ✅ | `secrets::test_night_owl_at_midnight` |
| Regentänzer | ✅ | `characters::test_dance_and_rain_dancer` |
| Vier Jahreszeiten | 🔶 | `secrets::test_all_seasons` |
| Sparschwein | 🔶 | `secrets::test_saver` |
| Katz und Maus | ✅ | `characters::test_cat_and_mouse_achievement` |
| Kletterass | ✅ | `characters::test_squirrel_climbs_trees` |
| Feinschmecker | ✅ | `shops::test_gourmet_achievement` |
| Zwergenjäger | ✅ | `secrets::test_find_all_gnomes_by_walking` |
| Unsichtbare Hilfe | ✅ | `quests::test_mime_quest` |
| Seeungeheuer! | ✅ | `secrets::test_nessie_in_fog` |
| Brückenrätsel | ✅ | `quests::test_troll_riddle_right` |
| Wunschbrunnen | ✅ | `secrets::test_wishing_fountain` |
| Diebesgut | ✅ | `secrets::test_nussi_stash` |
| Unheimliche Begegnung | ✅ | `secrets::test_ufo_at_night` |
| Quak! | ✅ | `secrets::test_pet_duck_statue_five_times` |
| Holzfäller, Glück auf!, Petri Heil, Handwerker, Händler, Ehrenzwerg (Nordwald) | 🔶 | `gathering::test_nordwald_achievements` (counters; felling, mining, fishing, crafting, trading and the dwarf jobs are played for real in `gathering`, `crafting`, `forest_people`); gems counted: `gathering::test_gem_counts` |
| Fettnäpfchen | ✅ | `forest_people::test_gnome_insult` |
| Achievement popup and reward money | ⬜ | Unlock one, check `UI._achievement` visible and money + reward |

## 9. Screens and menus — `screens.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| M opens/closes the map, Esc closes it (no pause) | ✅ | `test_map_opens_and_closes_with_m` |
| HUD button "Karte", "Schließen" | ✅ | `test_map_hud_button` |
| Click on the map walks there | ✅ | `test_map_click_walks_there` |
| Click on an unreachable map point → "Da kommt … nicht hin." | ⬜ | Click the pond centre on the map as a human |
| Notebook (J): tabs, achievement count, tasks | ✅ | `test_notebook_tabs` |
| Done task marked "geschafft" | ✅ | `test_notebook_marks_done_task` |
| Pause (Esc): time stops, Weiterspielen | ✅ | `test_pause_menu_stops_time` |
| Save from the pause menu, load restores money, stats, character | ✅ | `test_save_from_pause_menu_and_load` |
| Settings: quality buttons, back | ✅ | `test_settings_quality_and_back` |
| Settings: volume sliders, camera sensitivity, FPS checkbox | ⬜ | Change slider `value`, check `GameState.settings`; FPS label visible |
| Help screen | ✅ | `test_help_screen` |
| "Neues Spiel" from the pause menu (confirm, reload) | ⬜ | Reloads the scene; test that "Nein" returns to the pause menu, and "Ja" in its own test |
| Title: new game, starter choice, welcome toast; game input blocked | ✅ | `test_title_new_game_with_starter` |
| Title: continue with the saved character | ✅ | `test_title_continue` |
| Many toasts at once (regression: froze the game) | ✅ | `test_many_toasts_at_once` |
| HUD: clock, money, toast | ✅ | `test_hud_shows_money_and_clock` |
| HUD need bars and trend arrows | ⬜ | Sit tired, check the fatigue bar's arrow state in `Hud` |
| Autosave every 60 s | ⬜ | Wait 61 s, check the save file exists |
| Needs and inventory survive save/load | ⬜ | Set needs and items, save, change, `load_game` + `load_state`, compare |
| Android download button (web only) | ⬜ | Web only; screenshot preset `title` |

## 10. Needs, time, weather, seasons — `world.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Hunger rises, joy decays over a game hour | ✅ | `test_hunger_and_fatigue_rise_over_time` |
| Very hungry → slower | ✅ | `test_very_hungry_is_slower` |
| Hint toasts: hungry, tired, sad | ✅ | `test_hint_when_hungry`, `test_hint_when_tired_and_sad` |
| People go home at night | ✅ | `test_people_go_home_at_night` |
| Stands close at night | ✅ | `test_stands_close_at_night` |
| Rain: people look for shelter | ✅ | `test_rain_sends_people_to_shelter` |
| Frozen pond in winter, ducks stand on the ice | ✅ | `test_frozen_pond_in_winter` |
| Street lamps at night | ✅ | `test_lamps_light_up_at_night` |
| Sad smileys above sad characters | ⬜ | joy 10, wait 12 s, check a "sad" emote on the rig |
| Storm: lightning and thunder | ⬜ | Weather STORM, wait, check `env._flash > 0` once |
| Night animals: owl, hedgehog, fox appear; squirrels hide | ⬜ | 23:00, wait, check `inside`/`visible` of eulalia, stachel, fridolin |
| Seasonal decorations (snowmen, pumpkins) | ⬜ | Visual: `scripts/web_test.sh winter`; or check group visibility `season_3` |
| Weather changes over time | ⬜ | Short `weather_minutes_left`, check `weather_changed` |

## 10a. Nordwald — `nordwald.gd`

The forest north of the park (plan and phases: `doc/nordwald.md`).

| Feature | Status | Test / how to test |
|---|---|---|
| Walk from the park through the Waldtor to the lumber camp | ✅ | `test_walk_through_waldtor_to_lumber_camp` (tap-to-walk pathfinding) |
| Paths to the forest pond and the quarry | ✅ | `test_walk_to_quarry_and_pond` |
| The dwarves' mountain and the outer fence block walking | ✅ | `test_mountain_and_fence_block` (walks north with the keys) |
| Map opens on the view the player is in; tap on the forest map walks there; switch to the city park | ✅ | `test_forest_gate_open_and_map_view` |
| Visitors and park animals stay out of the Nordwald (random trees, nearest tree from the park side, two game hours) | ✅ | `test_visitors_stay_in_park`; the simulation also checks it (`visitor_in_forest`) |
| Buildings: lumber camp, sawmill, Waldschänke, Zwergenkontor, mine with rails and carts, Stellwerk, quarry walls | ⬜ | Visual: `scripts/web_test.sh forest_overview forest_camp forest_inn forest_sawmill forest_dwarves forest_night` |

## 10b. Bag and storage chest — `bag.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Bag opens with I and with the HUD button "Rucksack", closes with I; slots shown | ✅ | `test_open_with_key_and_button` |
| Tap a tile → details; "Essen" eats from the bag | ✅ | `test_eat_from_bag` |
| "Wegwerfen" | ✅ | `test_throw_away` |
| 12 slots, stacks per item; full bag takes nothing and says so; dwarf bag gives 18 | ✅ | `test_bag_full` |
| Storage chest at the lumber camp: move stacks in and out | ✅ | `test_storage_chest` (walks up, Action, taps tiles) |
| Each character keeps their own bag | ✅ | `test_own_bag_per_character` |
| Bag and chest are saved | ✅ | `test_bag_saved` |
| Item icons and layout on all screens | ✅ | `layout::test_bag_and_chest`; screenshots `bag`, `bag_touch`, `hud_items` |
| Item registry matches food effects; slot arithmetic | ✅ | unit `test_items.gd` |

## 10c. Gathering — `gathering.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Fell a forest tree: needs an axe (prompt says so), chop animation with the axe, logs and twigs, stump left | ✅ | `test_fell_tree_with_axe` |
| Better tools are faster (dwarf axe vs stone axe) and give more | ✅ | `test_better_axe_is_faster` |
| Walking away stops the work | ✅ | `test_walking_away_stops_work` |
| Felled trees grow back after two days | ✅ | `test_tree_regrows` |
| Mine quarry boulders with a pickaxe; ore and gems by luck and tier | ✅ | `test_mine_rock_and_luck` |
| By hand: twigs, field stones, berries, ceps, apples | ✅ | `test_gather_by_hand` |
| Fishing: cast, too early loses it, a bite, reel in | ✅ | `test_fishing` |
| Secret cherry trees in the city park: no hint without an axe, cherry wood | ✅ | `test_secret_cherry_tree` |
| Full bag and too tired stop work | ✅ | `test_full_bag_and_tired` |
| Felled/picked state is saved | ✅ | `test_gather_state_saved` |
| Spots look right (berries, apples, boulders) | ⬜ | Visual: `scripts/web_test.sh gather_glade gather_orchard gather_quarry` |

## 10d. Crafting — `crafting.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Workbench: recipes with have/need, disabled while something is missing, makes the stone axe | ✅ | `test_workbench_stone_axe` |
| Campfire: grilled trout, mushroom pan | ✅ | `test_campfire_cooking` |
| The whole loop: twigs and stones by hand → stone axe → fell a tree → board | ✅ | `test_first_axe_loop` |
| No room for the result → nothing is used up | ✅ | `test_no_room_for_result` |
| Screens on all screen sizes | ✅ | `layout::test_workbench_and_campfire`, `layout::test_gathering_prompt`; screenshot `craft` |

## 10e. People of the Nordwald, traders, dwarf jobs — `forest_people.gd`

| Feature | Status | Test / how to test |
|---|---|---|
| Sawmill buys wood ("Alles verkaufen" and single items) at the item value | ✅ | `test_sawmill_buys_wood` |
| Lumber camp sells the stone axe into the bag | ✅ | `test_buy_axe_at_lumber_camp` |
| Farm shop buys food and goods, the dwarves buy stone, ore and gems | ✅ | `test_farm_shop_and_dwarf_office` |
| Offering the dwarves a stone gnome | ✅ | `test_gnome_insult` |
| Waldschänke: hot meal, room for the night (sleeps to sunrise) | ✅ | `test_inn_meal_and_room` |
| Campfire logs: rest faster and cheer up | ✅ | `test_campfire_rest` |
| Grimbart's job (logs and stones → iron pickaxe), notebook entry, then the master test | ✅ | `test_dwarf_quest_props_gives_iron_pickaxe` |
| Brakka (recipe), Nori (dwarf axe), Thrain (dwarf bag after the switchman game) | ✅ | `test_dwarf_quests_rewards` (Thrain's score set directly; the game itself in `mg_forest`) |
| Gold ring at dwarves with a job | ✅ | `test_quest_ring_on_dwarves` |
| Forest people come by the forest gates, the Waldtor or out of the mine, work and stay in the forest | ✅ | `test_forest_people_live_in_the_forest`; forest stands open on time after a night: `shops::test_stands_open_after_a_night` |
| Forest people and dwarves look right | ⬜ | Visual: `scripts/web_test.sh people_forest people_dwarves forest_farmshop` |

## 11. NPC life (observable)

Mostly covered by the half-day simulation in `scripts/test.sh` (statistics + invariants, see below).

| Feature | Status | Test / how to test |
|---|---|---|
| NPCs buy food at open stands and eat | ⬜ | Hungry NPC near an open stand, check `HumanBrain.current.kind == "eat"` and its hunger falls |
| NPCs feed ducks, ducks swim to the bread | ⬜ | Gertrud at the pier, check `world.foods` and ducks' state "food" |
| Ducks follow a player carrying ≥ 3 bread | ⬜ | Buy bread, stand at the shore, check a duck's state "beg" |
| Goose hisses at humans within 3 m | ⬜ | Stand next to Gustav, check `last_said == "Zisch!"` |
| Mice flee from a running human | ⬜ | Run past a mouse, check its state "flee"/"hide" |
| Dogs on the leash follow their owner | ✅ | `quests::test_dog_walk` (the player's dog follows) |
| Talk: "Plaudern", "Streicheln", "Anschauen", "Brot zuwerfen" | ⬜ | Talk to a human / dog / pigeon / duck, choose the option, check joy and NPC animation |
| NPC greetings and sad/hungry lines | ⬜ | Set NPC joy 10, talk, check `dialog_text()` |

## 12. Simulation and invariants — `scripts/test.sh`

Half a day at 6× speed with a fixed seed (`seed=1`): same seed, same result. It prints
statistics (`TEST STATS`, `TEST STUCK`) and fails on any invariant violation
(`TEST INVARIANT`, checked every 2 game seconds in `DevOptions._invariants_loop`):

| Invariant | Status |
|---|---|
| Money never negative | ✅ |
| Positions finite (no NaN) | ✅ |
| Hunger, fatigue, joy within 0–100 | ✅ |
| Nobody outside the park (+20 m) unless at home | ✅ |
| Park people stay in the park, forest people in the Nordwald (`World.allowed`) | ✅ |
| No human in the water (bridges, pier and stones are fine) | ✅ |
| Seat and occupant agree; no seat shared | ✅ |
| Vendors at their stands during working hours | ⬜ (needs a tolerance for short breaks) |
| A leashed dog is in exactly one leash list | ⬜ (bug class fixed in `Actor.attach_leash`) |

## 13. Visual checks (browser screenshots, no input)

`scripts/web_test.sh <preset>` (presets in `tests/web/shots.cjs`) only takes screenshots; it does
not click or type. Use it for layout, placement and looks: title, overview, pond, food stands,
night, winter, touch layout (`sit_touch`), minigame views, map, notebook, character line-ups.

## 14. UI layout on desktop, phone and tablet — `layout.gd`

Every test puts the game into a state (HUD, prompt, dialog, quest, screen, minigame) and calls
`shot(label, targets)`, which runs `check_layout` on three window sizes (desktop 1280×720,
phone 844×390, tablet 1024×768), each with keyboard and touch controls:

- every panel, button, label and bar lies fully on screen (scroll areas clip their rows),
- no two of them overlap (a dark full-screen shade hides everything below it),
- the targets (the player's head, the NPC in the dialog, minigame objects) are on screen and not
  under any UI box,
- speech bubbles of characters in the picture are not under a UI box (toasts excepted, they
  fade after 4 s).

`scripts/web_test.sh scenario:layout` runs the same file in a phone-sized browser (844×390 CSS
px, touch, pixel ratio 2) and saves a screenshot at every `shot()` to
`build/screenshots/layout/<label>.png`; look at them with the Read tool (~20 min, software
rendering).

| Feature | Status | Test / how to test |
|---|---|---|
| HUD while walking (panels, menu buttons, joystick, round buttons) | ✅ | `test_hud_walking` |
| Prompt and inventory line; the gnome stays visible | ✅ | `test_hud_with_prompt_and_inventory` |
| Toasts and achievement popup: right column, left of the touch buttons, never off screen | ✅ | `test_toasts_and_achievement` |
| Quest dialogs (Mia, Pierre, Lena, troll riddle): player and NPC visible above the dialog | ✅ | `test_quest_dialog_mia`, `test_quest_mime_and_lena`, `test_quest_troll_riddle_at_night` |
| Dog walk running: toast, notebook with the quest | ✅ | `test_quest_dog_walk_running` |
| Shop menu | ✅ | `test_shop_menu` |
| On a bench (touch: Spezial) | ✅ | `test_on_bench` |
| Map, notebook, pause, settings, switch menu | ✅ | `test_screens_map_tasks_pause_switch` |
| Title and starter choice | ✅ | `test_title_and_starter` |
| All eight minigames: panel, buttons, game objects visible | ✅ | `test_mg_*` |
| Achievement during a minigame sits below the minigame panel | ✅ | `test_achievement_during_minigame` |
| Portrait phone (web) | ⬜ | Not supported by the layout (Android is landscape only); add a portrait screen to `SCREENS` if needed |

## Bugs found by the scenario tests

Fixed together with the tests (Oct 2026):

- 6th toast within ~4 s froze the game and ate all memory (`UI.toast` loop with `queue_free`).
- M / J / Esc opened and immediately closed map, notebook and pause menu.
- Clicking a place on the map: the mouse release walked to the 3D point behind the map.
- Empty deposit machine took the focus from "Pfandjagd starten".
- Mia put the player's dog for the dog walk back on her own leash; dogs could hang on two leashes;
  switching characters never cancelled the walk.
- Stands stayed open all night (vendors never stopped working).
- Second photo game with Peggy could never end (shots not reset).
- A quit and restarted minigame could be ended by the previous game's delayed result.
- Tapping an unreachable point caused a script error (`actor.emote_text`).

Found by the layout tests (`layout.gd`, Oct 2026):

- Touch mode: toasts covered the round buttons (Aktion, Spezial, Rennen) and the zoom buttons.
- Four or five two-line toasts reached below the screen and over an open dialog.
- An achievement during a minigame covered the minigame's panel (score, info).
- Pfandjagd: "Beenden" lay on the clock, the game panel on the character panel.
- The action prompt stayed visible under dialogs; it showed "[E]" after switching to touch.
- Touch buttons stayed on screen (and over the switch menu) while a dialog or screen was open.
- Short answers (troll riddle) were stacked: the dialog covered the player.
- Minigame hosts' speech bubbles (Hütchen-Harry) sat under the minigame panel; with the camera
  taken over, host lines now appear in the panel (`Minigame.host_say`).
- The running quest was the last row in the notebook, below all minigames (off screen on phones).
- A vendor who was strolling at the start of the working hours opened the stand only afterwards.

Found by `shops::test_stands_open_after_a_night` (Oct 2026):

- Stands opened up to 2.5 game hours late: vendors arrived at a random gate when the work began
  (walking is ~66 m per game hour). They now come early by their way from the gate near the stand.
- After a skipped night, Kemal was still "walking home" from 23:00 at 06:00.
- With the snack machines open at night, a hungry vendor walked 130 m to a machine right before work.
- Minigame hosts picked a new activity during their game (e.g. Hütchen-Harry performed and talked
  in a speech bubble under the game panel); hosts now stay put while their game runs.
