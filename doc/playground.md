# The playground in the city park

Owner's wish (2026-10-14): the playground grows to the fence and a bit wider, the path stays and
runs through it; more equipment that the player and people can use; three children with a quest
series; small games; digging in the sandbox finds something for another quest (with the troll).

## Area

- `ParkLayout.AREAS["playground"]`: x −55…−21, z 50…87, from the fountain path down to the hedge
  at the south fence. Ground "grass" with `keep_paths`: the ring path stays paved and runs right
  through (`ParkMap.compute_ground` skips path cells; `TerrainBuilder._under_ribbon` draws the
  cells under the path ribbon as the area's ground). Levelled as one flat region.
- Sand only under the equipment: `pg_sand_*` areas with `"flat": false` (not levelled on their
  own, the playground is). Trees keep off all areas; benches along paths too.
- A low picket fence (`PlaygroundModels.play_fence`) on the north, west and east sides, open where
  the paths come in; the park hedge closes the south. Five benches for the parents (not park
  benches for Bankdrücker), four shade trees, the sign "SPIELPLATZ" outside the north fence.

## Equipment (`Playground`, `src/world/playground.gd`)

Built by `ParkDecorator._playground`, kept as `World.playground`. Everything that doesn't move is
merged into one mesh (`PlaygroundStatic`); the moving parts are their own nodes.

| Thing | Use | How |
|---|---|---|
| Two swing sets (2 seats each) | sit: "Schaukeln" | seat kind `swing`, the pivot swings while used |
| Nest swing (2 places) | "In die Nestschaukel" | seat kind `nest` |
| Seesaw | "Wippen" | seat kind `seesaw`, the beam rocks |
| Carousel (4 places) | "Karussell fahren" | seat kind `carousel`, turns while used |
| Spring horse and spring duck | "Aufsitzen" | seat kind `spring`, rocks |
| Slide tower | "Rutschen" | motion: ladder up, slide down |
| Climbing net | "Klettern" | motion: up the net, cheer at the top, down the other side |
| Trampoline (in the ground) | "Hüpfen" | motion: six bounces |
| Balance beam and stumps | "Balancieren" | motion: along the beam, hop over the stumps |
| Big sandbox (digger, castle, buckets, water pump) | dig, treasure hunt | `SandDigGame`, people dig there |

- **Moving seats**: each seat has a carrier node (`Playground.riders`); every frame the rider is
  put on the seat, tilted with it (`_carry`). `Bench.verb` names the prompt, getting off is
  "Absteigen". `Actor.pose_anim()`: swing/nest → "swing", seesaw/carousel/spring → "ride".
- **Motions**: `Playground.use(actor, device)` runs scripted steps (`custom_motion`): only for an
  actor at the device's `start_point` and one at a time per device. New rig poses: climb, slide,
  bounce, balance, ride. A teleport ends a motion and gets off a moving seat.
- Achievement "Spielplatz-Profi": slide, climb, jump and balance once.

## People

- **Robin** (9, curly hair, always hungry), **Finja** (8, swings highest, wants a unicorn),
  **Mika** (7, collects toy cars): role "kid", `likes.play` 9, 9–19 h in the park.
- `Activities.Play` (all children): ride a seat kind, a device, dig in the sandbox or run about;
  a device in use is skipped.

## The gang's wishes (`PlaygroundQuests`)

One after the other; each child says where to find the thing (stat `pg_step`: kid i asks at 2i,
wish open at 2i+1, done at 2i+2; 6 = all three):

1. Robin wants an apple: Apfelwiese in the Oststadt or the Obstwiese in the Nordwald.
2. Finja wants a cuddly unicorn ("Stoff-Einhorn"): the Kirmes's prize counter, 12 tickets
   (Lose at Los-Lothar or the booths). Sascha has exactly one cuddly toy because the children
   kept asking.
3. Mika wants a toy car: the drive-in's "Kindermenü (mit Spielzeugauto)" (4,50 €, only from a
   car). One toy car per order, only when the bag has none.

Afterwards they tell of a treasure in the sandbox where a troll once played. Achievement
"Spielplatzbande".

## Games

- **Schaukel-Duell mit Finja** (`SwingGame`, spot north of the first swing set): 25 s; push when
  the swing turns at the top (|sin phase| ≥ 0.8) for height, pushing in the middle brakes. Finja
  reaches 78–90 %. Achievement "Bis in den Himmel" at 100 %.
- **Trampolin mit Robin** (`TrampolineGame`, spot east of the trampoline): 20 s; push off within
  0.2 s of landing (or just after) to go 0.45 m higher, else sink; height × 10 points per jump,
  somersault from 2.4 m (+15). Robin has 110–150 points.
- **Schatzsuche mit Mika** (`SandDigGame`, free roam, spot south of the sandbox): the sandbox is
  5 × 4 cells, three things buried, eight tries; dig where you stand (Aktion); Mika says
  heiß / warm / kalt. While Bruno's key has not been found, it is one of the three.

## Bruno's chest

- The **rusty key** with a troll's face from the sandbox. Bruno (under the Steinbrücke, at
  night) knows it: he buried it as a little troll 300 years ago; his chest stands on the bank by
  the bridge (`PlaygroundQuests.chest_pos`). The key opens it: 15 € troll gold and his crown.
  Bring him the crown: achievement "König Bruno" (stat `troll_chest` 0…3).
