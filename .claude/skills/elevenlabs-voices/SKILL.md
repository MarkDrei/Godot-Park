---
name: elevenlabs-voices
description: Make or remake spoken voice lines for Bank frei! characters with ElevenLabs (choosing or designing voices, writing lines with audio tags, generating clips with scripts/voices.py, wiring them into the game, costs and free-plan limits). Use when a character should get a voice, a voiced line changes, or clips need regenerating.
---

# Voice lines with ElevenLabs

Game side and file layout: `doc/voices.md`. This skill is the how-to and what we learned about
the API. **Update it whenever you find out something new** (a limit, an error, a setting that
sounds better), with the date.

## Setup

- Key: `~/.config/elevenlabs/api_key` (chmod 600) or `$ELEVENLABS_API_KEY`. Never print it, never
  put it in the repo; read it in scripts only. The owner writes it in their own shell.
- Key permissions are set per key on elevenlabs.io (Developers → API keys). Our key (2026-10-17) has
  TTS and Voices; User read and Models read are still missing. A missing one answers
  401 `missing_permissions` ("missing the permission voices_read …"). Needed:
  Text to Speech (generate); Voices read/write (list, save designed voices); User read
  (`credits`); Models read (optional).
- Plan (2026-10): free trial, ~10 000 credits a month, non-commercial use only. The owner is the
  only player, that is fine.

## Workflow

```bash
scripts/voices.py sync herbert peggy    # the game's lines (VoiceLines: greet, work, shop ads, hungry/sad)
VOICE_LOG=1 VERBOSE=1 scripts/scenario.sh > build/voices/dialogs.log   # every dialog the tests open
scripts/voices.py quests build/voices/dialogs.log   # quoted dialog lines found verbatim in src/
scripts/voices.py check                 # what is missing/outdated, characters it would cost
scripts/voices.py generate robin --dry-run
scripts/voices.py generate robin        # only new or changed lines cost credits
scripts/voices.py say kemal "Text"      # one test clip -> build/voices/kemal_say.wav + pitch
scripts/voices.py credits               # needs User read
scripts/test.sh unit && scripts/scenario.sh voices
```

1. Collect every line the character says: `sync` takes the everyday lines from `VoiceLines.of`
   (with mood tags for hungry/sad). Quest and minigame lines: `quests` from a VOICE_LOG scenario
   run finds only dialogs the tests open; grep the rest by hand: `UI.dialog(` with the person's
   display name, `host_say(`/`.say("` in the minigames whose `host_id` is the person, random
   variants (`["Allez!", "Et voilà …"][randi() % 3]`). Lines with filled-in values (`%s`, `%d`,
   prices) can't be voiced; a quoted part that is a `%s` of a constant (Bruno's riddles) can, if
   the dialog quotes it on its own („Challenge!“\n\n„%s“). `text` = exactly the game text
   without „“; `say` = mood tags, spelled-out numbers; the voice's `direction` = an audio tag for
   the voice itself before every line (troll voice, French accent, out of breath).
   `test_voices.gd` checks every `text` is still in src/ and VoiceLines are all in voices.json.
2. Pick or design a voice (below), put `voice_id`, `model_id`, `settings` into voices.json.
3. Test with `say` first (a short line), then `generate`. Commit the mp3s **and** their
   `.mp3.import` files plus `tools/voices/generated.json`.
4. You cannot listen. Check what you can: `pitch≈` from `say`/`design` (adult male ~85–155 Hz,
   adult female ~165–255 Hz, child ~250–400 Hz), duration vs text length; then send a wav to the
   owner with SendUserFile and ask. An STT round trip (Speech to Text permission) would let a
   script check the words; not set up yet.

## What the free plan allows via the API (tested 2026-10-17)

| Works | Blocked |
|---|---|
| TTS with premade voices (v4, v3) | Voice Design (`/v1/text-to-voice/design`): 403 `feature_not_available` |
| TTS with your own voices (designed in the web app) – to be confirmed | Library voices in TTS: 402 `paid_plan_required` |
| Searching the library, listing voices | |

The cheapest unlock is "add $5 of credits" (pay as you go) or Creator.

## Costs (measured 2026-10-17)

