import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_injury.dart';
import '../models/match_game.dart';
import '../models/news_event.dart';
import '../models/season_archive.dart';
import '../models/standing_row.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import 'local_db.dart' as local_db;

/// Snapshot seluruh data aplikasi untuk penyimpanan lokal dan fitur Export/Import JSON.
class GameSaveData {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final bool isSeasonStarted;
  final int currentSeason;
  final int currentGameweek;
  final bool midSeasonTransferDone;
  final Set<int> injuryAppliedWeeks;
  final List<Team> teams;
  final List<Tournament> tournaments;
  final List<MatchGame> matches;
  final Map<String, List<StandingRow>> standingsByTournament;
  final List<NewsEvent> newsEvents;
  final List<SeasonArchive> archives;
  final Map<String, String> customTournamentNames;
  final List<ActiveInjury> activeInjuries;
  final List<MatchGame> archivedMatches;

  const GameSaveData({
    this.schemaVersion = currentSchemaVersion,
    required this.isSeasonStarted,
    required this.currentSeason,
    required this.currentGameweek,
    required this.midSeasonTransferDone,
    required this.injuryAppliedWeeks,
    required this.teams,
    required this.tournaments,
    required this.matches,
    required this.standingsByTournament,
    required this.newsEvents,
    required this.archives,
    this.customTournamentNames = const {},
    this.activeInjuries = const [],
    this.archivedMatches = const [],
  });

  factory GameSaveData.fromJson(Map<String, dynamic> json) {
    final teamsRaw = json['teams'];
    if (teamsRaw is! List) {
      throw const FormatException('Field "teams" tidak ditemukan atau tidak valid.');
    }

    final tournamentsRaw = json['tournaments'] as List<dynamic>? ?? [];
    final matchesRaw = json['matches'] as List<dynamic>? ?? [];
    final standingsRaw =
        json['standingsByTournament'] as Map<String, dynamic>? ?? {};
    final newsRaw = json['newsEvents'] as List<dynamic>? ?? [];
    final archivesRaw = json['archives'] as List<dynamic>? ?? [];
    final injuryWeeksRaw = json['injuryAppliedWeeks'] as List<dynamic>? ?? [];
    final customNamesRaw =
        json['customTournamentNames'] as Map<String, dynamic>? ?? {};
    final activeInjuriesRaw = json['activeInjuries'] as List<dynamic>? ?? [];
    final archivedMatchesRaw = json['archivedMatches'] as List<dynamic>? ?? [];

    final currentSeason = (json['currentSeason'] as num?)?.toInt() ?? 1;
    final currentGameweek =
        ((json['currentGameweek'] as num?)?.toInt() ?? 1).clamp(1, 48);

    return GameSaveData(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      isSeasonStarted: (json['isSeasonStarted'] as bool?) ?? false,
      currentSeason: currentSeason < 1 ? 1 : currentSeason,
      currentGameweek: currentGameweek,
      midSeasonTransferDone: (json['midSeasonTransferDone'] as bool?) ?? false,
      injuryAppliedWeeks: injuryWeeksRaw.map((e) => (e as num).toInt()).toSet(),
      teams: teamsRaw
          .map((e) => Team.fromJson(e as Map<String, dynamic>))
          .toList(),
      tournaments: tournamentsRaw
          .map((e) => Tournament.fromJson(e as Map<String, dynamic>))
          .toList(),
      matches: matchesRaw
          .map((e) => MatchGame.fromJson(e as Map<String, dynamic>))
          .toList(),
      standingsByTournament: standingsRaw.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ),
      newsEvents: newsRaw
          .map((e) => NewsEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      archives: archivesRaw
          .map((e) => SeasonArchive.fromJson(e as Map<String, dynamic>))
          .toList(),
      customTournamentNames: customNamesRaw.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      activeInjuries: activeInjuriesRaw
          .map((e) => ActiveInjury.fromJson(e as Map<String, dynamic>))
          .toList(),
      archivedMatches: archivedMatchesRaw
          .map((e) => MatchGame.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app': 'football_tournament_simulator',
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'isSeasonStarted': isSeasonStarted,
      'currentSeason': currentSeason,
      'currentGameweek': currentGameweek,
      'midSeasonTransferDone': midSeasonTransferDone,
      'injuryAppliedWeeks': injuryAppliedWeeks.toList()..sort(),
      'teams': teams.map((e) => e.toJson()).toList(),
      'tournaments': tournaments.map((e) => e.toJson()).toList(),
      'matches': matches.map((e) => e.toJson()).toList(),
      'standingsByTournament': standingsByTournament.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      ),
      'newsEvents': newsEvents.map((e) => e.toJson()).toList(),
      'archives': archives.map((e) => e.toJson()).toList(),
      'customTournamentNames': customTournamentNames,
      'activeInjuries': activeInjuries.map((e) => e.toJson()).toList(),
      'archivedMatches': archivedMatches.map((e) => e.toJson()).toList(),
    };
  }
}

