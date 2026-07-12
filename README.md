<p align="center">
  <img src="https://raw.githubusercontent.com/ArsalanKaleemand/simul/main/assets/logo.png" alt="SIMUL Logo" width="120" height="120">
</p>

<h1 align="center">SIMUL</h1>
<p align="center">Watch together, in sync.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=Dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Firebase-%23FFCA28.svg?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/LiveKit-%2324292e.svg?style=for-the-badge&logo=livekit&logoColor=white" alt="LiveKit">
  <img src="https://img.shields.io/github/license/ArsalanKaleemand/simul?style=for-the-badge" alt="MIT License">
</p>

---

## Overview

SIMUL is a feature-rich, cross-platform co-watching application built with Flutter. It enables friends to watch YouTube videos together in perfect synchronization while simultaneously engaging through real-time voice chat, high-fidelity screen sharing with audio, live text chat, interactive emoji reactions, and turn-based multiplayer Connect 4 games within shared virtual rooms.

Engineered for ultra-low latency and seamless state synchronization, SIMUL delivers a unified digital hangout experience across mobile, desktop, and web platforms from a single codebase.

---

## Features

- 🎬 **Synchronized YouTube Playback** – Real-time state synchronization ensures play, pause, and seek actions stay perfectly aligned for every participant in the room.
- 👥 **Shared Rooms** – Easily create or join persistent or temporary watch spaces via unique, shareable room codes.
- 🔊 **Real-Time Voice Chat** – High-fidelity, low-latency spatial voice communication powered by the LiveKit WebRTC architecture.
- 🖥️ **Screen Sharing with Audio** – Broadcast your desktop view or specific browser tabs natively, complete with full system and tab audio pass-through.
- 💬 **Live Chat & Reactions** – Text communication integrated alongside animated floating emoji reactions for immediate, expressive interaction.
- 🎮 **Connect 4 Multiplayer** – An embedded, turn-based room game allowing friends to play seamlessly alongside media playback.
- 🌗 **Dynamic Theming** – Complete integration for beautifully polished, system-aware Light and Dark visual themes.
- 🌐 **True Cross-Platform Ecosystem** – Native performance and fluid execution across Android, iOS, Web, Windows, macOS, and Linux targets.

---

## Screenshots

> 🎬 Production screenshots and interactive demo GIFs coming soon.

---

## Architecture

SIMUL cleanly separates real-time structural state orchestration from intensive media streaming pipelines to guarantee horizontal scalability and high performance.

```
┌────────────────────────────────────────────────────────────────────────┐
│                              SIMUL CLIENT                               │
│         (Flutter Architecture: UI Layer ──► Provider State Provider)    │
└───────┬───────────────────────────────┬────────────────────────┬───────┘
        │                               │                        │
        │ 1. Sync & Room State          │ 2. WebRTC Media        │ 3. Mint JWT Token
        ▼                               ▼                        ▼
┌───────────────────────────────┐ ┌────────────────────────┐ ┌────────────────────┐
│       FIREBASE BACKEND        │ │   LIVEKIT CLOUD / VM   │ │   NODE.JS SERVER   │
│  (Auth, Firestore, Rules)     │ │ (Voice & Screen Share) │ │ (Secure Auth Token │
│                                │ │                        │ │   Generation)      │
└───────────────────────────────┘ └────────────────────────┘ └────────────────────┘
```

---

## Folder Structure

```
simul/
├── .github/workflows/          # Automated GitHub Actions continuous integration pipelines
├── lib/                        # Core Flutter application source workspace
│   ├── main.dart               # Project entry point, routing, and theme orchestration
│   ├── firebase_options.dart   # Client-side public Firebase identification rules
│   ├── screens/                # UI Views (Auth, Room, About, Splash screens)
│   ├── services/                # Infrastructure: Firestore, LiveKit, and Theme engines
│   ├── widgets/                 # Reusable UI elements (Chat, Reactions, Connect 4 engine)
│   └── utils/                   # Core constants, themes, and environmental parameters
├── token-server/                # Node.js backend app for secure LiveKit token generation
├── firestore.rules              # Backend security boundary definitions
└── scripts/                     # Platform execution utility automation scripts
```

---

## Getting Started

### Prerequisites

