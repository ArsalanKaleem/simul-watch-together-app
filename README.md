<div align="center">

<img src="docs/screenshots/banner.png" alt="SIMUL — Watch together, in sync." width="100%" />

# 🎬 SIMUL

### Watch together, in sync.

**One room. Every platform. Zero setup for your friends.**
Synced YouTube playback, voice chat, screen sharing with audio, live reactions, and Connect 4 — without the "3, 2, 1, play!" countdown.

<br/>

[![Live Demo](https://img.shields.io/badge/🌐_Live_Demo-simul--deskweb--app.web.app-000000?style=for-the-badge)](https://simul-deskweb-app.web.app/)

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)](https://firebase.google.com)
[![LiveKit](https://img.shields.io/badge/LiveKit-WebRTC-0F172A?style=flat-square&logo=webrtc&logoColor=white)](https://livekit.io)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)

[![CI](https://github.com/ArsalanKaleem/simul-watch-together-app/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/ArsalanKaleem/simul-watch-together-app/actions/workflows/flutter-ci.yml)
[![Platforms](https://img.shields.io/badge/platform-web%20%7C%20android%20%7C%20ios%20%7C%20windows%20%7C%20macos%20%7C%20linux-informational?style=flat-square)](#-platform-support)
[![Stars](https://img.shields.io/github/stars/ArsalanKaleem/simul-watch-together-app?style=flat-square)](https://github.com/ArsalanKaleem/simul-watch-together-app/stargazers)
[![Downloads](https://img.shields.io/github/downloads/ArsalanKaleem/simul-watch-together-app/total?style=flat-square)](https://github.com/ArsalanKaleem/simul-watch-together-app/releases)

<br/>

[**Why SIMUL**](#-why-simul) · [**Features**](#-features) · [**Screenshots**](#-screenshots) · [**Try it now**](#-try-it-right-now) · [**Get LiveKit keys**](#-getting-your-livekit-keys-5-minutes) · [**Tech Stack**](#-tech-stack) · [**Architecture**](#-architecture--security) · [**Downloads**](#-downloads) · [**Limitations**](#%EF%B8%8F-honest-limitations) · [**Contributing**](#-contributing)

</div>

---

## 📖 About

Watching something "together" with friends usually means three separate apps and someone counting down *"3… 2… 1… play!"* over Discord. **SIMUL** is one room that does all of it: the video stays in sync automatically, you can talk over it, share your screen with sound, react live, and settle an argument with a game of Connect 4 — without ever leaving the room.

Built as a single Flutter codebase running natively on **six platforms**, backed by Firebase and LiveKit, and released under the **MIT license**.

---

## 🌟 Why SIMUL

| | |
|---|---|
| 🆓 **No signup friction** | Anonymous auth — creating or joining a room takes seconds, no account required |
| 🔗 **Zero-setup joining** | Configure LiveKit once as the host; everyone who joins your room gets voice & screen share automatically — they never touch a settings screen |
| 📱 **Actually cross-platform** | Not a wrapped website — native builds for Web, Android, iOS, Windows, macOS, and Linux from one codebase |
| 🎯 **Built for the whole session, not just the video** | Voice, chat, reactions, and a game live *inside* the room — no tab-switching to Discord and back |
| 🔓 **Open source, MIT licensed** | Read every line, self-host it, fork it, ship your own version |
| 🛠️ **Actively hardened** | Not a weekend prototype — race conditions, Firestore security rules, and platform-specific playback bugs have been found and fixed with documented reasoning (see [CHANGELOG.md](CHANGELOG.md))|

---

## ✨ Features

| | Feature | Details |
|---|---|---|
| 🎬 | **Synced YouTube playback** | Play, pause, and seek stay in sync for everyone — converges within ~1 second |
| 🖥️ | **Screen sharing with audio** | Share a browser tab *with sound* (desktop/web) |
| 🔗 | **Share any website link** | Paste a non-YouTube URL and the whole room gets an "open" prompt |
| 🔊 | **Live voice chat** | LiveKit-powered WebRTC audio |
| 🔇 | **Per-viewer audio control** | Mute someone's shared audio just for you, without affecting anyone else |
| 💬 | **Chat & reactions** | Floating chat panel with replies and an unread badge, plus animated emoji reactions |
| 🎮 | **Connect 4** | Tap any column to join and play — no separate "join game" step |
| 🌗 | **Light / dark mode** | Theme engine with a one-tap toggle |
| 🔐 | **Zero-setup joining** | Host's LiveKit config is shared automatically; credentials are hidden from the joiner's UI |
| 📱 | **Cross-platform** | Web, Android, iOS, Windows, macOS, Linux — one codebase |

---

## 📸 Screenshots

<div align="center">

<table>
<tr>
<td align="center">
<img src="docs/screenshots/auth-screen.png" width="260"/><br/>
<b>Home</b>
</td>
<td align="center">
<img src="docs/screenshots/room-screen.png" width="260"/><br/>
<b>Room</b>
</td>
<td align="center">
<img src="docs/screenshots/room-share.png" width="260"/><br/>
<b>Screen Share</b>
</td>
</tr>
<tr>
<td align="center">
<img src="docs/screenshots/room-code.png" width="260"/><br/>
<b>Room Code</b>
</td>
</tr>
</table>

</div>

---

## 🚀 Try it right now

No install needed — the web build is live:

### **[👉 simul-deskweb-app.web.app](https://simul-deskweb-app.web.app/)**

Open it in two tabs (or send the link to a friend), create a room in one, join with the code in the other. Firebase is already configured — you're in a shared room in seconds. Voice and screen sharing need a LiveKit project, which takes about five minutes to set up (below) — or grab the mobile/desktop build straight from [**Releases**](https://github.com/ArsalanKaleem/simul-watch-together-app/releases).

---

## 🔑 Getting your LiveKit keys (5 minutes)

LiveKit powers voice chat and screen sharing. Firebase (rooms, chat, sync, the game) is already configured for you — **LiveKit is the only thing you set up**, and you only do it once as the host; anyone who joins your room inherits it automatically.

1. **Create a free account** at **[cloud.livekit.io](https://cloud.livekit.io)** — no credit card required.
2. Click **Create Project**, give it any name (e.g. "simul").
3. In your new project, go to **Settings → Keys** → **Create Key**.
4. Copy the **API Key** and the **API Secret** — the secret is shown **once**, so copy it now.
5. Back on the project overview, copy your **WebSocket URL** — it looks like `wss://your-project-name.livekit.cloud`.
6. Open SIMUL → tap **⚙️ Settings** → paste in the **URL**, **API Key**, and **API Secret** → **Save**.

That's it. Create a room — anyone who joins gets voice and screen sharing automatically, with no setup on their end.

<details>
<summary><strong>What if I don't want to make my own LiveKit project?</strong></summary>

You don't have to — you only need one if you're **hosting** a room. If you're just **joining** someone else's room, you need nothing at all; their configuration is passed to you automatically the moment you join.
</details>

<details>
<summary><strong>LiveKit's free tier — what does it actually give you?</strong></summary>

The free **Build** plan includes roughly **5,000 participant-minutes** and **50 GB** of data transfer per month, no card required. In practice that's about **~40 hours/month of 2-person sessions** — voice-only sessions are minute-bound, screen-sharing sessions are bandwidth-bound, and both land in roughly the same range. More participants or higher quality reduces this proportionally. See [livekit.com/pricing](https://livekit.com/pricing) for current numbers.
</details>

---

## 🧱 Tech Stack

### Core
| Layer | Technology | Why |
|---|---|---|
| **UI framework** | [Flutter](https://flutter.dev) 3.x / [Dart](https://dart.dev) 3.3+ | One codebase, six platforms |
| **State management** | [provider](https://pub.dev/packages/provider) | `ChangeNotifier` services + `ProxyProvider` |
| **Realtime database** | [Cloud Firestore](https://firebase.google.com/docs/firestore) | Rooms, chat, presence, sync, game state |
| **Auth** | [Firebase Auth](https://firebase.google.com/docs/auth) (anonymous) | Zero signup friction |
| **Voice & screen share** | [LiveKit](https://livekit.io) (WebRTC SFU) | Scales past a peer-to-peer mesh |
| **Secure storage** | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | Keychain / Keystore for credentials |
| **Token minting** | [crypto](https://pub.dev/packages/crypto) (HS256 JWT) | On-device — no token server required by default |

### Video playback — a genuinely different engine per platform
YouTube's late-2025 embed enforcement (Error 153) requires every request to carry a real referrer. An in-memory/off-screen document has none, so each platform needed its own fix:

| Platform | Engine | Fix applied |
|---|---|---|
| **Web** | `<iframe>` via `HtmlElementView` + `postMessage` | `webview_flutter` has no web implementation at all — the player is a real iframe hosted in the page, with `referrerPolicy` set *before* `src` is assigned |
| **Android / iOS / macOS** | [webview_flutter](https://pub.dev/packages/webview_flutter) | `baseUrl` gives the in-memory page a real HTTPS origin, so a referrer is actually sent |
| **Windows** | [webview_windows](https://pub.dev/packages/webview_windows) (WebView2) | Served from a real **loopback HTTP server** — a `file://` URL still sends no referrer, so a `127.0.0.1` server was the only reliable fix |

### Supporting
`google_fonts` · `url_launcher` · `http` · `web` · `dart:js_interop` / `dart:ui_web`

---

## 🗺️ Architecture & Security

Two backends, deliberately handled very differently:

```
┌────────────┐   Firebase (preconfigured)   ┌──────────────┐
│  SIMUL app │ ─────────────────────────────►│ Firestore+Auth│
└─────┬──────┘   rooms · chat · sync · game   └──────────────┘
      │
      │ voice + screen share
      │ token minted on-device from keys shared by the host
      ▼
  HOST's LiveKit project (wss://…livekit.cloud)
```

**LiveKit credential sharing — how it's actually protected:** the host's URL/key/secret live in `rooms/{id}/private/config`, a **separate document** from the room itself, gated by Firestore rules:

```
match /private/{docId} {
  allow read:  if isMember() || isHost();   // room members + host only
  allow write: if isHost();                 // only the host can set it
}
```

This matters because Firestore rules are **document-level, not field-level** — putting the secret directly on the room document would make it readable by anyone who can read the room, i.e. anyone with the room code. The private subcollection blocks strangers and room-code guessers. Adopted credentials are also **hidden in the joiner's Settings UI** — shown only as *"Provided by the room host."*

**What this does *not* protect against** (stated plainly, not buried): a genuine room **member** can still extract the secret, since their client must be able to read it to connect. Closing that gap fully requires minting short-lived tokens server-side instead of sharing the raw secret — see [Limitations](#%EF%B8%8F-honest-limitations) below.

---

## 🚀 Quick Start (running it yourself)

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- A free [LiveKit Cloud](https://cloud.livekit.io) account (see the [5-minute tutorial](#-getting-your-livekit-keys-5-minutes) above)

### 1. Clone & install
```bash
git clone https://github.com/ArsalanKaleem/simul-watch-together-app.git
cd simul-watch-together-app
flutter pub get
```

### 2. Platform permissions (required for microphone access)
Mic access is an OS permission that Dart can't grant on its own — see [`docs/PLATFORM_SETUP.md`](docs/PLATFORM_SETUP.md) for the exact `AndroidManifest.xml` / `Info.plist` entries before testing voice on a phone.

### 3. Run
```bash
flutter run -d chrome     # or windows / macos / your device
```

### 4. Connect LiveKit
In the app: **⚙️ Settings** → paste your URL / Key / Secret → **Save**. Full walkthrough in the [tutorial above](#-getting-your-livekit-keys-5-minutes).

---

## 📖 Usage Guide

| Action | How |
|---|---|
| Create / join a room | Home screen — *Create Room* or *Join Room* with the 6-character code |
| Load a video | Paste a YouTube URL into the bar under the player |
| Share any website | Paste a non-YouTube link — everyone gets an "open" prompt |
| Voice chat | Tap the 🎤 icon in the top bar |
| Share screen | 🖥️ (desktop) — pick a **tab** and tick **"Share tab audio"** for sound |
| Share on mobile | Drawer → *Share a Video Link* |
| Mute shared audio (just you) | Tap the speaker icon on the share view |
| Chat | Tap the floating chat bubble, bottom-right |
| React | Reaction bar (toggle from the drawer) |
| Play Connect 4 | **Games** → *Start* → tap any column to join |
| Switch theme | Drawer → *Light/Dark Mode* |

---

## 📦 Downloads

Prebuilt binaries are attached to **[GitHub Releases](https://github.com/ArsalanKaleem/simul-watch-together-app/releases)**:

- **Android** — `.apk`, direct install (enable "install from unknown sources")
- **Windows** — `simul-setup.exe`, a proper installer with Start Menu shortcuts
- **Web** — no download needed, just open [simul-deskweb-app.web.app](https://simul-deskweb-app.web.app/)

> ⚠️ These builds are **unsigned**. Android will warn about an unknown source, and Windows SmartScreen may flag the installer as unrecognized — this is expected for an independently published open-source app, not a sign of tampering. Build from source yourself with the Quick Start above if you'd rather not click through those warnings.

---

## 📁 Project Structure

```
lib/
├── main.dart                    # entry; providers + theming
├── firebase_options.dart        # Firebase config (preconfigured)
├── screens/                     # auth, room, settings, about, splash
├── services/                    # firebase, livekit, token minting, sync, game, theme
├── widgets/                     # chat, reactions, queue, game, share viewer
└── utils/constants.dart         # theme palette + config
firestore.rules                  # security rules (member-gated private config)
docs/                            # platform setup, audit notes, screenshots
```

---

## 💻 Platform Support

| Web | Android | iOS | Windows | macOS | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |

⚠️ Linux builds and runs, but is the least-tested target — issues welcome.

---

## ⚠️ Honest Limitations

No hand-waving — here's exactly where SIMUL falls short today:

- **LiveKit secret sharing is member-gated, not fully secret.** A genuine room member can extract the host's LiveKit API secret, since their client must read it to connect. Fine for a friends-and-family deployment; **not safe for a public, multi-tenant product** without moving to server-minted tokens (a Cloud Function, not yet implemented).
- **No Firebase App Check, no rate limiting.** A determined bad actor could spam writes. Same trust boundary as above.
- **Light/dark mode doesn't cover every screen yet.** The theme engine, Settings, and About screens are fully migrated; a few others still render dark-only. [Tracked issue](docs/issues/dark-mode-support.md) — good first PR.
- **`videoSync` log grows unless pruned.** The host can delete it, but there's no automatic cleanup yet.
- **Viewer audio control is mute-only**, not a volume slider — a LiveKit Flutter SDK limitation. A web-only slider is possible but not built.
- **No automated test suite** beyond a couple of unit tests.
- **Unsigned release binaries** (see [Downloads](#-downloads)) — expect OS warnings until code-signing is set up.

If any of these matter to your use case, [`docs/AUDIT_v1.3.0.md`](docs/AUDIT_v1.3.0.md) has the full technical writeup and upgrade paths.

---

## 🗺️ Roadmap

- [ ] Server-minted LiveKit tokens (closes the member-extraction gap above)
- [ ] Firebase App Check + basic rate limiting
- [ ] Full app-wide light/dark coverage
- [ ] Automated test suite
- [ ] Web-only volume slider for shared audio
- [ ] `videoSync` auto-cleanup / TTL

---

## 🤝 Contributing

Contributions are very welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Look for
[`good first issue`](https://github.com/ArsalanKaleem/simul-watch-together-app/labels/good%20first%20issue)
labels to get started, and run `flutter analyze` before opening a PR.

---

## 👤 Author

**Arsalan Kaleem**

[![Portfolio](https://img.shields.io/badge/Portfolio-arsalankaleem.github.io-000000?style=flat-square&logo=googlechrome&logoColor=white)](https://arsalankaleem.github.io/portfolio/)
[![GitHub](https://img.shields.io/badge/GitHub-ArsalanKaleem-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/ArsalanKaleem)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-arsalankaleem-0A66C2?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/arsalankaleem)

---

## 📄 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.

<div align="center">
<br/>

### If SIMUL is useful to you, a ⭐ genuinely helps other people find it.

**[🌐 Try the live demo](https://simul-deskweb-app.web.app/) · [📦 Download a build](https://github.com/ArsalanKaleem/simul-watch-together-app/releases) · [🐛 Report a bug](https://github.com/ArsalanKaleem/simul-watch-together-app/issues)**

<sub>Built with Flutter, Firebase & LiveKit · © 2026 Arsalan Kaleem</sub>

</div>