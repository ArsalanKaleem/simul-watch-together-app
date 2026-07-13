# SIMUL

<div align="center"> # 🎬 SIMUL

**Watch together, in sync.**

A cross-platform Flutter app for watching YouTube in sync with friends, sharing your screen *with audio*, talking over voice chat, reacting live, and playing Connect 4 — all in one shared room.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://claude.ai/chat/LICENSE)[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)[![Platform](https://img.shields.io/badge/platform-web%20%7C%20android%20%7C%20ios%20%7C%20windows%20%7C%20macos%20%7C%20linux-informational)](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-platform-support)[![Firebase](https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)[![LiveKit](https://img.shields.io/badge/realtime-LiveKit-0F172A?logo=webrtc&logoColor=white)](https://livekit.io/)[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://claude.ai/chat/CONTRIBUTING.md)[![Flutter CI](https://github.com/ArsalanKaleem/simul-watch-together-app/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/ArsalanKaleem/simul-watch-together-app/actions/workflows/flutter-ci.yml)[![GitHub](https://img.shields.io/badge/GitHub-ArsalanKaleem-181717?logo=github&logoColor=white)](https://github.com/ArsalanKaleem)[![Portfolio](https://img.shields.io/badge/Portfolio-arsalankaleem.github.io-000000?logo=googlechrome&logoColor=white)](https://arsalankaleem.github.io/portfolio/)[![LinkedIn](https://img.shields.io/badge/LinkedIn-arsalankaleem-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/arsalankaleem)

[Features](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-features) • [Screenshots](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-screenshots) • [Quick Start](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-quick-start) • [Usage Guide](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-usage-guide) • [Configuration](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-configuration) • [Contributing](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-contributing) • [Roadmap](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-roadmap--known-issues)

</div> ---

 ---## 📸 Screenshots

