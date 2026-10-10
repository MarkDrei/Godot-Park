# Oststadt: plan for the eastern extension

The world grows to the east by the size of the city park and the Nordwald together: the
**Oststadt**, a small, flat town where you can drive cars. This document is the agreed plan
(owner, 2026-10-10) and the checklist for the phases. Update it when a phase ships or a
decision changes.

## Decisions (from the owner)

- Extension to the **east**: world x from −130 to +390 (park and Nordwald unchanged), z from
  −270 to +90 like today.
- **Driving**: you can get into **any standing car**. Nobody can run over pedestrians and the
  player can't be run over: people jump aside, cars brake on their own, other cars keep their
  distance. Bumping into walls or cars is soft (no damage).
- **Low houses** (2–3 floors) so the camera never hangs behind high-rises. Single landmarks
  (church tower, crane, cinema screen) may be higher when they stand alone.
- **No fatigue in a car.** Hunger and joy go on as usual.
- **Two drive-ins**: the drive-in burger "Zum Durchfahrer" and the drive-in cinema.
- **Twelve minigames**: taxi, tow truck, delivery, parking, driving school, car wash, petrol
  station, kart track, ice cream van, garbage collection, scrapyard crane, oldtimer rally.
- Not wanted: police patrol, flea market, tyre change, bus driver, the abandoned-car easter egg.
- **Ten residents** (see below). The policewoman has no minigame.
- **Loader**: the town is built only when the player comes close to it (a loading screen, as at
  the start). Phones and the web don't pay for it until then.

## Map

```
x = 130 (fence)                                                             x = 390
z = -270 ┌──────────────────────── warehouses (north fringe) ─────────────────────────┐
         │ ══════════════ Waldrandstraße (z = -240) ══════════════════════════════ │
Nordwald │ Autokino        │ Kartbahn        │ Schrottplatz    │ Betriebshof       │
         │ ══ Forststraße (z = -160), Waldweg Ost gate at x = 130 ════════════════ │
         │ Tankstelle +    │ Werkstatt       │ Fahrschule +    │ houses            │
         │ Waschstraße     │ (tow truck)     │ Übungsplatz     │                   │
z = -90  │ ══════════════ Nordstraße (z = -90) ═══════════════════════════════════ │
         │ Drive-in burger │ Marktplatz,     │ church, houses  │ houses            │
Stadt-   │                 │ taxi stand      │                 │                   │
park     │ ══ Parkallee (z = -12), Osttor of the park at x = 130 ═════════════════ │
         │ Taxi-Zentrale   │ houses (Tempo   │ Gelateria,      │ houses            │
         │ houses          │ 30)             │ houses          │                   │
         │ ══════════════ Südring (z = 60) ═══════════════════════════════════════ │
z = 90   └──────────────── row houses, Opa Egon's garage (south fringe) ────────────┘
           Parkstraße        Hauptstraße       Lindenstraße      Ostring
           (x = 141)         (x = 210)         (x = 280)         (x = 350)
```

- Streets form a closed grid (no dead ends): 4 north–south streets, 5 east–west streets, 20
  crossings. Road 12 m (two 3.5 m lanes, 2.5 m parking strips), sidewalks 3 m. Right-hand
  traffic. Crosswalks on every arm of a crossing, traffic lights at the main crossings.
- Blocks between the sidewalks: columns x [150, 201], [219, 271], [289, 341], [359, 390];
  rows z [−270, −249], [−231, −169], [−151, −99], [−81, −21], [−3, 51], [69, 90].
- All data in `CityLayout` (streets, blocks, lots, places, houses); `CityMap` writes ground kinds,
  obstacles and roof heights into `ParkMap` (new ground kinds street, sidewalk, crossing, lot);
  `CityBuilder` builds the meshes.

## Driving

- `Car` (kinematic, like actors): arcade bicycle model, keyboard WASD, touch joystick plus
  "Gas" / "Bremse" buttons, gamepad stick and triggers. Action gets out (when slow), Special honks.
- Cars only drive on streets, crossings and lots (curbs stop them); the park is car-free, a car
  stops at the fence.
- Safety: every car looks ahead along its path; with an actor in the way it brakes so that it
  always stops in time. Pedestrians in front of a moving car jump aside. Actors can't walk into
  cars. Bumps bounce the car back softly.
- Camera further back and higher while driving; it rises over roofs instead of hiding behind them.
- `Needs`: state "drive" keeps fatigue where it is.

## Residents

| id | Name | Role |
|---|---|---|
| tanja | Taxi-Tanja | taxi company, host of the taxi job |
| kurt | Meister Kurt | garage, host of the tow truck job |
| toni | Tankwart Toni | petrol station shop, petrol game and car wash |
| bodo | Burger-Bodo | drive-in cook, delivery job |
| karla | Kino-Karla | drive-in cinema (evenings) |
| friedrich | Fahrlehrer Friedrich | parking game and driving test |
| siggi | Schrott-Siggi | scrapyard, car parts, crane game |
| gianni | Eismann Gianni | ice cream van |
| petra | Polizistin Petra | patrols on foot, comments on red lights |
| egon | Opa Egon | oldtimer rally |

Plus generic passers-by (taxi fares) and children (ice cream van). Traders: petrol station shop,
car parts at the scrapyard (horns with funny sounds), the drive-in's walk-up counter. The
kart track and the garbage depot have no host.

## Phases

Each phase ships on its own with scenario tests and rows in `doc/test-scenarios.md`.

1. ✅ **Map, loader, driving, drive-ins**: world bounds to the east, `CityLayout`/`CityMap`/
   `CityBuilder`, low houses, all lots as scenery, loader, parked cars to get into, driving,
   safety, camera, the drive-in burger and the drive-in cinema, map views.
2. ✅ **Traffic and residents**: lane graph, traffic lights, AI cars, the ten residents and the
   passers-by, the three traders.
3. ✅ **Taxi, tow truck, parking, petrol station.**
4. **Driving school, car wash, delivery, kart track, ice cream van, garbage collection, crane,
   oldtimer rally**, achievements.
