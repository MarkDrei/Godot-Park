# Godot-Park ("Bank frei!")

Open-world park game in Godot 4.7 for web and Android. Overview and commands: `README.md`.
Architecture: `doc/arc42.md`.

## Conventions
- Game UI text in German; code, comments and docs in English.
- Toolchain is rootless in `~/.local/opt/godot-park` (`scripts/setup.sh`).

## Working
- Before debugging or testing, read `doc/testing-notes.md`.
- Ship changes with `scripts/release.sh "message"`. It tests, commits, pushes `main` (live deploy),
  waits for the deploy and verifies the site and APK. Don't push and check by hand.
- Check visual changes with screenshots (`scripts/web_test.sh <preset>`, read the PNGs).

## Maintaining doc/testing-notes.md
Whenever you lose time to a testing or debugging problem, add the lesson to
`doc/testing-notes.md` in the same commit: a misleading error, a flaky test, a tool limitation, a
dev option or a game-specific pitfall. Keep entries short and concrete (symptom → cause → what to
do). Update or delete entries that turn out to be wrong or outdated. Add new dev options and
scripts to the quick reference.
