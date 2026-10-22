# Möwenbucht: plan for the fifth area

South of the city park (x −130..130, z 90..270, until now a street and city houses) the world
runs into the **sea**: the **Möwenbucht**, a small seaside resort with a promenade, dunes, a
sand beach, a pier, a harbour with a lighthouse and a bay to go out on in a **pedal boat** or a
**rowing boat**. As big as the city park. This document is the plan and the checklist for the
phases. Update it when a phase ships or a decision changes.

## Decisions (from the owner, 2026-10-22)

- **Sea**, not a lake: sand beach, dunes, pier, lighthouse on a mole, waves, the horizon to the
  south. Boats go out in the bay; a line of buoys marks how far.
- Boats: **Tretboot** (pedal boat, a swan) and **Ruderboot** (rowing boat). No motor boat, no
  sail boat.
- Access: **only the Südtor of the city park**. Its own area (`"coast"`), loaded on its own on
  phones ("Bereiche: Getrennt") and added when the player comes near on PCs, like the others.
- Fishing, beach stands, minigames and small attractions as in the other areas; normal money.
- **No voices yet** (the ElevenLabs credits are almost used up). Lines are written so they can
  be voiced later.
- Ship in phases, each live.

## Map

```
x = -130                                   x = 0                                     x = 130
z = 90  ┌──────── park fence (hedge) ─────── Südtor ──────── park fence ───────────────────────┐
        │ Kurmuschel   Fischbude  Eisdiele  Vorplatz  Kiosk   Souvenirs        Bootsverleih   │
z = 108 │ ═════════════════════ Strandpromenade (paved, benches, lamps) ═══════════════════  │
        │  Piratenschiff-   ░░ dunes ░░ ┃boardwalk┃ ░░ dunes ░░ ┃boardwalk┃ ░░ dunes ░░  Hafen │
        │  Spielplatz       ░░░░░░░░░░░ ┃         ┃ ░░░░░░░░░░░ ┃         ┃ ░░░░░░░  (quay) │
z = 135 │ Felsen   Volleyball  Strandkörbe   ┃ Seebrücke   Strandkörbe  Sandburgen  ┃jetty┃ M │
        │ (rocks)        Rettungsturm        ┃ (pier)      Strandbar               ┃boats┃ o │
z ~170  │ ╲ rocky   ~~~~~ shore (surf) ~~~~~~┃~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   basin   l │
        │  point      Buhne                  ┃                 Buhne                       e │
        │    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ┃ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ╲_______╱ │
        │      Sandbank (seals)              ┃                               Leuchtturm      │
z = 245 │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~ Brückenkopf (pavilion, landing) ~~~~~~~~~~~~~~~~~~~~~~ │
z = 262 │ o ─ o ─ o ─ o ─ o ─ o ─ o ─ o  buoys: the boats' limit ─ o ─ o ─ o ─ o ─ o ─ o ─ o  │
z = 270 └──────────────────────────── the open sea to the horizon ──────────────────────────┘
```

