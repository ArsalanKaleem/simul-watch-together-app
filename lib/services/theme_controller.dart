import 'package:flutter/material.dart';

/// Drives light / dark / system theme for the whole app.
///
/// Provided at the top of the widget tree (see main.dart) and consumed by
/// MaterialApp's `themeMode`. Call [toggle] from any button to flip between
/// light and dark.
///
/// PERSISTENCE (optional): this keeps the choice in memory only, so it resets
/// on a cold start. To remember it across launches, add `shared_preferences`
/// to pubspec.yaml and:
///   1. `final _prefs = await SharedPreferences.getInstance();`
///   2. load `_prefs.getString('themeMode')` in an async `load()` at startup
///   3. save it inside [setMode].
class ThemeController extends ChangeNotifier {
  ThemeMode _mode;

  ThemeController({ThemeMode initial = ThemeMode.dark}) : _mode = initial;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    // TODO(persistence): _prefs.setString('themeMode', mode.name);
  }

  /// Flip between light and dark. If currently following the system, this
  /// resolves against [platformBrightness] first so the flip feels correct.
  void toggle([Brightness? platformBrightness]) {
    switch (_mode) {
      case ThemeMode.light:
        setMode(ThemeMode.dark);
      case ThemeMode.dark:
        setMode(ThemeMode.light);
      case ThemeMode.system:
        setMode(platformBrightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark);
    }
  }
}
