import 'package:shared_preferences/shared_preferences.dart';

/// Adapter penyimpanan lokal untuk Android, iOS, Desktop, dan VM test
/// menggunakan [SharedPreferences].
Future<String?> readState(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<void> writeState(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> deleteState(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
