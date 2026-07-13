// lib/services/app_settings_service.dart
//
// Stores the user's LiveKit configuration in flutter_secure_storage and exposes
// it to the app. Users paste their values on the Settings screen; nothing
// LiveKit-related is baked into the repo.
//
// Two ways to get a token, in priority order:
//   1. If API key + secret are set  → the app mints join tokens ON-DEVICE
//      (no server needed). This is the recommended, zero-infra path.
//   2. Else if a Token Server URL is set → the app fetches tokens from it.
//
// If nothing is configured, we fall back to AppConfig's localhost dev defaults
// so `livekit-server --dev` + the bundled token-server still "just work".

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/constants.dart';

class AppSettingsService extends ChangeNotifier {
  static const _kUrl = 'livekit_url';
  static const _kKey = 'livekit_api_key';
  static const _kSecret = 'livekit_api_secret';
  static const _kTokenUrl = 'livekit_token_url';

  final FlutterSecureStorage _storage;

  AppSettingsService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String _url = '';
  String _apiKey = '';
  String _apiSecret = '';
  String _tokenUrl = '';
  bool _loaded = false;

  bool get isLoaded => _loaded;

  // Raw stored values (may be empty).
  String get liveKitUrlRaw => _url;
  String get apiKey => _apiKey;
  String get apiSecret => _apiSecret;
  String get tokenUrlRaw => _tokenUrl;

  /// Effective LiveKit websocket URL: what the user stored, else the dev default.
  String get liveKitUrl => _url.isNotEmpty ? _url : AppConfig.liveKitUrl;

  /// Effective token-server URL (for the server-based path).
  String get tokenUrl => _tokenUrl.isNotEmpty ? _tokenUrl : AppConfig.liveKitTokenUrl;

  /// True when we can mint tokens locally (preferred).
  bool get canMintLocally => _apiKey.isNotEmpty && _apiSecret.isNotEmpty;

  /// True when a usable configuration exists (either local minting, or a URL +
  /// token server). URL alone with dev defaults also counts for local dev.
  bool get isConfigured {
    final hasUrl = liveKitUrl.isNotEmpty;
    return hasUrl && (canMintLocally || tokenUrl.isNotEmpty);
  }

  Future<void> load() async {
    try {
      _url = (await _storage.read(key: _kUrl)) ?? '';
      _apiKey = (await _storage.read(key: _kKey)) ?? '';
      _apiSecret = (await _storage.read(key: _kSecret)) ?? '';
      _tokenUrl = (await _storage.read(key: _kTokenUrl)) ?? '';
    } catch (e) {
      debugPrint('[Settings] load failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> save({
    required String url,
    required String apiKey,
    required String apiSecret,
    String tokenUrl = '',
  }) async {
    _url = url.trim();
    _apiKey = apiKey.trim();
    _apiSecret = apiSecret.trim();
    _tokenUrl = tokenUrl.trim();
    await _storage.write(key: _kUrl, value: _url);
    await _storage.write(key: _kKey, value: _apiKey);
    await _storage.write(key: _kSecret, value: _apiSecret);
    await _storage.write(key: _kTokenUrl, value: _tokenUrl);
    notifyListeners();
  }

  Future<void> clear() async {
    _url = _apiKey = _apiSecret = _tokenUrl = '';
    await _storage.delete(key: _kUrl);
    await _storage.delete(key: _kKey);
    await _storage.delete(key: _kSecret);
    await _storage.delete(key: _kTokenUrl);
    notifyListeners();
  }
}