| Place | Where (x, z) | Notes |
|---|---|---|
| Südtor (the park's south gate, now the gate to the coast) | (0, 90) | visitors still arrive here |
| Vorplatz (round, r 6 m) | (0, 100) | sign "MÖWENBUCHT", info board, bicycles |
| Strandpromenade (main path, 5 m, east–west) | z ≈ 108, x −124..124 | benches facing the sea, lamps |
| Kurmuschel (music shell) | (−82, 99) | benches in rows (phase 3: concerts) |
| Fischbude / Eisdiele / Kiosk / Souvenirs | (−44, 99) / (−22, 99) / (24, 99) / (48, 99) | stands (phase 2) |
| Dunes with beach grass, sand fences | z 112..135 | up to 2.5 m high |
| Boardwalks over the dunes (wooden decks) | x −60, 0, 50 | |
| Piratenschiff-Spielplatz | (−98, 124) | a wooden pirate ship to climb |
| Beach (sand) | z 135..shore | Strandkörbe in rows (seats) |
| Beachvolleyball court | (−52, 148) | phase 3 |
| Rettungsturm (lifeguard tower) | (−22, 160) | |
| Strandbar | (24, 142) | phase 2 |
| Sandburgenplatz | (58, 152) | phase 3 |
| Seebrücke (pier, 4 m wide, 1.6 m above the water) | x 0, z 138..238 | piles, lamps, benches |
| Brückenkopf (pier head: pavilion, landing steps, telescope) | (0, 244) | |
| Felsen (rocky point, west) | x < −96, z 140..205 | rock, not walkable |
| Buhnen (wooden groynes into the sea) | x −64 and 36 | |
| Hafen (quay, paved) | (96, 140) | Bootsverleih, Fischkutter |
| Bootssteg (jetty with the boats) | from the quay (96, 147) south to (96, 178) | pedal and rowing boats moored |
| Mole (stone breakwater, walkable) | (124, 140) south to (124, 214), west to (100, 228) | |
| Leuchtturm (red and white) | (96, 230) | phase 3: climb it |
| Sandbank with seals | (−58, 226) | reachable by boat |
| Buoys | z 262 and x ±124 | where the boats must turn |

Shore line: a bay, deepest in the middle (z ≈ 176 at x 0, ≈ 166 at the sides). The beach falls
from 1 m at the dunes' foot to the water; the sea floor sinks to 3 m below the surface 30 m out.
The sea plane goes on to the horizon (also in front of the Westpark's and the Oststadt's south
edge, which become a seaside town and a cliff). Waves and a strip of surf along the shore.

## Boats (phase 1)

- Cars of their own kinds (`CarSpecs`: `pedalo` "Tretboot", `rowboat` "Ruderboot", `water`):
  driven like the cars (gas, steer; on touch the pedals and the stick), only on water inside the
  buoys and away from the pier, the mole, the jetty and the sandbank. Slow (pedal boat ~2.5 m/s,
  rowing boat ~3 m/s), they glide on and turn slowly; they bob on the waves; no engine sound,
  splashes.
- They lie at the jetty in the harbour: east of it six side by side with the stern to the planks
  and the bow out into the basin (gas takes them straight out), west of it two along it.
  Getting in from the jetty (or the beach) like a car ("Einsteigen: Tretboot"); getting out only
  where there is land or a deck within reach: on open water there is no "Aussteigen", pressing
  it says "Hier ist kein Land. Fahr an einen Steg oder an den Strand, um auszusteigen."
- The rowing boat shows the oars moving, the pedal boat its paddle wheel.
- Phase 1: free to use. Later the Bootsverleih asks a fee (phase 4: Bootsverleiher Ole).

## People (the vendors and hosts since phase 2; quests and stories in phase 4)

All live at the coast (`"coast": true`) and stay there.

| Who | Role | Post |
|---|---|---|
| Bootsverleiher Ole | boat rental, pedal-boat race host | jetty |
| Fischerin Gesche | the fishing cutter, sells fresh fish, buys what you catch | quay |
| Leuchtturmwärter Hinnerk | the lighthouse, sea stories, lighthouse climb | lighthouse |
| Rettungsschwimmerin Svenja | lifeguard tower, swimming flags | tower |
| Souvenir-Sönke | Souvenirs: buys shells and amber | promenade |
| Fischbrötchen-Uwe | Fischbude | promenade |
| Eis-Giulia | Eisdiele | promenade |
| Strandbar-Piet | Strandbar, Beachvolleyball host | beach |
| Kiosk-Inge | Kiosk (beach toys), Flaschenpost hints | promenade |
| Opa Fietje | sandcastle master | Sandburgenplatz |
| Kapellmeister Klaus | sea shanties on the guitar in the Kurmuschel (15–20 h) | Kurmuschel |
| Visitors | bathers, walkers, children with buckets; families on the beach | |
| Animals | gulls (playable like the ravens: hop, short flight), seals on the sandbank, crabs on the beach | |

## Fishing, beach stands, food (phase 2, done)

- **Angeln** with a rod (`fishing_rod`, also at the Strandkiosk; the **Brandungsangel**
  `sea_rod`, tier 2, at Gesche's cutter: bites come sooner) at nine places (`CoastSpots.FISHING`):
  four on the pier head, three on the mole, two on the quay; and from a **rowing boat** lying
  still on the water ("Angeln" while sitting, `BoatFishing`). As in the Nordwald: wait for the
  bite (the prompt turns to "Biss! Schnell einholen!", "!" over the head, a splash), then
  "Aktion" within 1.6 s; too early costs the try. What bites depends on the place
  (`Gathering.CATCH`): pier and mole herring, mackerel, plaice, cod, rarely a lobster, now and
  then an old boot; the harbour more herring and boots; the boat the bay's plaice and cod, the
  best chance of a lobster.
- **Sammeln** on the beach: "Muscheln sammeln" at shell spots along the water's edge (two shells,
  12 % a piece of amber), regrowing after a day.
- **Stands** (vendors in brackets): Fischbude (Uwe: Fischbrötchen, Backfisch, Limonade; buys
  herring and mackerel), Eisdiele (Giulia, Gianni's cousin: Spaghettieis, Softeis, Eis),
  Strandkiosk (Inge: water, lemonade, chocolate, rods), Souvenirs (Sönke: sells Muschelketten,
  buys shells, amber and chains), Strandbar (Piet: Kokos-Shake, lemonade, cola, milkshake;
  stools at the counter), Fischkutter "Möwe" (Gesche at the quay: buys every fish, a lobster for
  15 €; sells the surf rod). Räucher-Fiete at the castle takes sea fish too.
- The coast's people are in the cast from phase 2 on (`Cast.COAST`), the hosts at their posts.

## Minigames and attractions (phase 3)

Shipped in two parts (the retro of the castle's games: not eight at once). Part 1 (done):

| Game | Host | How it plays | Pays |
|---|---|---|---|
| Tretbootrennen | Ole (at the boat rental) | in a pedal boat against two others round the yellow buoys 1, 2, 3 (the next one glows green and has the light pillar; touching it within 6 m counts, a buoy out of turn counts nothing) and back between the two flags; a countdown 3-2-1-LOS | 3 € for the win, 1 € second; 1 € stake |
| Steine flitschen | nobody (beach, x −30) | a gauge at the side shows the throwing angle, the needle swinging from flat to steep; "Werfen!" when it is in the green (flat, the zone lights up and "JETZT!" shows, the reaction included): five to seven skips, the bright middle eight to ten, yellow two to four, red (steep) "Plopp! Zu steil"; every skip a splash ring and its number in big; three stones, the best counts | – |
| Leuchtturm | Hinnerk | up to the gallery, once round the bay | 0,50 € |
| Münzfernrohr | – (pier head) | half a minute through the telescope: a narrow round view, ◀ ▶ ▲ ▼ (or the stick) turn it, "Fertig" | 0,20 € |

Part 2 (done):

| Game | Host | How it plays | Pays |
|---|---|---|---|
| Sandburg bauen | Opa Fietje (sandcastles) | a bucket swings above the castle; while it is right above, the ring on the castle glows green and "JETZT!" shows (a press now and a moment later still hits): "Stülpen!" adds a storey; beside it (up to 0.9 m) the top storey crumbles, far beside it nothing; the bucket swings a little faster with every storey; the tide (the bar, the surf coming up the sand) ends it after 45 s | joy; 8 storeys for the goal |
| Beachvolleyball | Strandbar-Piet | seen from the side; Piet plays the ball over, a ring in the sand shows where it lands and you run there by yourself; while it drops through the arms' reach it glows green with "JETZT!": "Baggern!" plays it back; too early "Zu früh!", not at all "Verpasst!" (points for Piet), while it is far away a press does nothing; Piet misses more often the longer a rally; first to 5 | 2 € for the win |
| Möwenalarm | Fischbrötchen-Uwe | three fish rolls on the counter; a gull diving at one shows a red ring with "!" over it; the button below ("Links", "Mitte", "Rechts" or A, S, D) shoos it ("Husch!"); a press where none comes costs nothing; an unguarded gull steals the roll ("Geklaut!"); 45 s, the gulls come faster | 1 € for two rolls, 3 € for all three |
| Angelwettbewerb | Fischerin Gesche | 90 s on the pier head with your own rod (as always: "Biss!", then Aktion), Gesche fishes beside you, her catches count in the panel; leaving the pier head ends it | 3 € for the win; 1 € stake |

The seals' photo goes to phase 4 (with the seals as animals and a quest).

Attractions: a coin telescope on the pier head (zoom view), concerts in the Kurmuschel, a message
in a bottle (secret), napping in a Strandkorb, the lighthouse beam at night.

Every game follows the `minigame-design` skill.

## Stories, quests, achievements (phase 4)

To be detailed when phase 3 is done (owner's ideas welcome): a message in a bottle that leads
across the areas, the lighthouse lamp (smithy at the castle), treasure on the sandbank; quests for
the stands; achievements for boats, fishing, the games.

## Phases

Status: phase 1 shipped (2026-10-22). The south of the city park (its street and the tall houses)
gave way to the bay; the houses south of the Westpark end at a cliff west of the bay, a little
harbour town lies east of it; the sea is on the horizon from every area.

1. **Walkable area** (done): grid rows for the coast, the area (CoastArea, CoastMap, CoastBuilder,
   Coast, CoastBackdrop), the Südtor as its gate, promenade, dunes, beach with Strandkörbe,
   pier, harbour with jetty and mole, lighthouse (model), rocks, groynes, sandbank, buoys, the sea
   to the horizon with surf, pedal and rowing boats to drive, gulls, visitors, the map.
2. Fishing, gathering, stands and food (done).
3. Minigames and attractions (done, in two parts).
4. People, quests, stories, achievements. Voices later, when there are credits.