> **Screenshots coming soon.** The app is fully functional — this section will be updated with real screenshots and a short demo GIF shortly. Want to help? See [`docs/screenshots/README.md`](https://claude.ai/chat/docs/screenshots/README.md) for exactly what's needed — it's a great first contribution.

<div align="center"> |        Home        |  Room — Watching  |    Screen Share    |
| :-------------------: | :-------------------: | :-------------------: |
| 🖼️*coming soon* | 🖼️*coming soon* | 🖼️*coming soon* |


|     Connect 4     |     Settings     |    Light Mode    |
| :---------------: | :---------------: | :---------------: |
| 🖼️*coming soon* | 🖼️*coming soon* | 🖼️*coming soon* |

</div> ---

 ---## ✨ Features


|                                   |                                                                                                                                                                      |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🎬**Synced YouTube playback**     | Play, pause, and seek stay in sync for everyone in the room                                                                                                          |
| 🖥️**Screen sharing with audio** | Share a browser tab (or desktop) —*with sound*                                                                                                                      |
| 🔊**Live voice chat**             | Talk over LiveKit voice while you watch                                                                                                                              |
| 🔇**Per-viewer audio control**    | Each viewer can locally mute shared audio without affecting anyone else                                                                                              |
| 💬**Live chat & reactions**       | Floating chat panel plus animated emoji reactions                                                                                                                    |
| 🎮**Connect 4**                   | Tap a column to join and play — no separate "join" step                                                                                                             |
| 🌗**Light / dark mode**           | Theme engine + toggle shipped; full app coverage is an open item — see[Roadmap](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-roadmap--known-issues) |
| 🔐**In-app LiveKit setup**        | Paste your own keys in Settings; stored securely on-device, tokens minted locally                                                                                    |
| 📱**Truly cross-platform**        | Web, Windows, macOS, Linux, Android, iOS from one codebase                                                                                                           |

---

## 🧱 Tech Stack

* **[Flutter](https://flutter.dev/)** — UI, cross-platform target
* **[Firebase](https://firebase.google.com/)** (Auth + Firestore) — rooms, chat, presence, sync state, Connect 4 (shared backend, already configured)
* **[LiveKit](https://livekit.io/)** — WebRTC voice + screen share (each user brings their own project)
* **[provider](https://pub.dev/packages/provider)** — state management
* **[flutter\_secure\_storage](https://pub.dev/packages/flutter_secure_storage)** — on-device credential storage

---

## 🗺️ How it's wired

Two backends, handled very differently:

1. **Firebase — already set up, you do nothing.** Auth, rooms, chat, sync state, and the game run on a shared Firebase project configured in `lib/firebase_options.dart`.
2. **LiveKit — you bring your own, entered in-app.** Voice/screen-share is the metered part. Open the app's **⚙️ Settings** screen, paste your LiveKit URL + API key/secret, and the app mints its own join tokens on-device — no server to deploy.

```
┌────────────┐   Firebase (shared, preconfigured)   ┌──────────────┐
│  SIMUL app │ ─────────────────────────────────────►│ Firestore+Auth│
└─────┬──────┘                                        └──────────────┘
      │ voice + screen share
      │ token minted on-device from keys pasted in Settings
      ▼
  YOUR LiveKit project (wss://…livekit.cloud)
```

---

## 🚀 Quick Start

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
* A free [LiveKit Cloud](https://cloud.livekit.io/) account (no credit card)

### 1. Clone and install

```bash
git clone https://github.com/ArsalanKaleem/simul-watch-together-app.git
cd simul
```

Add two dependencies to your `pubspec.yaml` (also listed in [`pubspec.additions.yaml`](https://claude.ai/chat/pubspec.additions.yaml)):

```yaml
dependencies:
  flutter_secure_storage: ^9.2.2
  crypto: ^3.0.5
```

Then:

```bash
flutter pub get
flutter analyze     # should be clean
```

### 2. Run it

```bash
flutter run -d chrome     # or windows / macos / linux / a connected device
```

No build flags, no `.env` file needed to get the app on screen.

### 3. Connect your own LiveKit project

1. Create a free project at **cloud.livekit.io**.
2. **Settings → Keys** → create an API Key (copy the key + the secret shown once).
3. Copy your project URL — looks like `wss://your-project.livekit.cloud`.
4. In the running app: tap **⚙️ Settings** → paste URL, Key, Secret → **Save**.

You're live. Create a room, share the code, and go.

---

## 📖 Usage Guide

### Creating a room

1. Open the app → **Create Room** tab → enter your name → **Create Room**.
2. A popup shows your 6-character room code — **Copy** it or tap **Enter Room**.
3. Share the code with whoever you're watching with.

### Joining a room

1. **Join Room** tab → enter your name and the room code → **Join Room**.

### While in a room


| Action                                   | How                                                                                                                                  |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Load a YouTube video                     | Paste a URL into the bar under the video                                                                                             |
| Talk                                     | Tap the 🎤 mic icon in the top bar                                                                                                   |
| Share your screen                        | Tap 🖥️ (top bar on desktop, or**Settings → Share Screen**on mobile) — pick a**tab**and tick**"Share tab audio"**to include sound |
| Mute someone's shared audio just for you | Tap the speaker icon on the share view                                                                                               |
| Chat                                     | Tap the floating chat bubble, bottom-right                                                                                           |
| React                                    | Use the reaction bar (toggle visibility from the drawer)                                                                             |
| Play Connect 4                           | Open the**Games**tab, tap**Start**, then just tap any column to join                                                                 |
| Invite more people                       | Open the drawer (≡) →**Invite to Room**                                                                                            |
| See who's here                           | Tap the participant count chip in the top bar                                                                                        |
| Switch theme                             | Drawer →**Light/Dark Mode**, or from Settings                                                                                       |
| Leave                                    | Back arrow, top-left                                                                                                                 |

### Configuring LiveKit later

Drawer → **Settings**, or the ⚙️ icon on the home screen — update your URL/key/secret any time, or switch to the advanced token-server mode (see below).

---

## ⚙️ Configuration


| What                              | Where                                     | Who sets it                                           |
| --------------------------------- | ----------------------------------------- | ----------------------------------------------------- |
| Firebase                          | `lib/firebase_options.dart`               | Maintainer (already done)                             |
| LiveKit URL / key / secret        | **In-app Settings**→ secure storage      | **Each user**                                         |
| Token server (advanced, optional) | `token-server/.env`+ Settings → Advanced | Advanced users only                                   |
| Firestore rules                   | `firestore.rules`                         | Maintainer (`firebase deploy --only firestore:rules`) |

<details> <summary><strong>Advanced: run your own token server instead of on-device minting</strong></summary> On-device minting keeps your LiveKit secret in secure storage on your device. If you'd rather keep the secret off the client entirely:

```bash
cd token-server
cp .env.example .env      # set LIVEKIT_API_KEY / LIVEKIT_API_SECRET
npm install && npm start  # serves /token on :5000
```

Deploy it (Render / Railway / Fly.io / Cloud Run are all free-tier friendly), then in the app's **Settings → Advanced**, paste the **Token Server URL** and leave API Secret blank.

</details> <details> <summary><strong>Fully local development (no cloud at all)</strong></summary> 
```bash
livekit-server --dev      # ws://localhost:7880, key=devkey secret=secret
```

In Settings, enter URL `ws://localhost:7880`, Key `devkey`, Secret `secret` (leaving Settings empty also falls back to these automatically).

</details> <details> <summary><strong>LiveKit free tier — what you get</strong></summary> LiveKit Cloud's free **Build** plan (no card required):

* \~5,000 WebRTC participant-minutes / month
* \~50 GB data transfer / month
* Hard cap, resets monthly

In practice: **\~40 hours/month of 2-person sessions**, whether voice-only (minute-bound) or screen-sharing (bandwidth-bound). More people or higher quality reduces this proportionally. Check [livekit.com/pricing](https://livekit.com/pricing) for current numbers.

</details> ---

## 📁 Project Structure

```
simul/
├── lib/
│   ├── main.dart                       # entry; providers + theming
│   ├── firebase_options.dart           # shared Firebase config (committed)
│   ├── screens/
│   │   ├── settings_screen.dart        # paste LiveKit keys here
│   │   ├── auth_screen.dart            # home screen (create/join room)
│   │   ├── room_screen.dart            # the watch-together room
│   │   ├── about_screen.dart
│   │   └── splash_screen.dart
│   ├── services/
│   │   ├── app_settings_service.dart   # secure-storage config store
│   │   ├── livekit_token.dart          # on-device JWT minting
│   │   ├── livekit_service.dart
│   │   ├── firebase_service.dart
│   │   ├── youtube_sync_service.dart
│   │   ├── connect4_service.dart
│   │   └── theme_controller.dart
│   ├── widgets/                        # chat, reactions, queue, game, share viewer
│   └── utils/constants.dart            # theme palette + dev fallbacks
├── token-server/                       # optional token server (advanced path)
├── firestore.rules                     # starter security rules
├── docs/                               # changelogs, fix writeups, screenshots
└── .github/                            # CI workflow + issue templates
```

---

## 🧪 Testing

```bash
flutter analyze
flutter run -d chrome
```

There's no automated test suite yet — see [Roadmap](https://claude.ai/chat/77c3adf2-e764-4891-9423-74f8705a12fb#-roadmap--known-issues). Manual testing needs **two participants** in the same room (two browser profiles, or two devices) since most of the interesting behavior (voice, screen share, Connect 4) only shows up multiplayer.

---

## 🗺️ Roadmap & Known Issues

* 🌗 **Light/dark mode is partial** — the theme engine, Settings, and About screens are fully migrated; most other screens still render dark regardless of the toggle. This is filed as a ready-to-pick-up issue: **[`docs/issues/dark-mode-support.md`](https://claude.ai/chat/docs/issues/dark-mode-support.md)** — great first contribution.
* 📸 Screenshots/demo GIF — see [`docs/screenshots/README.md`](https://claude.ai/chat/docs/screenshots/README.md).
* 🧪 No automated tests yet.
* 🔊 Viewer audio control is on/off mute only (no volume slider) — a LiveKit Flutter SDK limitation; a web-only slider is possible, see [`docs/CHANGES_AND_FIXES.md`](https://claude.ai/chat/docs/CHANGES_AND_FIXES.md).

See [open issues](https://github.com/ArsalanKaleem/simul-watch-together-app/issues) for the full list.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](https://claude.ai/chat/CONTRIBUTING.md) before opening a PR. Good first issues are labeled [`good first issue`](https://github.com/ArsalanKaleem/simul-watch-together-app/labels/good%20first%20issue) on the issue tracker.

## 👤 Author

**Arsalan Kaleem**

[![GitHub](https://img.shields.io/badge/GitHub-ArsalanKaleem-181717?logo=github&logoColor=white)](https://github.com/ArsalanKaleem)[![Portfolio](https://img.shields.io/badge/Portfolio-arsalankaleem.github.io-000000?logo=googlechrome&logoColor=white)](https://arsalankaleem.github.io/portfolio/)[![LinkedIn](https://img.shields.io/badge/LinkedIn-arsalankaleem-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/arsalankaleem)

## 📄 License

Distributed under the [MIT License](https://claude.ai/chat/LICENSE). © 2026 Arsalan Kaleem.

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


| What                       | Where                                      | Who sets it                                           |
| -------------------------- | ------------------------------------------ | ----------------------------------------------------- |
| Firebase                   | `lib/firebase_options.dart`                | Maintainer (already done)                             |
| LiveKit URL / key / secret | **In-app Settings** → secure storage      | **Each user**                                         |
| Token server (optional)    | `token-server/.env` + Settings → Advanced | Advanced users                                        |
| Firestore rules            | `firestore.rules`                          | Maintainer (`firebase deploy --only firestore:rules`) |

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
