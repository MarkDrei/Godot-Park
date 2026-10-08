# Nordwald: plan for the northern extension

The park doubles in size to the north. The old park stays the tidy city park; the new half is
the **Nordwald**, a wilder forest with a lumber camp, a quarry at the dwarves' mountain, and a
gathering, crafting and trading loop. This document is the agreed plan (brainstormed with the
owner, 2026-10-08) and the checklist for the phases. Update it when a phase ships or a decision
changes.

## Decisions (from the owner)

- Extension to the **north**: world z from −270 to +90 (park −90..+90 unchanged).
- **Inventory belongs to each character** (`Actor.inventory`), as today.
- Trees can be felled **only in the Nordwald**, plus a few **secret trees in the city park**.
  These are not highlighted (no ring, no hint); with an axe in the bag the prompt appears next to
  them. They regrow, like the forest trees.
- **Tools never break.** Better tools work faster; the best ones are dwarf quest rewards.
- **Park visitors never enter the Nordwald.** It has its own NPCs; only the dwarves (and the
  forester, see below) give quests.
- **No observation tower, no building sites.** "Building" means crafting things at the workbench
  and the campfire: tools, food, and goods to sell.
- **Minigames**: axe throwing, wood chopping, and one with the dwarves (switchman at the mine
  railway, see below).
- **The mountain**: a small hill at the north edge with the quarry at its foot, dwarves, and a
  mine railway whose carts disappear into the mountain. The mountain itself cannot be entered.

## Map

```
z = -270  ┌──────────────────── mountain (beyond the edge, not walkable) ─────────────────┐
          │  fir forest (felling)        forest pond     │ quarry  ⛏  mine portal ═══╗    │
          │  ▲ ▲ ▲ ▲  ▲ ▲ ▲              ~~~~~           │ dwarf office, rails, carts  │    │
          │  ▲ ▲  lumber camp            berries, mushrooms   switch tower (minigame)   │
 forest   │  ▲  workbench, campfire, axe target, chopping block                         │
 gate (W) │       sawmill (buys wood)        forest inn "Waldschänke"     orchard, bees │
          │                                  (food, rooms, terrace)                     │
z = -90   └─────────────────────────────── Waldtor (old Nordtor) ──────────────────────┘
                                   city park (unchanged)
```

Rough positions (x, z), to be tuned with screenshots:

| Place | Position | Notes |
|---|---|---|
| Waldtor | (0, −90) | Old Nordtor; fence between park and forest, gate open |
| Forest gate (outside) | (−130, −200) | Where Nordwald NPCs arrive; not used by park visitors |
| Lumber camp | (−40, −160) | Workbench, campfire, chopping block, axe-throwing target, storage chest, hammock |
| Sawmill | (−70, −135) | Buys wood and boards |
| Felling forest | x < −50, z < −120 | Dense firs and pines, every tree fellable |
| Forest inn "Waldschänke" | (25, −150) | Hot meals, rooms to sleep, terrace |
| Forest pond | (−45, −225) | Fishing, fed by a small brook from the mountain |
| Berry hedges, mushroom glade | scattered, e.g. (0, −200) | Gathering without tools |
| Orchard and beekeeper | (95, −140) | Apples; honey via the beekeeper |
| Quarry | (60, −230) | Rock faces, boulders to mine |
| Dwarf mountain and mine portal | (75, −262), edge | Rails from the quarry into the portal |
| Dwarf office "Zwergenkontor" | (35, −240) | Buys stone, ore, gems; dwarf quests |
| Switch tower | (90, −235) | Dwarf minigame |

## Resources

| Item | Source | Tool |
|---|---|---|
| Twigs (Äste) | lying around in the forest | none |
| Logs (Holzscheite) | felling trees (stump regrows in ~2 game days) | axe |
| Cherry wood (Kirschholz) | the secret trees in the city park; sells high | axe |
| Stone (Stein) | rocks in the quarry (respawn daily) | pickaxe |
| Ore (Erzbrocken) | sometimes when mining | pickaxe |
| Gem (Edelstein) | rarely when mining; dwarves love them | pickaxe |
| Berries, mushrooms, herbs, apples | bushes, glade, orchard (daily, mushrooms best after rain) | none |
| Fish | forest pond, short timing game | fishing rod |
| Honey | beekeeper | none |

Gathering: hold the action button; a short bar fills, a well-timed tap (rhythm of the chops)
makes it faster. Each action costs a bit of fatigue and adds hunger, so the needs loop matters.
Tool tier sets the speed: tier 1 crafted, tier 2 bought or crafted from ore, tier 3 from dwarf
quests.

