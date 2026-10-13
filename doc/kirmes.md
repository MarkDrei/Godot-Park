# Kirmes: plan for the western extension

The world grows to the west by the size of the city park: the **Westpark**, a second park with
a permanent **Kirmes** (funfair) in it. West of the Nordwald there is nothing (forest backdrop,
not walkable). This document is the plan, refined from the owner's first ideas (knowledge vault,
"Bank frei! – Kirmes: Stand der Ausarbeitung", 2026-10-11), and the checklist for the phases.
Update it when a phase ships or a decision changes.

## Decisions (from the owner)

- Extension to the **west**, as big as the city park: x from −390 to −130, z from −90 to +90.
  West of the Nordwald (x < −130, z < −90) nothing: backdrop forest.
- A **park with a Kirmes**, lively and joyful, with many things to discover.
- **Permanent**, not an event. **No main entrance, no entry fee**: the park's Westtor opens onto a
  meadow and the fair begins after a few steps.
- Booths spread evenly with lots of space between them; **many benches and small oases of rest**
  (benches, fountain, string lights, quiet music) where fatigue drops faster.
- **Ferris wheel** as the landmark in the middle, with a view over the whole map.
- **No nausea** from rides or food. **Joy rises most here**; hunger can be stilled.
- **Tickets** as a second currency, redeemed only for useful things (rare crafting items, tools,
  upgrades). No cuddly toys, decoration or other prizes that only fill the bag.
- **Stamp card** (Stempelpass): every booth and ride tried once.
- An **arcade** (Spielhalle) with simple machines; more complex little games come later. High
  score per machine, played with coins. No claw machine.
- Rides: Ferris wheel, bumper cars, carousel, chain swing, swing boat, a funny ghost train, a
  small roller coaster.
- Booth games (many over time): whack-a-mole, can throwing, duck fishing, ring toss, high
  striker, balloon darts, wheel of fortune / lottery tickets; later: basketball, hot wire, water
  race, marble horse race, guess the weight, memory.
- Food: candy floss, roasted almonds, bratwurst, crêpes.
- Figures and secrets: the **fortune teller** (one cryptic hint per visit about real secrets of
  the map), the **fair ghost** (at night in the ghost train, looks for something lost), the
  **magician** (mental arithmetic tricks to play along; the only multi-stage quest).
- Quests are straight (one step), except the magician's.
- Not wanted: claw machine, toys and decoration as prizes, candy-floss recipe quest, string-light
  quest, duck parade, photo for the couple, fair marathon.
- Areas: the Westpark is its own area (`"fair"`, arc42 §8.8): with "Bereiche: Getrennt" the
  Westtor asks, and only the player's area is awake. Built on demand like the Oststadt.

## Refinements (this plan)

- **Name**: the area is the *Westpark*, the fair in it *die Kirmes*. Gate question: "Willst du
  zur Kirmes?"
