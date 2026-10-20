# Voices

Owner's wish (2026-10-17): characters speak their lines, made with ElevenLabs. Started with
Kiosk-Kemal and the Stadtpark's adults on the free plan (premade voices); on 2026-10-18 the
owner took the Starter plan (30 000 credits a month), and every named person in all areas got
a voice: the Stadtpark keeps its premade voices, the children, the Nordwald, the Kirmes and
the Oststadt have native German library voices (some with a regional accent: Bavarian and
Austrian in the forest, Berlin at the currywurst stand, Saxon and Swabian at the fair).
Only Pantomime Pierre stays silent.

How to make and remake clips (API, voices, prompts, costs, pitfalls): the skill
`.claude/skills/elevenlabs-voices/SKILL.md`.

## Files

| What | Where |
|---|---|
| Voices (voice id, model, settings, design prompt) and lines | `tools/voices/voices.json` (`tools/` has a `.gdignore`, Godot skips it) |
| What each clip was made from (voice, model, settings, text) | `tools/voices/generated.json` (written by the script) |
| Clips, mp3 44.1 kHz 64 kbit/s mono, ~15–40 KB each | `assets/voice/<speaker>/<key>.mp3`, key = first 12 hex of md5(line without „“) |
| Generator | `scripts/voices.py` (sync, check, generate, design, create, say, credits, voices) |
| The lines a person says outside quests | `VoiceLines.of(id)` (`src/core/voice_lines.gd`), dumped by `tests/voice_lines_dump.gd` for `sync` |
| Playback | `src/autoload/voice.gd` (autoload `Voice`) |
| API key | `~/.config/elevenlabs/api_key` (chmod 600, never in the repo) |

## In the game

- `UI.dialog(title, text)` calls `Voice.dialog`: the speaker is the Cast person whose display
  name is the title; every quoted part „…“ of the text with a clip is played in turn, a text
  without quotes as a whole. Narration in brackets has no clip and stays silent. Closing or
  replacing the dialog stops the voice.
- `Actor.say` calls `Voice.say`: the clip plays from an `AudioStreamPlayer3D` on the speaker
  (unit size 10 m, silent beyond `Voice.HEAR` = 40 m), not while a dialog is speaking. Beyond
  40 m from the camera the bubble isn't shown either (it looked like a missing voice).
- Anonymous people speak with a crowd voice (Cast `"voice"`, `Actor.voice()`): `volk_frau_jung`,
  `_mittel`, `_alt`, `volk_mann_…` by sex and age (`VoiceLines.crowd`), `volk_maedchen` and
  `volk_junge` for children. They have all the common lines (`VoiceLines.of` → `_crowd_lines`).
- Common reactions (applause, a horn, a vendor serving: `VoiceLines.pick`): the crowd says any
  of them, a named person always the same one, so each person needs only one clip per set. A
  named person waves back with one of their greetings and answers a chat with their own small
  talk (`VoiceLines.wave_back`, `reply`); role lines (Thorsten's phone, Kalle's litter, Mia's
  dogs, the vendors' thanks and the dog begging) are in `VoiceLines._reactions`.
- `DriveJob.radio` (a driving job's host, wherever they are) calls `Voice.radio`: played like a
  dialog line, queued after the line before it; the text goes into the job's panel
  ("Funk · Taxi-Tanja: „…“"). These lines are tagged `"where": "radio/minigame"` in voices.json.
  A taxi passenger in the back seat speaks the same way (`DriveJob.passenger_line`) with their
  crowd voice; getting in they name the street („Zur Lindenstraße, bitte!“, `TaxiJob.to_street`),
  the house number is on the map. A radio line waits for a bubble that is speaking.
- A line without a clip is silent, so voicing grows line by line. Volume: Lautstärke × Stimmen
  (setting `voice`, slider "Stimmen" in Einstellungen).
- Shop.interact picks the advert once, so the bubble and the dialog show (and speak) the same
  line; the dialog's voice replaces the bubble's.

## Voiced lines

- Everybody: greetings, work lines, small talk, shop calls, hungry/sad, quest dialogs and the
  hosts' lines in the minigames (voices.json has who has which voice: `premade` or `library`;
  `direction` adds an audio tag for the voice itself, e.g. Bruno's troll voice, Claudette's
  French and Gianni's Italian accent). Not voiced: Pantomime Pierre, the Kirmes ghost
  Gisbert, the castle ghost Hedwig, the lost child, the animals and the player's own sleep lines
  ("Zzz …", "Guten Morgen!"). Random visitors and customers speak with the crowd voices.
- Crowd voices (2026-10-20): the owner heard speech bubbles without a voice and silent taxi
  passengers. A 4-minute park run showed 112 of 174 bubbles without a clip: common lines
  (applause, chat replies, waving, a horn, the vendors' thanks), Thorsten's phone calls and the
  anonymous people. Eight crowd voices from the library (Ava, Irene, Carlotta as an older woman,
  Ben, Otto, Opa Johann, Emmy and Knurps for the children) and the common lines for every named
  person: 927 clips for 7 870 credits.
- The Ritterburg (2026-10-20): 25 people with native German library voices (Morwen an ancient
  narrator, Fiete North German, Sepp Austrian, Walburga a witch voice, Kasimir a helium
  character voice for the child), 345 clips for 6 474 credits on the Starter plan; Zambini's and
  Esmeralda's new story lines too.
- Kemal got two new greetings, Robin four (Robin's lines are in voices.json without a voice yet).
- Small talk ("Plaudern", chats between people): every named person in all areas has four own
  lines (Cast `smalltalk`, `Cast.smalltalk`; visitors keep the common ones).
- Stage directions ("(verbeugt sich)", "…") and lines with numbers that change (prices, counts)
  are not voiced.

`tests/unit/test_voices.gd` fails when a voiced speaker gets a line outside quests without a
line in voices.json (`sync`), a voiced line is no longer in `src/` (text changed), or a line
has no clip.

## Adding a character

1. Add the voice to `voices.json` (a premade voice id, or a voice made in the ElevenLabs web
   app, see the skill), then `scripts/voices.py sync <id>` takes the lines from `VoiceLines`.
   Quest lines by hand (see the skill: collect them from a scenario run); `say` for mood tags.
2. `scripts/voices.py check`, then `scripts/voices.py generate <speaker>`.
3. Run `scripts/test.sh unit`, add the character to `tests/scenarios/voices.gd`.
