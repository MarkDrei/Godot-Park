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
  (unit size 6 m, silent beyond 30 m), not while a dialog is speaking.
- `DriveJob.radio` (a driving job's host, wherever they are) calls `Voice.radio`: played like a
  dialog line, queued after the line before it; the text goes into the job's panel
  ("Funk · Taxi-Tanja: „…“"). These lines are tagged `"where": "radio/minigame"` in voices.json.
- A line without a clip is silent, so voicing grows line by line. Volume: Lautstärke × Stimmen
  (setting `voice`, slider "Stimmen" in Einstellungen).
- Shop.interact picks the advert once, so the bubble and the dialog show (and speak) the same
  line; the dialog's voice replaces the bubble's.

## Voiced lines

- Everybody: greetings, work lines, small talk, shop calls, hungry/sad, quest dialogs and the
  hosts' lines in the minigames (voices.json has who has which voice: `premade` or `library`;
  `direction` adds an audio tag for the voice itself, e.g. Bruno's troll voice, Claudette's
  French and Gianni's Italian accent). Not voiced: Pantomime Pierre, random visitors and
  customers, the Kirmes ghost Gisbert and the lost child (no Cast people).
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