/// Layanan penyimpanan lokal lintas platform (IndexedDB pada Web dan
/// SharedPreferences pada Android/iOS/Desktop) serta Export/Import JSON.
class StorageService {
  static const String _storageKey = 'football_sim_game_state_v1';

  /// Menyimpan seluruh state permainan ke penyimpanan lokal dalam format JSON.
  Future<void> saveGameState(GameSaveData data) async {
    final encoded = jsonEncode(data.toJson());
    await local_db.writeState(_storageKey, encoded);
  }

  /// Memuat state permainan yang tersimpan di penyimpanan lokal, atau null jika belum ada.
  ///
  /// Pada platform Web, jika data di IndexedDB masih kosong namun ditemukan
  /// simpanan lama di SharedPreferences (`localStorage`), data otomatis
  /// dimigrasikan satu kali ke IndexedDB lalu entri lama dihapus agar kuota
  /// `localStorage` bersih.
  Future<GameSaveData?> loadGameState() async {
    final raw = await local_db.readState(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      return _decodeSaveData(raw);
    }

    if (kIsWeb) {
      return _migrateLegacyWebStorageIfPresent();
    }

    return null;
  }

  GameSaveData? _decodeSaveData(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return GameSaveData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<GameSaveData?> _migrateLegacyWebStorageIfPresent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyRaw = prefs.getString(_storageKey);
      if (legacyRaw == null || legacyRaw.trim().isEmpty) return null;

      final migrated = _decodeSaveData(legacyRaw);
      if (migrated == null) return null;

      await local_db.writeState(_storageKey, legacyRaw);
      await prefs.remove(_storageKey);
      return migrated;
    } catch (_) {
      return null;
    }
  }

  /// Menghapus seluruh data simpanan lokal (untuk Reset Aplikasi).
  Future<void> clearGameState() async {
    await local_db.deleteState(_storageKey);
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
      } catch (_) {
        // Abaikan jika SharedPreferences web tidak dapat diakses.
      }
    }
  }

  /// Mengonversi [GameSaveData] menjadi string JSON terformat untuk backup.
  String serializeToJsonString(GameSaveData data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data.toJson());
  }

  /// Mengekspor data tersimpan saat ini (atau [currentData] jika disediakan) menjadi JSON string.
  Future<String> exportJsonString([GameSaveData? currentData]) async {
    if (currentData != null) {
      return serializeToJsonString(currentData);
    }

    var raw = await local_db.readState(_storageKey);
    if ((raw == null || raw.trim().isEmpty) && kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_storageKey);
    }
    if (raw == null || raw.trim().isEmpty) {
      throw StateError('Belum ada data tersimpan untuk diekspor.');
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Data lokal rusak atau tidak valid.');
    }
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(decoded);
  }

  /// Memvalidasi, mem-parsing, dan menyimpan JSON backup ke penyimpanan lokal.
  Future<GameSaveData> importJsonString(String jsonStr) async {
    final trimmed = jsonStr.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Teks JSON backup kosong.');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (e) {
      throw FormatException('Format JSON tidak valid: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON harus berupa objek map.');
    }

    final saveData = GameSaveData.fromJson(decoded);
    await saveGameState(saveData);
    return saveData;
  }
}
