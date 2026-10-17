# Voices

Owner's wish (2026-10-17): characters speak their lines, made with ElevenLabs. Started with
Kiosk-Kemal, then every adult of the Stadtpark with greetings, work lines, shop calls, hungry/sad
and their quest dialogs. Children stay silent for now: the free plan can't design voices or
use library voices through the API, and no premade voice is a child. Next areas (Nordwald,
Oststadt, Kirmes) one per month, as the free quota (~10 000 characters) allows. The owner
has a free ElevenLabs plan (non-commercial use, fine for a game only the owner plays).

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
- A line without a clip is silent, so voicing grows line by line. Volume: Lautstärke × Stimmen
  (setting `voice`, slider "Stimmen" in Einstellungen).
- Shop.interact picks the advert once, so the bubble and the dialog show (and speak) the same
  line; the dialog's voice replaces the bubble's.

## Voiced lines

- Stadtpark adults (premade voices on eleven_v4, the table is voices.json; `direction` adds an
  audio tag for the voice itself, e.g. Bruno's troll voice, Jacques' French accent): greetings,
  work lines, shop calls, hungry/sad, quest dialogs. Pantomime Pierre stays silent.
- Kemal got two new greetings, Robin four (Robin's lines are in voices.json without a voice yet).
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
