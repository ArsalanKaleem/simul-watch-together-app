# SIMUL

**Watch together, in sync.** SIMUL is a cross-platform Flutter app for watching
YouTube in perfect sync with friends, sharing your screen with audio, talking
over voice chat, reacting live, and playing a quick game of Connect 4 — all in
a shared room.

Built with Flutter + Firebase (auth, rooms, chat, sync state) and
[LiveKit](https://livekit.io) (voice + screen share).

> ⚠️ **Heads up:** the app code has been reviewed but not compiled in this
> bundle. After `flutter pub get`, run `flutter analyze` and fix any nits
> before shipping.

---

## Features

- 🎬 **Synced YouTube** — load a video and play/pause/seek stays in sync for everyone
- 🖥️ **Screen sharing with audio** — share a browser tab (or desktop) *with sound*
- 🔊 **Live voice chat** — talk while you watch
- 🔇 **Per-viewer audio control** — each viewer can mute the shared audio locally
- 💬 **Live chat + reactions**
- 🎮 **Connect 4** — just tap a column to join and play
- 🌗 **Light / dark mode** (engine + About screen done; see *Theming* below)
- 📱 **Runs on** Web, Windows, macOS, Linux, Android, iOS

---

## How it's wired (important)

This project uses a **shared Firebase backend** (the maintainer's project) for
auth, rooms, chat, sync state, and the game. **You do not set up Firebase** —
it's already configured in `lib/firebase_options.dart`.

The **only thing you supply is LiveKit** — the real-time voice/screen-share
service. Each deployer plugs in **their own** LiveKit project + a tiny token
server. That's the metered part, so it's yours to own.

```
┌────────────┐     Firebase (shared, maintainer's)   ┌──────────────┐
│  SIMUL app │ ───────────────────────────────────►  │  Firestore   │
│  (Flutter) │      auth · rooms · chat · sync        │  + Auth      │
└─────┬──────┘                                        └──────────────┘
      │
      │ voice + screen share            YOUR LiveKit + YOUR token server
      └───────────────────────────────►  (you configure these)
```

---

## Quick start

### 1. Clone & install
```bash
git clone https://github.com/YOUR_USERNAME/simul.git
cd simul
flutter pub get
```

### 2. Get your own LiveKit (the only setup you need)
1. Create a free project at **https://cloud.livekit.io**.
2. Copy your project's **WebSocket URL** — looks like
   `wss://your-project.livekit.cloud`.
3. In **Settings → Keys**, create an **API Key** and **API Secret** (the secret
   is shown once — save it).

### 3. Run the token server with your LiveKit key/secret
The app never holds the LiveKit secret — a small Node server mints room tokens.
```bash
cd token-server
cp .env.example .env          # then edit .env:
#   LIVEKIT_API_KEY=<your key>
#   LIVEKIT_API_SECRET=<your secret>
npm install
npm start                     # serves POST/GET /token on :5000
```
For a public/hosted demo, deploy this folder to **Render / Railway / Fly.io /
Cloud Run** (all have free tiers) and set the same two env vars there.

### 4. Run the app pointed at your LiveKit
```bash
flutter run -d chrome \
  --dart-define=USE_PRODUCTION=true \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud \
  --dart-define=LIVEKIT_TOKEN_URL=https://your-token-server/token
```
Or edit the two `defaultValue` strings in `lib/utils/constants.dart`
(`_liveKitUrlProd`, `_liveKitTokenUrlProd`) and just run `flutter run`.

Helper scripts are in `scripts/` (`run_web.sh` / `run_web.bat`).

That's it — no Firebase steps.

---

## Fully local development (no cloud at all)

Prefer to test without LiveKit Cloud? Run everything on your machine:

```bash
# terminal 1 — local LiveKit (dev mode, key=devkey / secret=secret)
livekit-server --dev

# terminal 2 — token server (its .env defaults already match dev mode)
cd token-server && npm install && npm start

# terminal 3 — app in dev mode (defaults to ws://localhost:7880)
flutter run -d chrome        # or: ./scripts/run_local.sh
```
In dev mode `USE_PRODUCTION` is `false`, so the app uses the localhost defaults
automatically.

---

## LiveKit free tier — what you get

LiveKit Cloud's free **Build** plan needs no credit card and gives roughly:

- **~5,000 WebRTC participant-minutes / month**
- **~50 GB data transfer / month**
- A **hard cap** — connections stop when you hit it and reset next month (no
  surprise bill). It's **recurring monthly**, not a one-time trial.

In practice, participant-minutes are counted **per person**, so a 2-person room
uses 2 minutes of allowance per real minute:

- **Voice-only, 2 people:** ~5,000 ÷ 2 ≈ **~40 hours/month**.
- **Screen sharing, 2 people:** bandwidth becomes the limit —
  ~2.5 Mbps ≈ ~1.1 GB/hr per viewer, so 50 GB ≈ **~40 hours/month** too.
- **More people / higher quality → proportionally fewer hours.**

So think *a few dozen hours of 2-person sessions per month, free*. If you
outgrow it, LiveKit's paid tier lifts the caps, or you can **self-host** the
open-source LiveKit server (Apache-2.0) on your own VPS. Numbers change — check
https://livekit.com/pricing before relying on them.

---

## Project structure

```
simul/
├── lib/
│   ├── main.dart               # app entry, theming wired here
│   ├── firebase_options.dart   # shared Firebase config (maintainer's)
│   ├── screens/                # auth, room, about, splash
│   ├── services/               # firebase, livekit, youtube sync, connect4, theme
│   ├── widgets/                # chat, reactions, queue, game, share viewer
│   └── utils/constants.dart    # ← LiveKit URL/token config + theme palette
├── token-server/               # Node token minting service (you run/deploy this)
├── firestore.rules             # starter security rules
├── scripts/                    # run_web / run_local helpers
└── .github/workflows/          # flutter analyze CI
```

---

## Configuration reference

| What | Where | Who sets it |
|------|-------|-------------|
| Firebase | `lib/firebase_options.dart` | Maintainer (already done) |
| LiveKit URL / token URL | `lib/utils/constants.dart` or `--dart-define` | **You** |
| LiveKit API key / secret | `token-server/.env` | **You** (never in the app) |
| Firestore rules | `firestore.rules` | Maintainer (`firebase deploy --only firestore:rules`) |

---

## Known caveats (please read)

- **Screen-share audio needs a checkbox.** When the browser's "Choose what to
  share" dialog appears, share a **Chrome/Edge tab** and tick
  **"Share tab audio"**. Sharing a bare *window* gives no audio; Firefox/Safari
  tab-audio support is limited.
- **First click unlocks sound.** Browsers block incoming audio until a user
  gesture; the app calls `startAudio()` on interaction and shows an
  "Enable sound" button if still blocked. This is expected browser behavior.
- **Viewer audio control is on/off mute**, not a volume slider — the LiveKit
  *Flutter* SDK has no per-track gain. A true slider is possible web-only.
- **Light/dark is partial.** The theme engine, the toggle, and the About screen
  are done; other screens still render dark until their hardcoded colors are
  migrated to `SimulColors.of(context)` (mechanical — see below).
- **App Check recommended.** Since the Firebase config is public in this repo,
  enable Firebase **App Check** and keep `firestore.rules` tight so only this
  app can use the backend.

---

## Theming: finishing light mode

Each remaining screen just needs its static colors swapped for the
theme-aware palette. In `build()`:

```dart
final c = SimulColors.of(context);   // then use c.bg, c.card, c.text, …
```

Mapping: `SimulColors.black → c.bg`, `.surface → c.surface`, `.card → c.card`,
`.border → c.border`, `.muted → c.muted`, `.white → c.text`. Drop `const` on
widgets the compiler flags. The About screen (`lib/screens/about_screen.dart`)
is a full worked example. A common design choice is light chrome + a dark video
stage — so you may deliberately leave the room's video area dark.

---

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). Please run
`flutter analyze` before opening a PR.

## License

[MIT](LICENSE) © 2026 Arsalan Kaleem
