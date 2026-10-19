# Ritterburg: plan for the fourth area

North of the Westpark and west of the Nordwald (x −390..−130, z −270..−90, until now "no world")
stands the **Ritterburg** on a hill that rises into the mountain, with a **medieval market**
along the way up and a **tournament ground** in front of the walls. This document is the plan,
refined from the owner's ideas (knowledge vault, "Bank frei! – Ritterburg mit Mittelaltermarkt",
2026-10-19), and the checklist for the phases. Update it when a phase ships or a decision changes.

## Decisions (from the owner)

- Casual, good vibes, small challenges; minigames and achievements as in the rest of the game.
- To the north the area runs into the mountain; it is entered from the **south** (Westpark) and
  the **east** (Nordwald). Four levels, bottom to top: tournament ground, ascent with market
  paths, inner square, knights' exhibition. Torches in the evening.
- **Normal money**, no special currency (no tickets).
- Tournament: jousting, sword fights, archery, ring tilting, **tug of war** against a knight,
  **betting** on the fighters. **Horses only in the tournament** (owner, 2026-10-19): knights
  joust on horseback as a show, the player rides only in the joust and ring-tilting minigames;
  outside the horses stand in a paddock and can be petted. They are not playable characters.
- Behind the outer wall the way rises ~7 m, at least two paths (west and east) with traders and
  booths and small medieval games.