- **Coins and tickets**: rides and games cost coins (0,50–2,00 €), games pay out **tickets**
  (not money). Tickets are a counter like money (shown in the HUD next to the money while in the
  Westpark and in the bag). The **prize counter** ("Gewinnausgabe") trades tickets for: ore,
  gems, cherry wood, honey, the iron axe and pickaxe, the fishing rod, and the biggest prize, the
  **Bauchladen** (vendor's tray: +6 bag slots, stacks with the dwarf bag).
- **Oases**: five rest spots (fountain garden, pond shore, lime grove, rose arbour, the bench ring
  under the Ferris wheel) with their own little sign; sitting there rests 2× faster, quiet music
  plays. Visiting all five: achievement.
- **Joy**: everybody's joy rises 1.5× in the Westpark; rides give a big joy boost.
- **Stamp card**: shown in the notebook (tasks screen) as a grid of stamps.
- **Arcade machines** (phase 5), each a 2D game in a cabinet screen: *Schlangenfraß* (snake),
  *Astro-Abwehr* (shoot falling meteors), *Ziegelbrecher* (breakout). High-score table per
  machine with the fair people's scores to beat (Highscore-König: first place on all three).
- **Rides** are short experiences: pay, sit in, the camera rides along, joy and a stamp; the
  Ferris wheel stops at the top for the view over the whole map. Bumper cars are a small game
  (bump the other cars for points).
- **People of the Westpark** live there (`"fair": true`) and never visit the city park; park
  people don't go there either. Showmen come by the west road; visitors and children stroll,
  eat, ride and cheer.

## Map

```
x = -390                                                                       x = -130
z = -90 ┌──────────────────── forest backdrop (not walkable) ──────────────────────────┐
        │ Achterbahn            Geisterbahn          Spielhalle      Gewinn-   │ Teich    │
        │ (coaster)                                  (arcade)        ausgabe   │ (pond,   │
        │                                                                      │  oasis)  │
        │ Autoscooter      ┌── Festplatz ──┐   Budengasse: booths on both sides  │          │
        │ (bumper cars)    │  Riesenrad    │ ═════════════════════════════════════ Westtor │
        │                  └───────────────┘                                   │ meadow   │
        │ Kettenkarussell     Karussell       Schiffschaukel   Schlemmergasse  │ Lichter- │
        │                                                     (food, tables)  │ garten   │
        │ Wahrsagerin (tent among trees)              Zauberbühne (magician)   │ (oasis)  │
z = 90  └───────────────────── south road (city) ─────────────────────────────────────────┘
```

All data in `FairLayout` (places, paths, plazas, rides, booths); `FairMap` writes heights,
water, paths and ground kinds of the Westpark cells into the `ParkMap` when it loads;
`FairBuilder` builds the meshes; `Fair` (runtime) animates the rides and owns the fair's things.
Until it loads, the park sees a cheap `FairBackdrop` (meadow, trees, Ferris wheel, tents).

## Phases

Each phase ships on its own with scenario tests and rows in `doc/test-scenarios.md`.

1. ✅ **Map and area**: world bounds to the west (grid 780 × 360), the Westpark built on demand
   (`World.load_fair`, loading screen), terrain, pond, paths, trees, the fence and the Westtor
   as the crossing, all rides and buildings as animated scenery (the Ferris wheel turns), booths
   and food stands as scenery, benches, lamps and string lights, the oases, area `"fair"` in
   `AreaGates`/`World` (split: the Westtor asks), the backdrop from the park, map view
   "Westpark".
2. ✅ **People and food**: the showmen, visitors and children of the Westpark, the food stands
   (candy floss, almonds, bratwurst, crêpes), oases rest faster, joy rises faster, fair music.
3. ✅ **Rides and stamp card**: the seven rides as experiences (bumper cars as a game), stamp card.
4. ✅ **Booths and tickets**: whack-a-mole, can throwing, duck fishing, ring toss, high striker,
   balloon darts, wheel of fortune; tickets, prize counter.
5. ✅ **Arcade**: the arcade hall with three machines and high scores.
6. ✅ **Figures, quests and secrets**: fortune teller, magician (tricks and his story), fair ghost,
   the lost teddy, the tired showman, the hunger delivery from the park; easter eggs (golden
   duck, golden mole, special gondola, the bench scene, the lottery man's third line, the
   arcade's retro code); achievements.

## Shipped

- Phase 1: `FairLayout`, `FairMap`, `FairBuilder`, `FairModels`, `Fair`, `FairBackdrop`; area
  `"fair"` in `World`/`AreaGates`; map view "Westpark".
- Phase 2: `Cast.FAIR` (four food vendors, eight booth hosts and ride operators, Spielhallen-Sascha,
  Madame Esmeralda, the great Zambini) plus 12 visitors and 6 children (`Cast.fair_visitor`,
  `fair_kid`), spawned when the Westpark loads; their posts are `Fair.posts` ("fair:<id>"
  spots, `Perform.exact`); they come and go by the Westpforte and the Südpforte. Food stands
  `fair_candy`, `fair_almonds`, `fair_sausage`, `fair_crepes`. Oasis seats rest 2× faster
  (`Seat.oasis`), joy rises at the Kirmes (`Needs.FAIR_JOY`, `FAIR_ENJOY`), the organ waltz
  (`Sound.fair_music_level`). Achievements Oasen-Entdecker and Zuckerschock 2.0.
- Phase 3: `Ride` (a `Minigame`: pay, ride along with the camera, joy, stamp) with `FerrisRide`
  (stop at the top with the view), `CarouselRide`, `ChainRide`, `SwingRide`, `GhostRide` (a dark
  inside built only for the ride, five frights), `CoasterRide` (one lap) and `BumperCars` (a
  minute of bumping, `bumper_best`). The rides take over their part of `Fair` (`ride_wheel`,
  `ride_boat`, `ride_ghost`, `player_scooter`, `coaster_board`). `FairPass`: the stamp card (16
  stamps, notebook entry), ride counters. Open 10:00–24:00; the wheel, the bumper cars and the
  ghost train need their operator. Achievements Karussell-Profi and Stempelpass voll.
- Phase 4: `BoothGame` (a `Minigame` at a booth: counter, camera over the shoulder, tickets,
  stamp; `pace` slows markers for tests) with `CanThrow`, `DuckFishing`, `RingToss`,
  `BalloonDarts`, `WhackAMole`, `WheelOfFortune`, `HighStriker`. Tickets are `GameState.tickets`
  (HUD, bag screen, save). `FairTrade`: Los-Lothar's lottery tickets and the prize counter
  (honey, ore, cherry wood, duck horn, fishing rod, gem, iron axe and pickaxe, the Bauchladen:
  +6 bag slots). Achievements Maulwurf-Jäger, Dosenkönig, Hauptgewinn, Goldener Maulwurf (hidden).
- Polish after play-testing: the booth hosts step out of the booth during a game
  (`BoothGame.host_spot`); Ringwurf has its bottles on a stepped table; Hau den Maulwurf has
  six holes in two staggered rows and a close camera; the coaster runs on a smooth spline
  (station → lift hill), with eased speed and a bar that follows the track, and the rider is
  off it afterwards; the bumper car is a `Car` (kind `"scooter"`, `Car.arena`) driven with the
  Oststadt's controls (`PlayerController.enter_car`); booths, benches and the south gate path
  no longer stand on or run through paths and rides.
- Looks: painted wooden stalls (`FairModels._stall`: board walls, framed counter panels,
  barber-pole posts, a curved canvas awning with a fluttering scalloped valance, a sign board with
  a crest, gold frames and bulbs, pennants, emblems or price boards on the sides) and a topper on
  every roof that shows what the booth is about; the fair shaders (`fair.gdshader`: boards,
  canvas, lacquer and metal; `fair_lights.gdshader`: chasing bulbs and steady lamps) on all
  rides and halls; more detail on the rides (wheel braces and hub star, the carousel's rounding
  board with mirrors, the chain swing's striped roof, the swing boats' crests, the coaster's tent
  station and footings), the ghost train (battlements, sign, gravestones, a pumpkin), the bumper
  hall's sign, the arcade (light panels, posters, marquee) and the magic stage.
- Phase 5: `ArcadeGame` (a `Minigame` at a cabinet: a 240 × 180 "pixel" screen drawn into a
  panel, touch buttons, a high-score table with the fair people's scores in
  `ArcadeGame.TABLE`, tickets by score) with `SnakeMachine` (Schlangenfraß), `AstroMachine`
  (Astro-Abwehr) and `BricksMachine` (Ziegelbrecher) at the back of the arcade hall. Achievement
  Highscore-König (first place on all three).
- Phase 6: `FairStories`: Madame Esmeralda's daily hint (the first secret not found yet, from
  gnomes to the arcade's back room), Zambini's four tricks (binary cards, 1089, always four,
  guess the number) and his story "Der verschwundene Assistent" (Hoppel the rabbit: Esmeralda →
  the ghost train → Geister-Gustav → a carrot trail → the rose arbour → back to Zambini; the
  twist: he never vanished him on purpose), Gisbert the fair ghost (22–3 h, his pocket watch at
  the top of the Ferris wheel), Lia's teddy, the hunger delivery for Muskel-Max (hot dog and
  fries to go from the city park, warm within six game hours), and `AlmondShift` (the tired
  showman: serve eight customers). Easter eggs: the golden duck (a new place every day), the
  golden gondola, the rose arbour's flock of birds (ten sits), Los-Lothar's third line, the
  retro code on the machines, the back room for the Highscore-König. Nine new achievements
  (five of them hidden).

Still open from the first ideas: the quests with other areas (ingredients from a garden, fish
for a grill, a spare part from the crafting area, a visitor by boat) wait for those areas; the
Retro Racer machine in the back room comes with the more complex arcade games.
