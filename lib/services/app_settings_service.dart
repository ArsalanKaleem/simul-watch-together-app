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
  static const _kAdopted  = 'livekit_adopted';

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

  /// True when this config came from the room host rather than from this
  /// user. Adopted credentials are USABLE but never rendered in the UI —
  /// the joiner shouldn't be handed someone else's API secret to read,
  /// copy, or reuse outside the app.
  bool _adopted = false;
  bool get isAdopted => _adopted;

  bool get isLoaded => _loaded;

  // Values for the SETTINGS UI only. When the config was adopted from the
  // host these return empty strings, so the screen can't display or leak
  // them. Token minting uses the internal fields below instead.
  String get liveKitUrlRaw => _adopted ? '' : _url;
  String get tokenUrlRaw   => _adopted ? '' : _tokenUrl;
  String get apiKeyForUi   => _adopted ? '' : _apiKey;

  // Internal use (token minting) — never bind these to a widget.
  String get apiKey => _apiKey;
  String get apiSecret => _apiSecret;

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

  /// True only when the USER has actually entered something — unlike
  /// [isConfigured], which is effectively always true because the localhost
  /// dev fallbacks satisfy it. Audit fix: the Settings status banner and the
  /// room's auto-adopt logic both need to know "did a human configure this",
  /// not "does some fallback exist".
  bool get hasUserConfig =>
      !_adopted &&
      (_url.isNotEmpty || _apiKey.isNotEmpty || _tokenUrl.isNotEmpty);

  /// Adopts LiveKit credentials shared through a room document (the host
  /// publishes theirs so joiners are configured automatically). Only applies
  /// when this device has no user-entered config of its own, so it can never
  /// overwrite someone's deliberate setup. Returns true if adopted.
  Future<bool> adoptSharedConfig({
    required String url,
    required String apiKey,
    required String apiSecret,
  }) async {
    if (hasUserConfig) return false;
    if (url.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) return false;
    // Re-adopting the identical config is a no-op (avoids a pointless write
    // + notify on every room entry).
    if (_adopted && _url == url && _apiKey == apiKey && _apiSecret == apiSecret) {
      return false;
    }
    await save(
        url: url, apiKey: apiKey, apiSecret: apiSecret, adopted: true);
    return true;
  }

  Future<void> load() async {
    try {
      _url = (await _storage.read(key: _kUrl)) ?? '';
      _apiKey = (await _storage.read(key: _kKey)) ?? '';
      _apiSecret = (await _storage.read(key: _kSecret)) ?? '';
      _tokenUrl = (await _storage.read(key: _kTokenUrl)) ?? '';
      _adopted  = (await _storage.read(key: _kAdopted)) == '1';
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
    bool adopted = false,
  }) async {
    _adopted = adopted;
    _url = url.trim();
    _apiKey = apiKey.trim();
    _apiSecret = apiSecret.trim();
    _tokenUrl = tokenUrl.trim();
    await _storage.write(key: _kUrl, value: _url);
    await _storage.write(key: _kKey, value: _apiKey);
    await _storage.write(key: _kSecret, value: _apiSecret);
    await _storage.write(key: _kTokenUrl, value: _tokenUrl);
    await _storage.write(key: _kAdopted, value: _adopted ? '1' : '0');
    notifyListeners();
  }

  Future<void> clear() async {
    _url = _apiKey = _apiSecret = _tokenUrl = '';
    _adopted = false;
    await _storage.delete(key: _kAdopted);
    await _storage.delete(key: _kUrl);
    await _storage.delete(key: _kKey);
    await _storage.delete(key: _kSecret);
    await _storage.delete(key: _kTokenUrl);
    notifyListeners();
  }
}