- TTS on eleven_v4 / eleven_v3: **1 credit per character** of the sent text (incl. audio tags).
  The response header `character-cost` tells the real cost; the script prints it.
- Kemal's 10 lines: 366 credits. A typical line: 20–70 credits, 14–40 KB as mp3_44100_64.
- Stadtpark round (2026-10-17): 22 adults × ~6 everyday lines = 138 clips, 5 591 credits; their
  quest/minigame lines 41 clips, 2 618 credits (Bruno's key speech alone 412). A `direction`
  adds its length to every line. Whole month so far ≈ 8 650 of ~10 000.
- Voice Design: charged for the preview text (100–1000 characters) once per call (3 previews).
- Some Voice Library voices carry a credit multiplier (legacy custom rates).

## Models

| model_id | Notes |
|---|---|
| `eleven_v4` | Newest (2026), best quality, 90+ languages incl. German. Settings: only stability and similarity_boost (no style, no speed). No SSML `<break>`. Audio tags work. **Speaks the target language natively**: an English premade voice speaks fluent German without an English accent. |
| `eleven_v4_turbo` | Low latency variant for real time; not needed for pre-made clips. |
| `eleven_v3` | Expressive, audio tags, 70+ languages. ElevenLabs: Voice Design voices may sound better on v3 than on v4 – compare. |
| `eleven_multilingual_v2` | Older, stable for long text, no `language_code`. |
| `eleven_flash_v2_5` | Cheapest/fastest, half price, weaker; number normalisation off by default. |

Output formats on the free plan: mp3 up to 128 kbit/s (192 needs Creator), pcm/wav up to
24–32 kHz (44.1 kHz needs Pro). We use `mp3_44100_64` for the game (Godot imports mp3, also on
the web) and `pcm_22050` for analysis (wrapped as wav by the script).

## Voices

- **Premade voices** work on the free plan with TTS; ids are stable. They are English, but v4
  makes them speak German natively (English words like "Howdy!" stay English). The account has
  21 (`GET /v2/voices?category=premade`, 2026-10-17): male middle-aged Roger
  `CwhRBWXzGAHq8TQ4Fs17` (laid-back), George `JBFqnCBsd6RMkjVDRZzb` (warm storyteller), Callum
  `N2lVS1w4EtoT3dr4eOWO` (husky trickster), Eric `cjVigY5qzO86Huf0OWal` (smooth), Chris
  `iP95p4xoKVk53GoZ742B` (charming), Brian `nPczCjzI2devNBz1zQrb` (deep, comforting), Daniel
  `onwK4e9ZLuTAKqWW03F9` (steady broadcaster), Adam `pNInz6obpgDQGcFmaJgB` (dominant, firm);
  male young Charlie `IKne3meq5aSn9XLyUdCD` (deep, energetic), Harry `SOYHLrjzK2X1ezoPC6cr`
  (fierce warrior), Liam `TX3LPaxmHKxFdv7VOQHJ` (energetic), Will `bIHbv24MWmeRgasZH58o`
  (relaxed); male old Bill `pqHfZKP75CvOlQylNhV4`; female middle-aged Bella
  `hpp4J3VqNfWAUOO0d1Us` (bright, warm), Alice `Xb7hH8MSUJpSbSDYk0k2` (clear educator), Matilda
  `XrExE9yKIg1WjnnlVkGX` (upbeat), Lily `pFZP5JQG7iQjIQuC4Bku` (velvety); female young Sarah
  `EXAVITQu4vr4xnSDxMaL` (reassuring), Laura `FGY2WhTYpPnrIDTdsKH5` (quirky), Jessica
  `cgSgspJ2msm6clMCkdW9` (playful); neutral River `SAz9YHcvj6GT2YYXdXww` (calm). No child, no
  old woman: age and character come from `direction` tags. Who has which: voices.json
  (`premade`). Spread them by area (park, Nordwald, Oststadt, Kirmes) so repeats are not heard
  together.
- **Voice Library** (community voices, many native German with a language tag): searchable with
  `GET /v1/shared-voices?language=de&age=young&search=kid&gender=male` (Voices read; fields
  `free_users_allowed`, `rate`, `use_case`). The FAQ says no child voices, but there are many
  child-like *cartoon character* voices by adults (2026-10-17: "Teddy Twinkle – Cute Cartoon"
  `XjGYkUkzth8BPs29fmcV` en boy, "Bibi Blume" `7Nj1UduP6iY6hWpEDibS` de cheeky cartoon,
  "Knurps" de chipmunk, "Manni – Youthful Know-It-All" de; many Hindi kid characters).
  **On the free plan library voices can't be used via the API at all**: TTS answers 402
  `paid_plan_required` "Free users cannot use library voices via the API. Upgrade to Creator or
  add $5 of credits". `free_users_allowed: true` only means the web app.
- **Voice Design** (voice from a text prompt): **the API is paid-only** – the free plan gets
  403 `feature_not_available` "Creating a voice through the API is only available on a paid
  plan." On the free plan the owner designs in the web app (Voices → Create a Voice → Voice
  Design), saves the voice and gives us the voice id. With a paid plan:
  `scripts/voices.py design <speaker>` (POST /v1/text-to-voice/design, 3 previews as wav with
  pitch) and `scripts/voices.py create <speaker> <generated_voice_id>` (POST /v1/text-to-voice).
  Children (Robin, 9) can only come from Voice Design.