## Inventory

- Per character, saved with the actor (already the case).
- Bag screen ("Rucksack"): grid of slots, categories food / materials / tools / quest items,
  item icon, name and count; actions: eat, drop. Touch friendly.
- Limited slots (e.g. 12, stacks up to 20); a bigger bag (18 slots) from a dwarf quest or the
  workbench.
- Storage chest at the lumber camp, shared, for surplus.
- The HUD line stays as a compact summary.

## Crafting

At the **workbench** (lumber camp):
- Logs → boards; stone → stone slabs
- Tools: stone axe and stone pickaxe (twigs + stone), fishing rod (twigs + ...), iron axe and
  iron pickaxe (boards + ore), bigger bag
- Goods to sell: birdhouse, carved figure, stone garden gnome (the dwarves hate it — a gag)

At the **campfire**: grilled fish, mushroom pan, berry jam, baked apple. Home-made food fills
more than vending machine snacks.

## Trading

- **Sawmill**: buys logs, boards, cherry wood.
- **Zwergenkontor**: buys stone, ore, gems; sells the stone pickaxe.
- **Farm shop / market stall** at the Waldtor: buys crafted goods and food (better prices than
  raw materials).
- Lumber camp: sells the stone axe, fishing rod.

## Rest and food

- Waldschänke: hot meals, a room for the night (sleep anywhere in the forest at night without
  going home), terrace benches.
- Hammock at the lumber camp: free, slower recovery.
- Sitting at the campfire recovers fatigue faster and raises joy.

## Minigames

1. **Axe throwing** (lumber camp): target with rings, wind, five throws, aim + power like boule.
2. **Wood chopping** (lumber camp): rhythm duel against the lumberjack, split as many logs as
   possible in 30 s; gives logs.
3. **Switchman** (dwarves): carts roll out of the mountain; flip the switches so ore carts go to
   the smelter and rock carts to the dump. Gets faster; dwarves pay per correct cart.

## NPCs

- Dwarves (3–4, quest givers): e.g. Grimbart (foreman), Brakka (cook), Nori (gem expert),
  Thrain (switchman).
- Forester (Försterin): explains felling, sapling quest (plant a sapling for every felled tree).
- Without quests: lumberjack (axe-throwing / chopping host, sells tools), sawmill worker, inn
  keeper, beekeeper, a hiker and a mushroom collector who wander the forest.
- Forest animals: deer at the edge of the forest at dawn, a fox, woodpeckers (later).

## Dwarf quests (draft)

1. **Pit props** (Grimbart): 6 logs + 6 stone → iron pickaxe.
2. **Dwarf hunger** (Brakka): mushroom pan + berry jam → dwarf recipes for the campfire.
3. **Lost gem** (Nori): find a gem in the quarry / bring 3 gems → dwarf axe (tier 3).
4. **Night shift** (Thrain): win the switchman game on hard → dwarf bag (bigger inventory) and
   the title "Ehrenzwerg".

## Phases

Each phase ships on its own with scenario tests and rows in `doc/test-scenarios.md`.

1. ✅ **Map**: world bounds to the north, terrain, fence and Waldtor, forest, paths, pond, mountain
   backdrop, map screen (two views), visitors stay in the park, buildings as scenery
   (`ForestDecorator`, `ForestModels`). Load time 2.3 → 2.8 s natively.
2. ✅ **Inventory**: bag screen (I / "Rucksack"), 12 slots (18 with the dwarf bag), item registry
   `Items`, drawn icons `ItemIcons`, eat and throw away, storage chest at the lumber camp.
3. ✅ **Gathering** (`Gathering`): fellable trees with regrowth, quarry boulders, twigs and field
   stones, berries/ceps/apples, fishing, tool tiers, four secret cherry trees in the park.
   Gathering is one press of Action; the work runs by itself (hits per tier) and stops when the
   player walks away.
4. ✅ **Crafting** (`Crafting`, `CraftScreen`): workbench and campfire, 14 recipes. Honey for the
   baked apple comes with the beekeeper (phase 6).
5. **Trading and places**: sawmill, Zwergenkontor, farm shop, Waldschänke (food, room), hammock,
   campfire rest.
6. **NPCs and quests**: dwarves, forester, lumberjack and the others; dwarf quests and rewards.
7. **Minigames**: axe throwing, wood chopping, switchman.
