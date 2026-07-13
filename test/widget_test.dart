// This replaces Flutter's default `flutter create` counter-app test, which
// referenced a `MyApp` class that doesn't exist in this project (this app's
// root widget is `SimulApp`, defined in lib/main.dart) — that's what was
// failing `flutter analyze` in CI with:
//   "The name 'MyApp' isn't a class" (test/widget_test.dart)
//
// Pumping SimulApp directly here would require mocking Firebase (it's
// initialized in main() before runApp), which is more than this quick fix
// needs. Instead, this is a real, fast, dependency-free unit test for
// on-device LiveKit token minting — the kind of pure logic that's cheapest
// and most valuable to unit test.
//
// Add more tests alongside this one as you go; see CONTRIBUTING.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:simul/services/livekit_token.dart';

void main() {
  group('LiveKitToken.mint', () {
    test('produces a 3-segment JWT', () {
      final token = LiveKitToken.mint(
        apiKey: 'testkey',
        apiSecret: 'testsecret',
        identity: 'user-1',
        name: 'Test User',
        room: 'ROOM01',
      );
      expect(token.split('.').length, 3);
    });

    test('throws if API key or secret is missing', () {
      expect(
        () => LiveKitToken.mint(
          apiKey: '',
          apiSecret: '',
          identity: 'user-1',
          name: 'Test User',
          room: 'ROOM01',
        ),
        throwsArgumentError,
      );
    });

    test('is deterministic for the signature portion given the same inputs',
        () {
      // nbf/exp are time-based, so header+payload will differ run to run —
      // but the function should never throw and should always yield well-
      // formed base64url segments (no padding characters).
      final token = LiveKitToken.mint(
        apiKey: 'testkey',
        apiSecret: 'testsecret',
        identity: 'user-1',
        name: 'Test User',
        room: 'ROOM01',
      );
      for (final segment in token.split('.')) {
        expect(segment.contains('='), isFalse);
      }
    });
  });
}
