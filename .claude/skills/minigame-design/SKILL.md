---
name: minigame-design
description: Rules and checklist for designing, building and reviewing Bank frei! minigames (timing, aiming, riding, throwing, any game with a "press now" moment) so they are playable on a phone the first time. Use when adding a new minigame, changing a game's controls or rules, or when the owner says a game is confusing or hard to play.
---

# Designing minigames that are playable at once

The base class is `src/minigames/minigame.gd` (HUD panel, buttons, `set_info`, `set_score`,
`host_say`, `show_power`, `set_cue`, `look`). Read one finished game that follows these rules
before writing a new one: `burg_rings.gd` (timing), `burg_joust.gd` (aiming with a 2D overlay),
`burg_archery.gd` (aiming in 3D, follow camera). **Update this skill** when a game teaches you
something new, with the date.

## Why this skill exists (retro, 2026-10-22)

Phase 3 of the Ritterburg (commit ca8462b, 2026-10-19) shipped eight games in one commit with
green tests. The owner could not play Tjost and Ringstechen and found archery hard to follow:

| What the owner saw | Cause |
|---|---|
| Tjost: "I got points now and then, but no idea why" | The crosshair sat on Kunibert's shield 30–60 m away: on a phone it was **not visible at all** (the old screenshot shows no crosshair). The scoring zones were not drawn anywhere, and no result said which zone was hit. |
| Ringstechen: the lance goes up a bit, sometimes down, never reaches the ring | The lance was a hand item moved by the generic `throw` animation (arm swings up, then down), **unrelated to the hit test**, which was a hidden `tip_x` number. An early press **used up the next ring** without saying so. |
| Archery: the crosshair goes into or behind the target | The crosshair moved in a vertical plane, but the target face leans back by 0.12 rad. |
| Archery: the arrows are hard to see | A thin 8 mm hand-item arrow, 0.9 s flight, camera 8.5 m in front of the target: the arrow was on screen for the last ~0.2 s only. |

Root causes behind all four:
1. **The tests played with knowledge the player does not have.** They read `m.aim`, `m.tip_x()`
   and called `m.strike()` "in the very frame", so they passed while the screen showed nothing
   usable. Green tests said "the mechanics work", not "a person can play this".
2. **Screenshots were taken but only checked for layout** (overlaps, panels), not for "can I see
   what I need to decide, at the moment I have to decide it?". No screenshot showed the
   decision moment.
3. **Visuals were reused, not designed for the rule:** a hand item and a generic animation stood
   in for the lance, a plain plane for a tilted face. What the player sees was not what counts.
4. **Rules lived in the code and in one line of info text**, without the vocabulary the screen
   uses (no "gold middle = 3", no "green = now").
5. **Volume:** eight games at once, each tested for "can it be won", none played as a
   first-timer would play it.

## Rules

### 1. One sentence of rules, and the screen shows each word of it
- Write the rule as one or two sentences **before** coding: "When the ring glows green, press
  Stechen: the lance goes up and spears it." Put it in `set_info` and in `describe()`.
- Every noun in that sentence must be something you can point at on the screen (the ring,
  green, the lance). Every number must be visible where it applies (draw the zones with their
  points, like `ShieldAim` in `burg_joust.gd`).
- The host's first line says the same in their own words (`host_say`; it is voiced, see below).

