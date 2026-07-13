# SIMUL

**Watch together, in sync.** SIMUL is a cross-platform Flutter app for watching
YouTube in sync with friends, sharing your screen *with audio*, talking over
voice chat, reacting live, and playing Connect 4 — all in a shared room.

Built with Flutter + Firebase (auth, rooms, chat, sync state) and
[LiveKit](https://livekit.io) (voice + screen share).

> ⚠️ The app code here has been reviewed but not compiled in this bundle.
> After `flutter pub get`, run `flutter analyze` and fix any nits before shipping.

---

## Features

- 🎬 **Synced YouTube** — play/pause/seek stays in sync for everyone
- 🖥️ **Screen sharing with audio** — share a browser tab (or desktop) *with sound*
- 🔊 **Live voice chat**
- 🔇 **Per-viewer audio control** — each viewer can mute the shared audio locally
- 💬 **Live chat + reactions**
- 🎮 **Connect 4** — just tap a column to join and play
- 🌗 **Light / dark mode** (engine + Settings/About done; see *Theming*)
- 🔐 **In-app LiveKit setup** — paste your own keys in Settings; stored securely
- 📱 **Runs on** Web, Windows, macOS, Linux, Android, iOS

---

## How it's wired (read this first)

Two backends, and they're handled very differently:

**1. Firebase — already set up. You do nothing.**
Auth, rooms, chat, YouTube sync state and the game run on a **shared Firebase
project** that ships configured in `lib/firebase_options.dart`.

**2. LiveKit — each user brings their own, entered in-app.**
The real-time voice / screen-share layer is the metered part, so every user
supplies **their own** LiveKit project. There's a **Settings screen** in the app
(gear icon on the home screen, or the side drawer in a room) where you paste:

- your **LiveKit URL** (`wss://your-project.livekit.cloud`)
- your **API Key** and **API Secret**

Those are saved to **`flutter_secure_storage` on your device** and never leave
it. With a key + secret present, the app **mints its own LiveKit join tokens
on-device** — so there's **no token server to run or deploy**. 🎉

```
┌────────────┐   Firebase (shared, already configured)   ┌──────────────┐
│  SIMUL app │ ─────────────────────────────────────────►│ Firestore+Auth│
└─────┬──────┘                                            └──────────────┘
      │ voice + screen share
      │ token minted on-device from YOUR pasted key/secret
      ▼
  YOUR LiveKit project (wss://…livekit.cloud)
```

---

## Quick start

### 1. Clone & add two dependencies
```bash
git clone https://github.com/YOUR_USERNAME/simul.git
cd simul
```
Add these to your `pubspec.yaml` under `dependencies:` (also listed in
[`pubspec.additions.yaml`](pubspec.additions.yaml)):
```yaml
  flutter_secure_storage: ^9.2.2
  crypto: ^3.0.5
```
Then:
```bash
flutter pub get
```

### 2. Run the app
```bash
flutter run -d chrome     # or windows / macos / your device
```
No build-time flags, no `.env`, no token server.

### 3. Paste your LiveKit keys in Settings
1. Create a free project at **https://cloud.livekit.io**.
2. In **Settings → Keys**, create an **API Key** + **API Secret** and copy your
   project **URL** (`wss://your-project.livekit.cloud`).
3. In the app, tap the **⚙️ gear** on the home screen → paste **URL**,
   **API Key**, **API Secret** → **Save**.

That's it. Create or join a room, turn on your mic, share a tab — you're live.

> The Settings screen shows a green banner once a valid configuration is saved.

---

## Fully local development (optional)

Want to test without LiveKit Cloud? Run a local server and use dev keys:
```bash
livekit-server --dev      # LiveKit at ws://localhost:7880, key=devkey secret=secret
```
Then in the app's **Settings**, enter:
- URL: `ws://localhost:7880`
- API Key: `devkey`
- API Secret: `secret`

(If you leave Settings empty, the app also falls back to these localhost dev
defaults automatically.)

---

## Advanced: use a token server instead of on-device minting

On-device minting means your API **secret** sits in device storage. That's fine
for your *own* key on your *own* device, but if you'd rather keep the secret off
the client entirely, the repo includes a small Node token server in
[`token-server/`](token-server/):

```bash
cd token-server
cp .env.example .env      # set LIVEKIT_API_KEY / LIVEKIT_API_SECRET
npm install && npm start  # serves /token on :5000
```
Deploy it (Render / Railway / Fly.io / Cloud Run), then in the app's Settings →
**Advanced** paste the **Token Server URL** and leave the API Secret blank. The
app will fetch tokens from the server instead of minting them.

---

## LiveKit free tier — what you get

LiveKit Cloud's free **Build** plan needs no credit card and gives roughly:

- **~5,000 WebRTC participant-minutes / month**
- **~50 GB data transfer / month**
- A **hard cap** — connections stop when you hit it and reset next month. It's
  **recurring monthly**, not a one-time trial.

Participant-minutes are counted **per person**, so a 2-person room uses 2
minutes per real minute:

- **Voice-only, 2 people:** ~5,000 ÷ 2 ≈ **~40 hours/month**.
- **Screen sharing, 2 people:** bandwidth-bound — ~2.5 Mbps ≈ ~1.1 GB/hr per
  viewer, so 50 GB ≈ **~40 hours/month** too.
- **More people / higher quality → proportionally fewer hours.**

So: *a few dozen hours of 2-person sessions per month, free.* Check
https://livekit.com/pricing for current numbers.

---

## Project structure

```
simul/
├── lib/
│   ├── main.dart                       # entry; providers + theming
│   ├── firebase_options.dart           # shared Firebase config (committed)
│   ├── screens/
│   │   ├── settings_screen.dart        # ← paste LiveKit keys here
│   │   ├── auth_screen.dart · room_screen.dart · about_screen.dart · splash_screen.dart
│   ├── services/
│   │   ├── app_settings_service.dart   # secure-storage config store
│   │   ├── livekit_token.dart          # on-device JWT minting
│   │   ├── livekit_service.dart · firebase_service.dart · youtube_sync_service.dart · connect4_service.dart · theme_controller.dart
│   ├── widgets/                         # chat, reactions, queue, game, share viewer
│   └── utils/constants.dart            # theme palette + dev fallbacks
├── token-server/                       # OPTIONAL token server (advanced)
├── firestore.rules                     # starter security rules
└── .github/workflows/                  # flutter analyze CI
```

---

## Configuration reference

| What | Where | Who sets it |
|------|-------|-------------|
| Firebase | `lib/firebase_options.dart` | Maintainer (already done) |
| LiveKit URL / key / secret | **In-app Settings** → secure storage | **Each user** |
| Token server (optional) | `token-server/.env` + Settings → Advanced | Advanced users |
| Firestore rules | `firestore.rules` | Maintainer (`firebase deploy --only firestore:rules`) |

---

## Known caveats (please read)

- **Screen-share audio needs a checkbox.** In the browser's "Choose what to
  share" dialog, share a **Chrome/Edge tab** and tick **"Share tab audio"**.
  Sharing a bare *window* gives no audio; Firefox/Safari support is limited.
- **First click unlocks sound.** Browsers block incoming audio until a user
  gesture; the app calls `startAudio()` on interaction and shows an
  "Enable sound" button if still blocked. Expected browser behavior.
- **Viewer audio control is on/off mute**, not a volume slider — the LiveKit
  *Flutter* SDK has no per-track gain.
- **Secret storage on web is best-effort.** `flutter_secure_storage` on web
  can't match native Keychain/Keystore guarantees. Since it's the user's *own*
  key, this is acceptable; use the token-server path if you need the secret off
  the client.
- **Light/dark is partial.** Engine, Settings and About are done; other screens
  still render dark until their colors are migrated to `SimulColors.of(context)`
  (see below).
- **App Check recommended.** The Firebase config is public in this repo, so keep
  `firestore.rules` tight and enable Firebase App Check.

---

## Theming: finishing light mode

Each remaining screen just swaps static colors for the theme-aware palette:
```dart
final c = SimulColors.of(context);   // then c.bg, c.card, c.text, …
```
Mapping: `SimulColors.black → c.bg`, `.surface → c.surface`, `.card → c.card`,
`.border → c.border`, `.muted → c.muted`, `.white → c.text`. Drop `const` where
the compiler flags it. `settings_screen.dart` and `about_screen.dart` are
worked examples.

---

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Run `flutter analyze`
before opening one.

## License

[MIT](LICENSE) © 2026 Arsalan Kaleem
