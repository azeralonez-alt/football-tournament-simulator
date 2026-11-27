import 'package:idb_shim/idb_browser.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _dbName = 'football_sim_db';
const String _storeName = 'game_state';
const int _dbVersion = 1;

Database? _cachedDb;

Future<Database?> _openDb() async {
  if (_cachedDb != null) return _cachedDb;
  final factory = idbFactoryBrowser;
  if (factory == null) return null;

  _cachedDb = await factory.open(
    _dbName,
    version: _dbVersion,
    onUpgradeNeeded: (VersionChangeEvent event) {
      final db = event.database;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    },
  );
  return _cachedDb;
}

/// Membaca JSON state dari IndexedDB pada platform Web (fallback ke SharedPreferences
/// jika browser tidak mendukung IndexedDB).
Future<String?> readState(String key) async {
  try {
    final db = await _openDb();
    if (db != null) {
      final txn = db.transaction(_storeName, idbModeReadOnly);
      final store = txn.objectStore(_storeName);
      final raw = await store.getObject(key);
      await txn.completed;
      return raw is String ? raw : null;
    }
  } catch (_) {
    // Fallback ke SharedPreferences jika IndexedDB tidak tersedia.
  }
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

/// Menulis JSON state ke IndexedDB pada platform Web tanpa batas kuota 5 MB localStorage.
Future<void> writeState(String key, String value) async {
  try {
    final db = await _openDb();
    if (db != null) {
      final txn = db.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.put(value, key);
      await txn.completed;
      return;
    }
  } catch (_) {
    // Fallback ke SharedPreferences jika IndexedDB tidak tersedia.
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

/// Menghapus entri JSON state dari IndexedDB pada platform Web.
Future<void> deleteState(String key) async {
  try {
    final db = await _openDb();
    if (db != null) {
      final txn = db.transaction(_storeName, idbModeReadWrite);
      final store = txn.objectStore(_storeName);
      await store.delete(key);
      await txn.completed;
      return;
    }
  } catch (_) {
    // Abaikan error IndexedDB dan bersihkan fallback.
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
