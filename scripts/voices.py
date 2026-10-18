#!/usr/bin/env python3
"""Voice lines with ElevenLabs (doc/voices.md, skill .claude/skills/elevenlabs-voices).

Reads tools/voices/voices.json (voices, design prompts, lines) and writes one clip per line to
assets/voice/<speaker>/<key>.mp3, key = first 12 hex of md5(line without „“ quotes); the game
(src/autoload/voice.gd) computes the same key. tools/voices/generated.json remembers what each
clip was made from, so only new or changed lines cost credits.

  scripts/voices.py sync [speaker…] [--prune]  # take the game's lines (VoiceLines) into voices.json
  VOICE_LOG=1 VERBOSE=1 scripts/scenario.sh > build/voices/dialogs.log   # every dialog the tests open
  scripts/voices.py quests build/voices/dialogs.log [speaker…]   # their lines (verbatim in src/) -> voices.json
  scripts/voices.py check [--prune]            # missing/outdated/orphan clips, characters to pay
  scripts/voices.py generate [speaker…] [--force] [--dry-run]   # e.g. one area at a time
  scripts/voices.py design <speaker> [--seed N] # 3 previews -> build/voices/, pitch per preview
  scripts/voices.py create <speaker> <generated_voice_id>   # save a preview as voice, store id
  scripts/voices.py say <speaker> "Text"       # one test clip -> build/voices/
  scripts/voices.py credits | voices           # quota / the account's voices

API key: $ELEVENLABS_API_KEY or ~/.config/elevenlabs/api_key (never in the repo).
"""
import base64
import hashlib
import json
import math
import os
import re
import struct
import subprocess
import sys
import urllib.error
import urllib.request
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "tools/voices/voices.json"
STATE = ROOT / "tools/voices/generated.json"
OUT = ROOT / "assets/voice"
SCRATCH = ROOT / "build/voices"
API = "https://api.elevenlabs.io"
# Mood tags for the lines everybody has (Conversations.HUNGRY/SAD), added by sync.
MOODS = {"Ich hab so einen Hunger!": "[whining] Ich hab so einen Hunger!",
         "Ach, mir geht's heute nicht so gut.": "[sad] Ach, mir geht's heute nicht so gut.",
         "Seufz …": "[sighs] Hach …"}
QUOTES = "„“”\" \n\t"


class QuotaExceeded(Exception):
    pass


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def api_key():
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k:
        p = Path.home() / ".config/elevenlabs/api_key"
        if not p.exists():
            die(f"no API key: set ELEVENLABS_API_KEY or write it to {p} (chmod 600)")
        k = p.read_text().strip()
    return k


def request(method, path, body=None, raw=False):
    """Returns (bytes or parsed JSON, response headers)."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"xi-api-key": api_key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            payload = r.read()
            return (payload if raw else json.loads(payload)), r.headers
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        if "quota" in detail.lower():   # 401 quota_exceeded: the month's credits are used up
            raise QuotaExceeded(detail)
        if "missing_permissions" in detail or "missing the permission" in detail:
            die(f"{method} {path}: the API key lacks a permission – {detail}")
        die(f"{method} {path}: HTTP {e.code} {detail}")


def load():
    return json.loads(CONFIG.read_text())


def save(cfg):
    CONFIG.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")


def clean(text):
    return text.strip(QUOTES)


def key(text):
    return hashlib.md5(clean(text).encode("utf-8")).hexdigest()[:12]


def clip_path(speaker, text):
    return OUT / speaker / f"{key(text)}.mp3"


def spoken_text(cfg, speaker, line):
    """What ElevenLabs gets: the voice's `direction` (an audio tag for the voice itself on every
    line, e.g. "[deep, gravelly troll voice]"), then the line's `say` (mood tags) or its text."""
    d = cfg["voices"][speaker].get("direction", "")
    t = line.get("say", line["text"])
    return f"{d} {t}" if d else t