- Traders and figures: **herb witch and alchemist** brew potions from ingredients you bring,
  **smithy** (works the dwarves' ore), dice games, market crier, beggar with riddle stories.
- **Potions** can't be bought: you bring the ingredients and pay only the brewing (~1 €). Effects
  last 8 game hours: *Lauftrank* (walk and run 50 % faster without getting tired),
  *Kräutertrank* (double herbs when picking), *Abbautrank* (ore and trees twice as fast).
  Potions sell for ~8 €.
- Ingredients: herbs and berries from the edge of the castle area, the city park, mostly the
  Nordwald, a little from the Kirmes. A mix from several areas.
- Food: suckling pig, flatbread, honey cake, stew in a bread loaf, smoked fish. **No mead.**
  Tavern with benches outside; a campfire to rest and cook (like the Nordwald).
- Inner square: juggler (juggling, fire breathing, song) taking turns with a **minstrel** with a
  lute, **puppet theatre**, a **magician** in a darker corner (mysterious, not the arithmetic
  magician of the Kirmes). A second wall leads up.
- Top: **knights' exhibition**, **lookout tower** (view over the map), **secret passage** to the
  dwarves: in at the castle, out at the mine. Done as a **fade to black** with a short text
  (owner, 2026-10-19).
- Animals: **falcons and ravens**, playable; as the player they hop and take a **short flight**
  with the action key (owner, 2026-10-19).
- **Castle ghost**, linked with the Kirmes ghost Gisbert: a quest makes the two meet, across both
  areas.
- A new magician **story** linked to Zambini and Esmeralda; both get adjusted.
- New performers and spectators, voiced like the others.
- Loading: its own area (`"burg"`); on phones it loads on its own ("Bereiche: Getrennt"), on PCs
  it is added when the player comes near ("Alles"), as the other areas.
- Not wanted: herald, crossbow and axe throwing, armourer, rune seer, falconer, finger pulling
  and barrel rolling, coat-of-arms stand, travelling trader, mead, armour hall, library,
  dungeon, castle dragon.
- Ship in phases, each live (owner, 2026-10-19). This doc stays in the repo only.

## Map

```
x = -390                                                                         x = -130
z = -270 ┌─────────────────────────── mountain (backdrop, not walkable) ──────────────────┐
         │  Kräuterhang        ┌──── 4: Ritterausstellung (~9 m) ────┐   Rabenfels       │
         │  (herbs, west)      │ Geheimgang  Ausstellungshalle  Turm │                   │
         │                     └──────────── inneres Tor ────────────┘                   │
         │                     ┌──── 3: Innenplatz (7 m) ────────────┐                   │
         │                     │ Magier (dark corner)  Gaukler/Bühne │   Hagebutten-     │
         │                     │ Puppentheater        Spielmann      │   hecken (east)   │
         │                     └─────────────────────────────────────┘                   ├ Waldweg
         │   west path ↗  Kräuterhexe  Taverne      Alchemist  Schmiede  ↖ east path      │
         │   2: Marktpfade (0 → 7 m)  Würfel  Marktschreier  Bettler  Lagerfeuer        │
         │   ═══════════════ outer wall ═══ Torhaus ═══ outer wall ═══════════════      │
         │  Koppel+Stall   Tribüne    ════ Turnierbahn (joust) ════   Tribüne   Bogen-   │
         │  (horses)       Ringstechen    Schwertkampfring  Wettbude  Tauziehen  stand   │
z = -90  └───────────────────────── Burgpforte (Westpark, between ghost train and arcade) ┘
```

| Place | Where (x, z) | Level / height |
|---|---|---|
| Burgpforte (gate from the Westpark) | (−260, −90) | 0 m |
| Waldweg (gate from the Nordwald, the forest's west gate; its people now come and go right inside it) | (−130, −200) | 0 m |
| Turnierbahn (joust lists, 70 × 14 m, east–west) | (−285, −118) | 0 m |
| Tribünen (stands) north and south of the lists | (−285, −104 / −132) | 0 m |
| Koppel and Stall (paddock, stable) | (−365, −115) | 0 m |
| Schwertkampfring + Wettbude (sword ring, betting booth) | (−215, −110) | 0 m |
| Tauziehen (tug-of-war pitch) | (−185, −135) | 0 m |
| Bogenstand (archery range, shooting north-east) | (−160, −110) | 0 m |
| Torhaus (gate house in the outer wall) | (−265, −152) | 0 m |
| West path / east path up | (−320, −175) / (−210, −175) | 0 → 7 m |
| Kräuterhexe / Alchemist | (−318, −185) / (−212, −186) | 3–4 m |
| Schmiede (smithy) | (−200, −165) | 1 m |
| Taverne (tavern with outdoor benches) | (−300, −165) | 1 m |
| Market stalls, dice, crier, beggar, campfire | along both paths | 1–6 m |
| Innenplatz (inner square, round, r 22 m) | (−265, −212) | 7 m |
| Magierecke (magician's corner) | (−289, −224) | 7 m |
| Inneres Tor (second wall) | (−265, −236) | 7 m |
| Ritterausstellung (exhibition hall) | (−282, −252) | 9 m |
| Aussichtsturm (lookout tower) | (−238, −252) | 9 m |
| Geheimgang (secret passage door) | (−305, −258) | 9 m |
| Kräuterhang / Hagebuttenhecken (herbs at the edges) | x < −345 / x > −185, z −150..−250 | slopes |

The hill: heights are set by the map writer (flat levels, ramps along the paths); the walls,
rock faces and steps between the levels are meshes with obstacles in front (the heightfield has
no slope limit). The mine's other end is the portal in the Nordwald (74, −254).

## People

All live in the castle area (`"burg": true`) and never leave it.

| Who | Role | Post |
|---|---|---|
| Ritter Kunibert von Klappenstein | jousting champion (red), tug-of-war opponent | lists, tug pitch |
| Ritterin Adelheid vom Ahornhain | jousting knight (blue), archery master | lists, archery range |
| Ritter Eckhard der Eiserne | sword fighter (show fights) | sword ring |
| Knappe Till | squire: sword fights against Eckhard, ring tilting host | sword ring |
| Stallmeisterin Jolanda | horses, paddock, the joust minigame's host | stable |
| Wettmeister Gernot | betting booth | sword ring |
| Kräuterhexe Walburga | brews Lauftrank and Kräutertrank | west path |
| Magister Quirin | alchemist, brews Abbautrank, a little vain | east path |
| Schmiedin Brunhild | smithy, works ore | smithy |
| Wirtin Gertrud | tavern: stew in bread, flatbread | tavern |
| Spanferkel-Sepp | suckling pig | market |
| Bäckerin Mechthild | honey cake | market |
| Räucher-Fiete | smoked fish | market |
| Würfel-Fritz | dice games | market |
| Marktschreier Hannes | shouts the market's news (and hints) | market |
| Lumpen-Ludwig | beggar with riddle stories | by the gate house |
| Funken-Jo | juggler, fire breather (turns with the minstrel) | inner square stage |
| Spielmann Wendelin | minstrel with a lute | inner square stage |
| Puppenspielerin Liesel | puppet theatre | inner square |
| Meister Morwen | the mysterious magician | magician's corner |
| Kastellanin Ottilie | runs the exhibition and the tower | exhibition |
| Spectators | Familie Rittersporn (Gunther, Irmela, little Kasimir), Oma Hiltrud (cheers at every joust), plus generated visitors and kids who watch the shows | |
| Animals | falcons Fenja and Falko, ravens Rabe Rudolf and Krah-Liese (playable), four horses (Blitz, Donner, Hafer, Wolke; tournament only) | |
| Burggespenst | Fräulein Hedwig, the castle ghost (at night on the battlements; not a Cast person, like Gisbert) | |

## Herbs, berries and potions

New gathering spots (by hand, like the berries; regrow after 24 game hours):

| Item | German | Where |
|---|---|---|
| chamomile | Kamille | city park meadows (Große Wiese, Picknickwiese) |
| elder | Holunderbeeren | city park hedges, castle slopes |
| woodruff | Waldmeister | Nordwald, under the trees |
| wild_garlic | Bärlauch | Nordwald, along the brook |
| berries (exists) | Waldbeeren | Nordwald, Beerenlichtung |
| lavender | Lavendel | Kirmes: Rosenlaube, Lichtergarten |
| st_johns_wort | Johanniskraut | castle: Kräuterhang (west) |
| rose_hip | Hagebutten | castle: hedges east of the wall |

| Potion | Brewed by | Ingredients | Effect (8 game hours) |
|---|---|---|---|
| Lauftrank | Walburga | Waldmeister 2, Kamille 2, Waldbeeren 2 | walk and run +50 %, no fatigue from walking/running |
| Kräutertrank | Walburga | Johanniskraut 2, Bärlauch 2, Holunderbeeren 2 | herbs and berries ×2 when picking |
| Abbautrank | Quirin | Hagebutten 2, Lavendel 2, Erzbrocken 1 | felling and mining twice as fast |

Brewing costs 1 €, a potion sells for 8 €. Drinking from the bag ("Trinken"); the HUD shows the
running potion and the hours left. A second potion of the same kind extends it to 8 h again.

**Smithy** (Brunhild, station "Schmiede", pays with ore): Hufeisen (ore 1), Geisterlaterne
(ore 2 + Brett 1, for the ghost story), the iron axe and pickaxe (as at the workbench, plus a
hot forge: no board needed, ore 3), and the repair of the magician's staff (story).

## Minigames

| Game | Host | How it plays | Pays |
|---|---|---|---|
| Tjost (joust) | Jolanda | on horseback down the lists against a knight: keep the lance on the shield (aim) and hit at the right moment (timing); three runs | 2–6 € |
| Ringstechen (ring tilting) | Till | ride past five rings, take them with the lance by timing | 0,50 € per ring |
| Bogenschießen (archery) | Adelheid | aim and draw, wind from the flag, five arrows at a target | 0,20–1 € per arrow |
| Tauziehen (tug of war) | Kunibert | tap in rhythm with the drum; pull the knight over the line | 3 € |
| Schwertkampf-Wette (bet) | Gernot | bet 1–5 € on Eckhard or Till, watch the show fight; odds by their form | stake × odds |
| Würfelspiel | Würfel-Fritz | "Hoch hinaus": roll three dice, keep or re-roll once, beat Fritz | 1 € stake |
| Kristallkugel | Morwen | remember the order of the lights in the crystal ball (memory, grows by one) | 1 € per round, story |
| Aussichtsturm | Ottilie | climb, look over the whole map (camera ride, like the Ferris wheel) | – |

Shows (no game): joust between Kunibert and Adelheid (on the hour, 11–18), sword fights,
juggler/minstrel, puppet theatre (Kasper und der Raubritter).

## Stories and quests

### Der Sternenstab (the magician's story, multi-step)

Meister Morwen once was a real magician. Long ago he had an apprentice: young **Zambini**, who
preferred honest arithmetic tricks and left for the Kirmes after a quarrel. Morwen's sister
**Esmeralda** went with him and became the fortune teller. Since then Morwen's star staff has
lost its light: a splinter of the star is missing. Twist: the splinter got into Zambini's top
hat when he left – that is why Hoppel really vanished once (Kirmes story "Der verschwundene
Assistent": "Wie, weiß ich bis heute nicht …").

1. Morwen's crystal ball game; afterwards he speaks of "einem Lehrling, der lieber rechnete als
   zauberte" and his staff without light.
2. Zambini (Kirmes) gets nervous, denies; "Frag die Wahrsagerin, die weiß, wer ich mal war."
3. Esmeralda tells that Morwen is her brother; her hint: "Was einst verschwand, kam aus dem Hut."
4. Zambini lets you look into his hat (needs "Der verschwundene Assistent" done, otherwise he
   sends you to find Hoppel first): the **Sternensplitter**.
5. Schmiedin Brunhild sets the splinter into the staff (ore 2 + gem 1).
6. Morwen's staff glows; he writes a letter of reconciliation. Bring it to Zambini.
7. Zambini reads it; at his next show a real dove flies out of the hat. Esmeralda's last hint
   changes ("Zwei Brüder im Geiste …"). Reward: 20 €, Morwen teaches a "real" trick: his
   crystal ball now pays double, achievement *Zwei Zauberer*.

### Zwei Gespenster (Hedwig and Gisbert, multi-step)

Fräulein Hedwig haunts the castle's battlements at night (22–3 h) and is bored: nobody stays up
for her. Gisbert at the Kirmes ("Grüß die Wahrsagerin von mir") is lonely too.

1. Meet Hedwig at night; she has heard of "einem Herrn Gespenst mit Taschenuhr" (needs the
   Kirmes story "ghost" done, otherwise she waits).
2. Gisbert sends a greeting; Hedwig answers with a riddle verse – carry three messages back and
   forth (each only at night).
3. Ghosts can't leave their place: Brunhild forges the **Geisterlaterne**; Hedwig rides in it.
4. Carry the lantern (on foot through the Burgpforte) to the Ferris wheel at midnight; ride up:
   the two meet at the top. From then on, on clear nights, both float over the Kirmes and the
   battlements now and then; Hedwig reveals the **Geheimgang** if not yet found. Achievement
   *Geisterstunde zu zweit*.

### Single quests

| Quest | Giver | Asks | Reward |
|---|---|---|---|
| Ein Eisen für Blitz | Jolanda | a horseshoe from the smithy | 4 €, a free joust |
| Erz für die Esse | Brunhild | 5 ore from the dwarves' quarry | 8 €, forge recipes cheaper |
| Fisch für die Taverne | Gertrud | 3 trout from the Nordwald pond | 6 € and a stew in bread |
| Die heisere Stimme | Hannes | Waldhonig against his hoarse voice | 5 €, his next shout is a hint |
| Kasper ist weg | Liesel | her Kasper puppet, last seen at the Kirmes (a child there swapped it) | 6 €, a private show |
| Kräuterkunde | Walburga | one of each herb of the castle (Johanniskraut, Hagebutten) – teaches herbs | first potion's brewing free |
| Lumpen-Ludwigs Rätsel | Ludwig | three riddle stories, one per day (answer from three options) | 2 € each, last: a hint to the passage |

The fortune teller gets hints for the castle's secrets; the market crier shouts news.

## Achievements (new)

| Title | For |
|---|---|
| Turniersieger | win a joust |
| Ringmeister | all five rings in one ride |
| Ins Schwarze | three bullseyes in one archery round |
| Stärker als ein Ritter | win the tug of war |
| Glückliches Händchen | win three bets |
| Würfelglück | beat Würfel-Fritz five times |
| Kräuterkundig | pick every herb and berry once |
| Braumeister | brew all three potions |
| Turmblick | climb the lookout tower |
| Burggeschichte | read every board in the exhibition |
| Durch den Berg | use the secret passage |
| Rätselfreund | solve all of Ludwig's riddles |
| Zwei Zauberer | finish "Der Sternenstab" |
| Geisterstunde zu zweit | finish "Zwei Gespenster" (hidden) |

## Phases

Phase 1 shipped 2026-10-20 (see arc42 §5.2d, tests `burg.gd`). Changes against the plan: the
Nordwald's gate is the existing Waldweg at z −200 (the trail along the hedges leads down to
the tournament ground); the stalls face the nearest path; the bread stall became the tavern's
flatbread; Wirtin Gertrud and Spanferkel-Sepp have the ids `wirtin` and `ferkelsepp` (the park
has a Gertrud and the Nordwald a Sepp). Not yet: the castle's people are silent (phase 5), the
food is not sold yet (phase 2), the horses are only in the paddock (phase 3).

1. **Area**: the fourth area in all area code (bounds in `Area`, gates on any border and between
   any two areas, navigation, map, baked map, backdrops, loading, split); terrain with levels,
   walls, gate house, tower, buildings and booths as meshes; paths; the tournament ground; the
   Westpark's north fence gets the Burgpforte, the Nordwald's west gate becomes the Burgweg
   (forest people come in elsewhere); people with posts and spectators; animals (falcons and
   ravens with the short flight, horses in the paddock); torches at night; the secret passage
   (fade); map labels; tests.
2. **Herbs and potions**: herb spots in all areas, items and icons, Walburga and Quirin brew,
   potion effects (HUD, save), the smithy; tests.
3. **Games**: joust and ring tilting (horses), archery, tug of war, betting, dice, crystal ball,
   lookout tower, the shows; tests.
4. **Stories and quests**: Sternenstab, Zwei Gespenster, single quests, Esmeralda's and Zambini's
   changes, exhibition boards, achievements; tests.
5. **Voices**: all new lines (castle people, changed Kirmes lines); tests.
