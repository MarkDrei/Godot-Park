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

## People (phase 4; the anonymous visitors and the gulls come in phase 1)

All live at the coast (`"coast": true`) and stay there.

| Who | Role | Post |
|---|---|---|
| Bootsverleiher Ole | boat rental, pedal-boat race host | jetty |
| Fischerin Gesche | the fishing cutter, sells fresh fish, buys what you catch | quay |
| Leuchtturmwärter Hinnerk | the lighthouse, sea stories, lighthouse climb | lighthouse |
| Rettungsschwimmerin Svenja | lifeguard tower, swimming flags | tower |
| Fischbrötchen-Uwe | Fischbude | promenade |
| Eis-Giulia | Eisdiele | promenade |
| Strandbar-Piet | Strandbar, Beachvolleyball host | beach |
| Kiosk-Inge | Kiosk (beach toys), Flaschenpost hints | promenade |
| Strandkorb-Wiebke | rents Strandkörbe | beach |
| Opa Fietje | sandcastle master | Sandburgenplatz |
| Kapellmeister Bruno? (open) | concerts in the Kurmuschel | Kurmuschel |
| Visitors | bathers, walkers, children with buckets; families on the beach | |
| Animals | gulls (playable like the ravens: hop, short flight), seals on the sandbank, crabs on the beach | |

## Fishing, beach stands, food (phase 2)

- **Angeln** with the existing rod (`fishing_rod`) at the pier head, the mole, the groynes and from
  a rowing boat: sea fish Hering, Makrele, Scholle, Dorsch, rarely a Hummer. A short timing
  game (bite → "Zieh!"). Fish sell at Gesche's cutter and the Fischbude; Räucher-Fiete at the
  castle buys them too.
- **Sammeln** on the beach: Muscheln (shells) and rarely Bernstein (amber), regrowing after a
  day. Kiosk-Inge buys amber; shells for a Muschelkette (crafting, phase 2).
- Stands: Fischbude (Fischbrötchen, Backfisch), Eisdiele (Spaghettieis, Softeis), Strandbar
  (Limo, Kokosmilch), Kiosk (Eimer und Schaufel, Sonnenhut, Flaschenpost-Papier), Strandkorb rental.

## Minigames and attractions (phase 3)

| Game | Host | How it plays |
|---|---|---|
| Tretbootrennen | Ole | a buoy course in the bay against two pedal boats |
| Steine flitschen | at the groyne | angle and strength, count the skips |
| Sandburg bauen | Opa Fietje | stack bucket after bucket in time; the tide comes |
| Beachvolleyball | Piet | bump the ball when it is in the ring, two against two |
| Möwenalarm | Uwe | protect the fish rolls from diving gulls |
| Angelwettbewerb | Gesche | the most fish in two minutes at the pier head |
| Leuchtturm | Hinnerk | climb and look over the coast (camera ride) |
| Robben-Foto | Hinnerk | row to the sandbank and take a photo of the seals |

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
2. Fishing, gathering, stands and food.
3. Minigames and attractions.
4. People, quests, stories, achievements. Voices later, when there are credits.