Ensure you have configured the following runtime environments locally before deploying:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable Channel)
- [Node.js](https://nodejs.org/) (v18+ recommended)
- An active [LiveKit Cloud Account](https://cloud.livekit.io) (or a validated self-hosted instance)

### Installation

1. Clone the workspace repository:
   ```bash
   git clone https://github.com/ArsalanKaleemand/simul.git
   cd simul
   ```

2. Retrieve Flutter application dependencies:
   ```bash
   flutter pub get
   ```

3. Install Node.js token server dependencies:
   ```bash
   cd token-server
   npm install
   ```

### LiveKit Setup

1. Log into your LiveKit Cloud Console.
2. Copy your project's target WebSocket URL (e.g., `wss://your-project.livekit.cloud`).
3. Navigate to **Settings > Keys** and generate a unique API Key and API Secret.

### Token Server Setup

Within the `token-server` directory, duplicate the environment configuration template:

```bash
cp .env.example .env
```

Populate `.env` with your secure LiveKit credentials:

```
LIVEKIT_API_KEY=your_livekit_api_key_here
LIVEKIT_API_SECRET=your_livekit_api_secret_here
```

---

## Running the Project

**1. Start the Token Server Locally**

```bash
cd token-server
npm start
```

**2. Execute the Client Application**

Compile and run the Flutter client targeting production environments with explicit configuration mapping variables:

```bash
flutter run -d chrome \
  --dart-define=USE_PRODUCTION=true \
  --dart-define=LIVEKIT_URL=wss://your-project.livekit.cloud \
  --dart-define=LIVEKIT_TOKEN_URL=http://localhost:5000/token
```

To configure permanent fallback defaults, modify `_liveKitUrlProd` and `_liveKitTokenUrlProd` constants within `lib/utils/constants.dart`.

---

## Firebase Configuration & Security

### Why Client Configurations Are Public By Design

This repository deliberately tracks the following client-side infrastructure metadata files:

- `lib/firebase_options.dart`
- `google-services.json`
- `GoogleService-Info.plist`

> **Note**
> In the Firebase architecture, client configuration records contain only non-sensitive identifiers (such as API keys and Project IDs) required to link the client app with cloud services. They are not server secrets, database credentials, or administrative keys.

### Backend Protection Blueprint

Security boundaries in SIMUL are strictly enforced at the database and application layers, rendering client configuration exposure non-critical:

- **Firebase Authentication:** Restricts platform interaction strictly to verified user profiles.
- **Firestore Security Rules:** Enforces fine-grained write/read operational boundaries. Users can exclusively write to metadata segments matching their validated UID or room authorization mapping.
- **Firebase App Check:** Integrated to validate incoming network payloads, ensuring requests originate exclusively from authentic, untampered instances of this application.

### Custom Backend Migration

If you prefer hosting an isolated backend infrastructure, provision a distinct Firebase application instance, execute the standard `flutterfire configure` procedure to overwrite the workspace variables, and deploy the included `firestore.rules` structure.

### Security Paradigm

To maintain optimal enterprise-grade posture throughout application execution, the following infrastructure boundaries are explicitly maintained:

- **Zero App-Layer Secrets:** Server credentials, service account certificates, and infrastructure secrets are strictly excluded from client runtimes.
- **Decoupled Secrets Pipeline:** The critical `LIVEKIT_API_SECRET` resides strictly inside the environment layer of the isolated server instance.
- **Automated Exclusions:** Local files containing sensitive data profiles (`.env`) are explicitly configured under `.gitignore` definitions to prevent accidental public disclosure tracking.

---

## Troubleshooting

Modern web browsers enforce strict media autoplay security layers. Audio channels will remain muted automatically until a user triggers an active gesture profile within the viewport. SIMUL resolves this via interactive interface flags ("Enable Sound") designed to establish direct media permissions context on client initialization.

When distributing system media through desktop screensharing, confirm you are selecting an independent browser tab context rather than a software application container, and verify the explicitly designated "Share tab audio" interactive configuration checkbox is selected.

Ensure compile targets possess complete system dependency trees. Desktop builds (Linux/Windows) require active system C++ toolchains and development headers natively configured prior to local compilations.

---

## Roadmap

- [ ] Add customizable user avatars and custom status profiles.
- [ ] Integrate additional synchronized video hosting architectures (Vimeo, Twitch, Custom HLS streams).
- [ ] Add native Picture-in-Picture (PiP) hardware support across iOS and Android operating systems.
- [ ] Introduce spatial audio algorithms for large-scale immersive environments.

---

## Contributing

Contributions are welcome. Review the standard contribution pipeline before opening modifications:

1. Fork the workspace repository.
2. Structure a dedicated functional feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your enhancements (`git commit -m 'Add some AmazingFeature'`).
4. Ensure target codebase components conform to validation checks (`flutter analyze`).
5. Push changes to the repository tracking origin (`git push origin feature/AmazingFeature`).
6. Initiate an official Pull Request.

---

## License

Distributed under the terms of the MIT Open Source License. Review `LICENSE` documentation details inside the repository root for extended usage specifications.

---

## Author

**Arsalan Kaleem**

- GitHub: [@ArsalanKaleem](https://github.com/ArsalanKaleem)
- Portfolio: [arsalankaleem.github.io/portfolio](https://arsalankaleem.github.io/portfolio)
- LinkedIn: [in/arsalankaleem](https://linkedin.com/in/arsalankaleem)