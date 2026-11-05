import '../firebase/crashlytics_service.dart';
import '../services/api_client.dart';
import '../services/device_actions.dart';
import '../services/server_settings.dart';
import 'base_view_model.dart';

enum ConnectStatus { idle, empty, testing, connected, failed }

class ConnectViewModel extends BaseViewModel {
  ConnectViewModel({
    required this._api,
    required ServerSettings settings,
    required this._device,
    required this._crashlytics,
  }) : _settings = settings,
       _url = settings.serverUrl ?? '';

  final ApiClient _api;
  final ServerSettings _settings;
  final DeviceActions _device;
  final CrashlyticsService _crashlytics;

  String _url;
  ConnectStatus _status = ConnectStatus.idle;
  ApiFailure? _failure;
  int? _latencyMs;

  String get url => _url;
  ConnectStatus get status => _status;
  ApiFailure? get failure => _failure;
  int? get latencyMs => _latencyMs;

  /// Saving is only possible after a successful test.
  bool get canSave => _status == ConnectStatus.connected;

  /// Adds http:// when missing, since Tailscale addresses are plain HTTP.
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.contains('://')) url = 'http://$url';
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  void setUrl(String value) {
    if (value == _url) return;
    _url = value;
    _status = ConnectStatus.idle;
    _failure = null;
    _latencyMs = null;
    notifyListeners();
  }

  Future<String?> paste() async {
    final text = await _device.paste();
    if (text != null) setUrl(text.trim());
    return text?.trim();
  }

  Future<void> test() async {
    final url = normalize(_url);
    if (url.isEmpty) {
      _status = ConnectStatus.empty;
      notifyListeners();
      return;
    }
    _status = ConnectStatus.testing;
    _failure = null;
    notifyListeners();
    try {
      if (Uri.tryParse(url)?.host.isEmpty ?? true) {
        throw const ApiException(ApiFailure.unreachable);
      }
      _latencyMs = await _api.health(url);
      _status = ConnectStatus.connected;
      await _crashlytics.setKey('server_reachable', true);
    } on ApiException catch (error) {
      _failure = error.failure;
      _status = ConnectStatus.failed;
      await _crashlytics.setKey('server_reachable', false);
    }
    notifyListeners();
  }

  Future<void> save() async {
    if (!canSave) return;
    await _settings.setServerUrl(normalize(_url));
  }
}
