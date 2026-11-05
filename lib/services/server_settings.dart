import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings kept on this device: the backend address and the AI check switch.
class ServerSettings extends ChangeNotifier {
  ServerSettings(this._prefs);

  static const _urlKey = 'server_url';
  static const _aiKey = 'ai_check';

  final SharedPreferences _prefs;

  String? get serverUrl => _prefs.getString(_urlKey);
  bool get aiCheck => _prefs.getBool(_aiKey) ?? true;

  Future<void> setServerUrl(String url) async {
    await _prefs.setString(_urlKey, url);
    notifyListeners();
  }

  Future<void> setAiCheck(bool value) async {
    await _prefs.setBool(_aiKey, value);
    notifyListeners();
  }

  Future<void> clear() async {
    await _prefs.remove(_urlKey);
    await _prefs.remove(_aiKey);
    notifyListeners();
  }
}
