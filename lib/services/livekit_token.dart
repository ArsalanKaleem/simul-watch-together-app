// lib/services/livekit_token.dart
//
// On-device LiveKit access-token minting.
//
// LiveKit access tokens are just JWTs (HS256) signed with your API secret.
// Because each user pastes THEIR OWN LiveKit key/secret into Settings (stored
// in flutter_secure_storage on their own device), we can mint the join token
// locally and skip running a token server entirely.
//
// Token shape (per LiveKit docs):
//   header  : { "alg": "HS256", "typ": "JWT" }
//   payload : { iss: <apiKey>, sub: <identity>, name: <name>,
//               nbf: <now>, exp: <now+ttl>,
//               video: { room, roomJoin, canPublish, canSubscribe,
//                        canPublishData } }
//   signature = HMAC_SHA256(base64url(header) + "." + base64url(payload), secret)
//
// NOTE: minting locally means the API secret lives on the device. That's fine
// when it's the user's OWN key on their OWN device, but it's why we never ship
// a key in the repo and never expose it to other users.

import 'dart:convert';
import 'package:crypto/crypto.dart';

class LiveKitToken {
  /// Builds a signed LiveKit join token.
  static String mint({
    required String apiKey,
    required String apiSecret,
    required String identity,
    required String name,
    required String room,
    bool canPublish = true,
    bool canSubscribe = true,
    Duration ttl = const Duration(hours: 6),
  }) {
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      throw ArgumentError('LiveKit API key and secret are required to mint a token.');
    }
    final now = DateTime.now().toUtc();
    final nbf = now.millisecondsSinceEpoch ~/ 1000;
    final exp = now.add(ttl).millisecondsSinceEpoch ~/ 1000;

    final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'iss': apiKey,
      'sub': identity,
      'name': name,
      'nbf': nbf,
      'exp': exp,
      'video': {
        'room': room,
        'roomJoin': true,
        'canPublish': canPublish,
        'canSubscribe': canSubscribe,
        'canPublishData': true,
      },
    };

    final segments = <String>[
      _b64url(utf8.encode(json.encode(header))),
      _b64url(utf8.encode(json.encode(payload))),
    ];
    final signingInput = segments.join('.');
    final sig = Hmac(sha256, utf8.encode(apiSecret))
        .convert(utf8.encode(signingInput))
        .bytes;
    segments.add(_b64url(sig));
    return segments.join('.');
  }

  // Base64Url without padding, as required by JWT.
  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
