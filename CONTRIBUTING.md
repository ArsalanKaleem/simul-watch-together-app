# Contributing to SIMUL

Thanks for your interest in improving SIMUL!

## Getting set up
1. Fork and clone the repo.
2. `flutter pub get`
3. Follow the **Quick start** in the README to point the app at your own
   LiveKit + token server (Firebase is already configured).
4. Run `flutter analyze` — it should be clean.

## Ground rules
- Keep PRs focused; one feature or fix per PR.
- Run `flutter analyze` (and `flutter test` if you add tests) before pushing.
- Match the existing style. If you touch a screen's colors, migrate it to the
  theme-aware palette (`SimulColors.of(context)`) rather than adding new
  hardcoded colors — see the About screen for the pattern.
- Never commit secrets: no LiveKit API secret in the app, no service-account
  JSON. The LiveKit secret lives only in `token-server/.env`.

## Good first issues
- Migrate a remaining screen to full light/dark support.
- Add a web-only volume slider for shared audio.
- Add widget/unit tests.

## Reporting bugs
Open an issue with steps to reproduce, platform (web/desktop/mobile), and what
you expected vs. what happened.
