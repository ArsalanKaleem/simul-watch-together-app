#!/usr/bin/env bash
# Fully local dev:
#   1) livekit-server --dev            # ws://localhost:7880 (devkey/secret)
#   2) flutter run -d chrome           # then in Settings enter:
#        URL=ws://localhost:7880  KEY=devkey  SECRET=secret
#   (Leaving Settings empty also falls back to these localhost defaults.)
flutter run -d chrome