### Voice Design prompts

Format that works best (ElevenLabs guide):

```
Native German, standard Hochdeutsch without any foreign accent. <Gender>, <age>. Perfect audio quality.
Persona: <2–5 words>. Emotion: <2–3 adjectives>.
<1–2 sentences on timbre, pacing, delivery>
```

- Name the language and variant in the first sentence, or the accent drifts.
- Don't write "accent" for intonation; avoid FX words (reverb, echo, phone, tape).
- "Perfect audio quality" / "studio-quality recording" for clean output.
- Preview text: 100–1000 characters, in German, matching the persona (a calm voice reading a
  shouted line comes out odd). Longer previews give steadier voices.
- `guidance_scale` (default 5): lower = more natural, higher = closer to the prompt (can sound
  artificial). `loudness` −1…1 (0 ≈ −24 LUFS). `seed` for the same voice again. Models
  `eleven_ttv_v3` (supports reference audio) and `eleven_multilingual_ttv_v2`.

## Writing lines (v3/v4)

- Audio tags in English in square brackets inside the German text: `[excited]`, `[whispers]`,
  `[sighs]`, `[laughs]`, `[chuckles]`, `[sad]`, `[mischievously]`, `[sarcastic]`, `[curious]`,
  `[crying]`, `[calling out]`. Be explicit (`[low, gravelly voice]`); a vague tag can turn into a
  sound effect. Tags the voice was not trained on work less reliably.
- Ellipses (…) give pauses and weight, CAPITALS give emphasis, normal punctuation the rhythm.
  No `<break>` on v3/v4.
- Write numbers as words when the pronunciation matters ("fünfzehn"); v4 normalises otherwise.
- Interjection-only lines ("Seufz …") read badly: send a performance instead (`[sighs] Hach …`).
- `seed` per line (in voices.json) makes a take repeatable (best effort).

## API reference (only what we use)

- `POST /v1/text-to-speech/{voice_id}?output_format=mp3_44100_64`, header `xi-api-key`, body
  `{"text", "model_id", "voice_settings": {"stability", "similarity_boost", "style",
  "use_speaker_boost", "speed"}, "seed", "language_code", "previous_text", "next_text"}`.
  Returns the audio; headers `character-cost`, `request-id`.
- `GET /v2/voices?voice_type=personal&page_size=100` (Voices read), `GET /v1/user/subscription`
  (User read), `GET /v1/models` (Models read).
- Docs index: https://elevenlabs.io/docs/llms.txt; every page as markdown by appending `.md`
  (e.g. `/docs/overview/capabilities/text-to-speech/best-practices.md`). Fetch with curl, the
  pages are long.

## Pitfalls

- Validation (422) is checked before permissions/plan: a 422 does not mean the call is allowed.
- `ResourceLoader.exists()` stays true for a deleted mp3 while its `.mp3.import` and the
  imported data are there; delete both when removing a clip (`check` lists orphans).
- The clip key is md5 of the text without „“ and whitespace; `Voice.path` (GDScript) and
  `scripts/voices.py` must strip the same characters.