def signature(cfg, speaker, line):
    v = cfg["voices"][speaker]
    sig = [v["voice_id"], v["model_id"], v.get("settings", {}), cfg["output_format"], spoken_text(cfg, speaker, line)]
    return hashlib.md5(json.dumps(sig, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]


def plan(cfg, only=None, force=False):
    """(speaker, line, path, signature) for every clip that has to be (re)made, round robin over
    the speakers (everybody's first line, then everybody's second …), so a quota that runs out
    leaves every speaker with some lines."""
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    todo = []
    for speaker, lines in cfg["lines"].items():
        if only and speaker not in only:
            continue
        for line in lines:
            p = clip_path(speaker, line["text"])
            sig = signature(cfg, speaker, line)
            rel = str(p.relative_to(ROOT))
            if force or not p.exists() or state.get(rel) != sig:
                todo.append((speaker, line, p, sig))
    rank = {}
    for t in todo:
        rank[id(t)] = sum(1 for u in todo[: todo.index(t)] if u[0] == t[0])
    todo.sort(key=lambda t: rank[id(t)])
    return todo, state


def cmd_check(cfg, prune=False):
    todo, _ = plan(cfg)
    todo = [t for t in todo if cfg["voices"][t[0]].get("voice_id")]
    wanted = {clip_path(s, l["text"]) for s, ls in cfg["lines"].items() for l in ls}
    orphans = sorted(p for p in OUT.rglob("*.mp3") if p not in wanted) if OUT.exists() else []
    chars = sum(len(spoken_text(cfg, s, l)) for s, l, _, _ in todo)
    for s, l, p, _ in todo:
        print(f"todo   {s:8} {p.relative_to(ROOT)}  {l['text'][:60]}")
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    for p in orphans:
        print(f"{'pruned' if prune else 'orphan'} {p.relative_to(ROOT)}  (no line in voices.json{'' if prune else '; --prune deletes it'})")
        if prune:
            p.unlink()
            Path(str(p) + ".import").unlink(missing_ok=True)
            state.pop(str(p.relative_to(ROOT)), None)
    if prune:
        STATE.write_text(json.dumps(state, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
        orphans = []
    for s, v in cfg["voices"].items():
        if not v.get("voice_id"):
            print(f"voice  {s}: no voice_id yet (design + create)")
    print(f"{len(todo)} clips to make, ~{chars} characters (1 credit each on v3/v4)")
    return 1 if todo or orphans else 0


def cmd_generate(cfg, only, force, dry):
    todo, state = plan(cfg, only, force)
    total = 0
    skipped = set()
    for speaker, line, p, sig in todo:
        v = cfg["voices"][speaker]
        if not v.get("voice_id"):
            skipped.add(speaker)
            continue
        text = spoken_text(cfg, speaker, line)
        if dry:
            print(f"would make {p.relative_to(ROOT)} ({len(text)} chars): {text}")
            total += len(text)
            continue
        body = {"text": text, "model_id": v["model_id"], "voice_settings": v.get("settings", {})}
        if "seed" in line:
            body["seed"] = line["seed"]
        try:
            audio, headers = request("POST", f"/v1/text-to-speech/{v['voice_id']}?output_format={cfg['output_format']}", body, raw=True)
        except QuotaExceeded as e:
            left = [(s, l) for s, l, q, _ in todo if not q.exists() and cfg["voices"][s].get("voice_id")]
            for _, l in left:
                l["pending"] = True
            save(cfg)
            print(f"quota used up: {e}\n{len(left)} lines marked pending in voices.json (generate again next month)")
            break
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(audio)
        cost = int(headers.get("character-cost", len(text)))
        total += cost
        state[str(p.relative_to(ROOT))] = sig
        if line.pop("pending", None):
            save(cfg)
        STATE.write_text(json.dumps(state, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
        print(f"made {p.relative_to(ROOT)}  {len(audio) // 1024} KB  {cost} credits  {line['text'][:50]}")
    for s in sorted(skipped):
        print(f"skipped {s}: no voice_id yet")
    print(f"{'would cost' if dry else 'cost'} {total} credits")


def pcm_pitch(pcm, rate):
    """Median fundamental frequency (Hz) of 16-bit mono PCM: autocorrelation of voiced frames."""
    n = len(pcm) // 2
    s = struct.unpack(f"<{n}h", pcm[: n * 2])
    step = max(1, rate // 8000)
    s = s[::step]
    r = rate / step
    frame, hop = 400, 800
    lo, hi = int(r / 450), int(r / 70)
    f0s = []
    for start in range(0, len(s) - frame - hi, hop):
        x = s[start:start + frame + hi]
        energy = sum(v * v for v in x[:frame])
        if energy < frame * 600 ** 2:
            continue
        best, lag = 0.0, 0
        for L in range(lo, hi):
            c = sum(x[i] * x[i + L] for i in range(0, frame, 2))
            if c > best:
                best, lag = c, L
        if lag and best > 0.3 * energy / 2:
            f0s.append(r / lag)
    f0s.sort()
    return f0s[len(f0s) // 2] if f0s else 0.0


def write_wav(path, pcm, rate):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)


def cmd_design(cfg, speaker, seed=None):
    d = cfg["voices"][speaker]["design"]
    body = {"voice_description": d["prompt"], "text": d["preview_text"], "model_id": d.get("model_id", "eleven_ttv_v3"),
            "guidance_scale": d.get("guidance_scale", 5), "loudness": d.get("loudness", 0.5)}
    if seed is not None or "seed" in d:
        body["seed"] = seed if seed is not None else d["seed"]
    rate = 22050
    res, headers = request("POST", f"/v1/text-to-voice/design?output_format=pcm_{rate}", body)
    SCRATCH.mkdir(parents=True, exist_ok=True)
    print(f"cost: {headers.get('character-cost', '?')} credits")
    for i, prev in enumerate(res["previews"]):
        pcm = base64.b64decode(prev["audio_base_64"])
        f = SCRATCH / f"{speaker}_design_{i}.wav"
        write_wav(f, pcm, rate)
        print(f"preview {i}: generated_voice_id={prev['generated_voice_id']}  pitch≈{pcm_pitch(pcm, rate):.0f} Hz  "
              f"{len(pcm) / 2 / rate:.1f} s  {f.relative_to(ROOT)}")
    print(f"keep one: scripts/voices.py create {speaker} <generated_voice_id>")


def cmd_create(cfg, speaker, gid):
    v = cfg["voices"][speaker]
    res, _ = request("POST", "/v1/text-to-voice", {"voice_name": v["name"], "voice_description": v["design"]["prompt"][:1000],
                                                    "generated_voice_id": gid})
    v["voice_id"] = res["voice_id"]
    v["design"]["generated_voice_id"] = gid
    save(cfg)
    print(f"{speaker}: voice_id {res['voice_id']} stored in {CONFIG.relative_to(ROOT)}")


def cmd_say(cfg, speaker, text):
    v = cfg["voices"][speaker]
    rate = 22050
    pcm, headers = request("POST", f"/v1/text-to-speech/{v['voice_id']}?output_format=pcm_{rate}",
                           {"text": text, "model_id": v["model_id"], "voice_settings": v.get("settings", {})}, raw=True)
    SCRATCH.mkdir(parents=True, exist_ok=True)
    f = SCRATCH / f"{speaker}_say.wav"
    write_wav(f, pcm, rate)
    print(f"{f.relative_to(ROOT)}  {len(pcm) / 2 / rate:.1f} s  pitch≈{pcm_pitch(pcm, rate):.0f} Hz  "
          f"{headers.get('character-cost', '?')} credits")


def game_lines(ids):
    """VoiceLines.of(id) for every id, from a headless Godot run (tests/voice_lines_dump.gd)."""
    out = subprocess.run([str(ROOT / "scripts/godot.sh"), "--headless", "--path", str(ROOT), "-s",
                          "tests/voice_lines_dump.gd", "--", *ids], capture_output=True, text=True, timeout=300).stdout
    m = re.search(r"^VOICE_LINES (.*)$", out, re.M)
    if not m:
        die("tests/voice_lines_dump.gd printed no VOICE_LINES:\n" + out[-2000:])
    return json.loads(m.group(1))


def cmd_sync(cfg, ids, prune):
    ids = ids or list(cfg["voices"])
    lines = game_lines(ids)
    added = 0
    for speaker in ids:
        have = cfg["lines"].setdefault(speaker, [])
        texts = {l["text"] for l in have}
        for t in lines[speaker]:
            if t not in texts:
                have.append({"text": t, "say": MOODS[t]} if t in MOODS else {"text": t})
                added += 1
                print(f"new    {speaker:10} {t}")
        # Quest and minigame lines are not in VoiceLines (scripts/voices.py quests, by hand).
        stale = [l for l in have if l["text"] not in lines[speaker] and "quest" not in l.get("where", "").lower()]
        for l in stale:
            print(f"{'pruned' if prune else 'stale '} {speaker:10} {l['text']}  (the game no longer says it)")
        if prune:
            cfg["lines"][speaker] = [l for l in have if l["text"] in lines[speaker]]
    save(cfg)
    print(f"{added} new lines; next: scripts/voices.py check / generate")


def cmd_quests(cfg, log, ids):
    """Dialog lines of voiced speakers from a VOICE_LOG scenario run: every quoted part (or the
    whole text) that appears verbatim in src/ (no filled-in numbers), not yet in voices.json."""
    source = "".join(p.read_text() for p in (ROOT / "src").rglob("*.gd")).replace("\\n", "\n")
    ids = set(ids or [s for s, v in cfg["voices"].items() if v.get("voice_id")])
    added = 0
    for row in Path(log).read_text().splitlines():
        if not row.startswith("VOICE_DIALOG\t"):
            continue
        _, speaker, text = row.split("\t", 2)
        if speaker not in ids:
            continue
        text = json.loads(text)
        quoted = re.findall(r"„(.*?)“", text, re.S) or [text]
        for part in quoted:
            part = clean(part)
            have = {l["text"] for l in cfg["lines"].setdefault(speaker, [])}
            if part in have or part in MOODS or part not in source or not re.search(r"[A-Za-zÄÖÜäöüß]", part) or part.startswith("("):
                continue
            cfg["lines"][speaker].append({"text": part, "where": "quest"})
            added += 1
            print(f"new    {speaker:10} {part[:90]}")
    save(cfg)
    print(f"{added} new quest lines")


def cmd_credits():
    s, _ = request("GET", "/v1/user/subscription")
    print(f"tier {s.get('tier')}: {s.get('character_count')} of {s.get('character_limit')} credits used, "
          f"reset at unix {s.get('next_character_count_reset_unix')}, voices {s.get('voice_slots_used', '?')}/{s.get('voice_limit')}")


def cmd_voices():
    res, _ = request("GET", "/v2/voices?page_size=100&voice_type=personal")
    for v in res["voices"]:
        print(f"{v['voice_id']}  {v['category']:10} {v['name']}")


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cfg = load()
    cmd, args = argv[0], argv[1:]
    flags = {a for a in args if a.startswith("--")}
    pos = [a for a in args if not a.startswith("--")]
    if cmd == "sync":
        cmd_sync(cfg, pos, "--prune" in flags)
    elif cmd == "quests":
        cmd_quests(cfg, pos[0], pos[1:])
    elif cmd == "check":
        return cmd_check(cfg, "--prune" in flags)
    elif cmd == "generate":
        cmd_generate(cfg, pos, "--force" in flags, "--dry-run" in flags)
    elif cmd == "design":
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        cmd_design(cfg, pos[0], seed)
    elif cmd == "create":
        cmd_create(cfg, pos[0], pos[1])
    elif cmd == "say":
        cmd_say(cfg, pos[0], pos[1])
    elif cmd == "credits":
        cmd_credits()
    elif cmd == "voices":
        cmd_voices()
    else:
        die(f"unknown command {cmd}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
