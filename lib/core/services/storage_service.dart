import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? getToken() {
    return _prefs?.getString(AppConstants.prefUserToken);
  }

  static Future<void> saveToken(String token) async {
    await _prefs?.setString(AppConstants.prefUserToken, token.trim());
  }

  static String getRoutingMode() {
    return _prefs?.getString(AppConstants.prefRoutingMode) ?? AppConstants.routeModeSmart;
  }

  static Future<void> setRoutingMode(String mode) async {
    await _prefs?.setString(AppConstants.prefRoutingMode, mode);
  }

  static bool getAutoConnect() {
    return _prefs?.getBool(AppConstants.prefAutoConnect) ?? false;
  }

  static Future<void> setAutoConnect(bool val) async {
    await _prefs?.setBool(AppConstants.prefAutoConnect, val);
  }

  static String? getCachedConfig() {
    return _prefs?.getString(AppConstants.prefCachedConfig);
  }

  static Future<void> setCachedConfig(String jsonConfig) async {
    await _prefs?.setString(AppConstants.prefCachedConfig, jsonConfig);
  }

  static Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