### 2. What the player sees is what counts
- The visual that the player watches must be the hit test: the lance points where it will hit
  (`BurgHorseGame.point_lance`), the ring sits where the tip has to be, the crosshair lies on the
  real surface (`_on_target` follows the target's tilt). Compute the hit **from** that geometry,
  or the geometry from the hit, never two separate models.
- Do not use hand items with generic animations (`throw`, `ride`) for a game action. Hold the
  tool as a mesh the game positions every frame, and animate the action itself (thrust, lift).
- Things that must stay in front of a surface go along its normal (`target_normal() * 0.08`),
  tilted with it.

### 3. Big enough on a phone
- The phone is 844×390 CSS px (`web_test.sh scenario:<file>`). What the player must watch
  (target, crosshair, ring, ball) should be **at least ~40 px** on that screen, the moving
  marker at least ~25 px.
- If the thing to aim at is far away in 3D, show it as a **2D overlay** at the side of the
  screen (`ShieldAim`), and keep the 3D scene as the story.
- Move the camera so the action is seen **across** the view, not along it: a lance pointing
  away from a camera behind the rider is a dot (Ringstechen: camera from the side).
- Fast small things get thicker, brighter and slower: the flight arrow's shaft is 56 mm thick with glowing
  fletching and flies 1.6 s, and the camera follows it (`BurgArchery._follow`).

### 4. Tell the player when to act
- A timing game shows the moment: the target changes colour (gold → green) and a big word
  appears (`set_cue("JETZT!")`). The cue must already include the reaction delay: show it when
  a press **now** would hit (`reach_x()` adds the speed × lift time).
- A coming event gets a bar (`show_power`) until it happens (Tjost: until the riders meet).
- Windows: at least ~0.3 s at the game's speed (Ringstechen: ±0.8 m at 4.8 m/s). Lower speed
  before shrinking anything else.
- The first chance comes after a run-up of 3 s or more (time to read the panel).

### 5. Every press has a visible, fair result
- Each action gets feedback within ~0.2 s: an animation that matches the outcome (the ring
  stays on the lance; the arrow sticks where it hit) and a big cue (`"+3 Mitte!"`,
  `"Zu früh!"`, `"Verpasst!"`), plus the host's line.
- Results name the reason in the game's words: which zone, too early/too late, not pressed.
- A press far from any target **costs nothing**. Only a press close to a target and outside its
  window may lose it, and then the cue says so. Never consume the next target silently.
- One button, one meaning, always the same verb ("Stechen!", "Stoß!", "Schießen!").

### 6. The opponent's score is explained too
- If the opponent scores at random, show their points next to yours each round
  (`"Kunibert +1"`), so a loss is understandable.

### 7. Lessons from the Möwenbucht's games (2026-10-22)
- **Check where the camera is and looks in the first frame.** The telescope first looked north,
  back into the player's own face; the lighthouse's eye sat inside the lantern. A screenshot of
  the first second shows it at once; tests can check the view direction (`test_telescope`).
- **A target behind the player needs a pointer.** A light pillar alone does not help when the
  next buoy is behind the boat: an arrow at the edge of the screen that turns towards it, with
  its distance (`CoastBoatRace.TargetArrow`).
- **The UI font has no arrow symbols** (◀ ▶ ▲ ▼ come out as boxes): label buttons with words
  ("Links", "Rechts", "Hoch", "Runter").
- **Transparent water shows what lies under it**, also where the world ends: the deep sea is
  opaque, only the shallows let the sand show through.
- Ship games in small batches (the coast's came in two parts) and look at each one's phone shots.

## Testing a minigame

1. **Play with the player's knowledge.** The scenario test decides when to press from what the
   screen shows (the cue text, the ring's material, the overlay), and presses with real input
   (`press("interact")`). Calling the game's method in "the very frame" from internal state is
   allowed only as a second test for the scoring, never as the only test.
2. **Test the failure paths:** too early, too late, not pressed, a press far from any target
   (`test_ring_tilting_misses`).
3. **Screenshot the decision moment** and the result: `shot("<game>_now")` while the cue is
   up, `shot("<game>_hit")` right after. Natively, `shot()` takes game time (it resizes the
   window): freeze the game around it (`m.set_process(false)`, shot, `set_process(true)`).
4. **Look at the phone shots** (`scripts/web_test.sh scenario:<file>:<test>`, one test per
   call, ~1–5 min each; `build/screenshots/<file>/`) and answer for each:
   - Can I see the thing I have to watch, and is it at least ~40 px?
   - Can I see the thing that will hit (lance tip, crosshair, ball), and does it point there?
   - From this screen alone, would I know when to press and what I'd get?
   - After the press, can I tell what happened and why?
   If one answer is no, the game is not done, whatever the tests say.
5. Browser timing runs on software rendering and is slow: a timing test that misses there is
   expected (it did before the redesign too); the native run is the reference.
6. Add or update the game's rows in `doc/test-scenarios.md` (with the screenshot names) and its
   rules in the area's doc (e.g. `doc/burg.md`) in the same commit.

## Voices

Host lines go through `host_say` and are voiced (`tools/voices/voices.json`). Changing an
instruction line breaks `test_voices.gd::test_voiced_lines_are_still_in_the_game` until the
line is updated there: use the `elevenlabs-voices` skill (`scripts/voices.py generate <host>`,
then `check --prune`). New short feedback lines ("Zu früh!", "Verpasst!") cost ~15 credits each.

## Checklist before shipping a game

- [ ] Rule in 1–2 sentences in `set_info` and `describe()`; every word visible on screen.
- [ ] Hit test computed from the same geometry the player sees; no generic hand-item animation.
- [ ] Targets and markers ≥ ~40 / ~25 px on the phone; far targets as a 2D overlay.
- [ ] "Now" cue (colour + `set_cue`) including the reaction delay; window ≥ ~0.3 s; run-up ≥ 3 s.
- [ ] Every press: matching animation + big result cue with the reason; far presses free.
- [ ] Opponent's points shown per round.
- [ ] Scenario test presses from the visible cue with real input; failure paths tested.
- [ ] Phone screenshots of the decision moment and the result, looked at with the four questions.
- [ ] Voice lines updated; doc rows and rules updated.
