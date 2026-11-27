import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/active_injury.dart';
import '../models/match_game.dart';
import '../models/news_event.dart';
import '../models/season_archive.dart';
import '../models/standing_row.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../services/fixture_generator.dart';
import '../services/match_simulator.dart';
import '../services/ovr_manager.dart';
import '../services/storage_service.dart';

/// Hasil parsing daftar tim massal dari format teks `"Nama Tim, OVR"`.
class BulkTeamParseResult {
  final List<Team> teams;
  final List<String> errors;

  const BulkTeamParseResult({
    required this.teams,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Ringkasan statistik pertemuan resmi (Head-to-Head) antara dua tim.
class HeadToHeadStats {
  final String teamAId;
  final String teamBId;
  final int totalMeetings;
  final int teamAWins;
  final int draws;
  final int teamBWins;
  final int teamAGoals;
  final int teamBGoals;
  final List<MatchGame> pastMatches;

  const HeadToHeadStats({
    required this.teamAId,
    required this.teamBId,
    required this.totalMeetings,
    required this.teamAWins,
    required this.draws,
    required this.teamBWins,
    required this.teamAGoals,
    required this.teamBGoals,
    required this.pastMatches,
  });
}

/// Pengelola state utama seluruh ekosistem turnamen sepak bola (ChangeNotifier).
class GameStateProvider extends ChangeNotifier {
  static const List<String> leagueIds = [
    'liga_a',
    'liga_b',
    'liga_c',
    'liga_d',
    'liga_e',
    'liga_f',
    'liga_g',
    'liga_h',
  ];

  static const int teamsPerLeague = 20;
  static const int totalRequiredTeams = 160;
  static const int maxGameweek = 48;

  static const List<int> _defaultClubColors = [
    0xFF1D4ED8,
    0xFF00A859,
    0xFFDC2626,
    0xFFEA580C,
    0xFF7C3AED,
    0xFF0D9488,
    0xFFD97706,
    0xFF0F172A,
    0xFFBE185D,
    0xFF0369A1,
  ];

  final StorageService _storageService;
  final MatchSimulator _matchSimulator;
  final OvrManager _ovrManager;
  final FixtureGenerator _fixtureGenerator;
  final Uuid _uuid;
  final Random _random;

  bool _isInitialized = false;
  bool _isSeasonStarted = false;
  int _currentSeason = 1;
  int _currentGameweek = 1;
  bool _midSeasonTransferDone = false;
  Set<int> _injuryAppliedWeeks = {};

  List<Team> _teams = [];
  List<Tournament> _tournaments = [];
  List<MatchGame> _matches = [];
  Map<String, List<StandingRow>> _standingsByTournament = {};
  List<NewsEvent> _newsEvents = [];
  List<SeasonArchive> _archives = [];
  Map<String, String> _customTournamentNames = {};
  List<ActiveInjury> _activeInjuries = [];
  List<MatchGame> _archivedMatches = [];

  GameStateProvider({
    StorageService? storageService,
    MatchSimulator? matchSimulator,
    OvrManager? ovrManager,
    FixtureGenerator? fixtureGenerator,
    Uuid? uuid,
    Random? random,
  })  : _storageService = storageService ?? StorageService(),
        _matchSimulator = matchSimulator ?? MatchSimulator(),
        _ovrManager = ovrManager ?? OvrManager(),
        _fixtureGenerator = fixtureGenerator ?? FixtureGenerator(),
        _uuid = uuid ?? const Uuid(),
        _random = random ?? Random();

  // ===========================================================================
  // Getters State Publik
  // ===========================================================================
  bool get isInitialized => _isInitialized;
  bool get isSeasonStarted => _isSeasonStarted;
  int get currentSeason => _currentSeason;
  int get currentGameweek => _currentGameweek;
  bool get midSeasonTransferDone => _midSeasonTransferDone;

  List<Team> get teams => List.unmodifiable(_teams);
  List<Tournament> get tournaments => List.unmodifiable(_tournaments);
  List<MatchGame> get matches => List.unmodifiable(_matches);
  List<NewsEvent> get newsEvents => List.unmodifiable(_newsEvents);
  List<SeasonArchive> get archives => List.unmodifiable(_archives);
  Map<String, String> get customTournamentNames =>
      Map.unmodifiable(_customTournamentNames);
  List<ActiveInjury> get activeInjuries => List.unmodifiable(_activeInjuries);
  List<MatchGame> get archivedMatches => List.unmodifiable(_archivedMatches);

  /// Mengembalikan daftar cedera aktif milik klub tertentu ([teamId]).
  List<ActiveInjury> getActiveInjuriesForTeam(String teamId) {
    return _activeInjuries.where((i) => i.teamId == teamId).toList();
  }

  /// Mengembalikan nama liga (`liga_a`..`liga_h`) menggunakan nama kustom bila ada.
  String getLeagueName(String leagueId) {
    final custom = _customTournamentNames[leagueId]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    final idx = leagueIds.indexOf(leagueId);
    if (idx != -1) {
      return 'Liga ${String.fromCharCode(65 + idx)}';
    }
    final letter = leagueId.split('_').last.toUpperCase();
    return 'Liga $letter';
  }

  Map<String, Team> get _teamsById => {for (final t in _teams) t.id: t};

  /// Mengembalikan daftar tim pada liga tertentu (`liga_a`..`liga_h`).
  List<Team> getTeamsForLeague(String leagueId) {
    return _teams.where((t) => t.leagueId == leagueId).toList();
  }

  /// Jumlah tim valid (nama tidak kosong dan OVR 1–100) pada satu liga.
  int getValidTeamCountForLeague(String leagueId) {
    return _teams
        .where(
          (t) =>
              t.leagueId == leagueId &&
              t.name.trim().isNotEmpty &&
              t.ovr >= 1 &&
              t.ovr <= 100,
        )
        .length;
  }

  /// Apakah satu liga sudah terisi lengkap 20 tim yang valid.
  bool isLeagueReady(String leagueId) =>
      getValidTeamCountForLeague(leagueId) == teamsPerLeague;

  /// Total tim valid di seluruh 8 liga (0–160).
  int get totalValidTeamCount {
    var total = 0;
    for (final leagueId in leagueIds) {
      total += getValidTeamCountForLeague(leagueId).clamp(0, teamsPerLeague);
    }
    return total;
  }

  /// True jika seluruh 8 liga telah terisi 20 tim valid (total 160 tim).
  bool get canStartFirstSeason =>
      leagueIds.every((id) => isLeagueReady(id)) &&
      _teams.length >= totalRequiredTeams;

  /// True jika seluruh pertandingan pada pekan aktif telah selesai dimainkan.
  bool get isCurrentWeekCompleted {
    final weekMatches = getMatchesForGameweek(_currentGameweek);
    if (weekMatches.isEmpty) return true;
    return weekMatches.every((m) => m.isFinished);
  }

  /// True jika seluruh pertandingan musim berjalan sudah selesai dimainkan.
  bool get isCurrentSeasonCompleted =>
      _isSeasonStarted &&
      _matches.isNotEmpty &&
      _matches.every((m) => m.isFinished);

  Team? getTeamById(String teamId) {
    for (final team in _teams) {
      if (team.id == teamId) return team;
    }
    return null;
  }

  Tournament? getTournamentById(String tournamentId) {
    for (final tournament in _tournaments) {
      if (tournament.id == tournamentId) return tournament;
    }
    return null;
  }

  List<MatchGame> getMatchesForGameweek(int gameweek) {
    return _matches.where((m) => m.gameweek == gameweek).toList();
  }

  List<MatchGame> getMatchesForTournament(String tournamentId) {
    return _matches.where((m) => m.tournamentId == tournamentId).toList();
  }

  /// Mengembalikan seluruh pertandingan yang sudah selesai dimainkan oleh [teamId]
  /// pada musim [season] (mencakup Liga Lokal, Cup, maupun Kontinental) secara
  /// kronologis (terlama ke terbaru).
  List<MatchGame> getTeamMatchesBySeason(String teamId, int season) {
    final seenIds = <String>{};
    final result = <MatchGame>[];

    void collectFrom(List<MatchGame> source) {
      for (final m in source) {
        if (!m.isFinished || m.seasonNumber != season) continue;
        if (m.homeTeamId != teamId && m.awayTeamId != teamId) continue;
        if (seenIds.add(m.id)) {
          result.add(m);
        }
      }
    }

    collectFrom(_archivedMatches);
    collectFrom(_matches);

    result.sort((a, b) {
      final gwCmp = a.gameweek.compareTo(b.gameweek);
      if (gwCmp != 0) return gwCmp;
      final legCmp = a.leg.compareTo(b.leg);
      if (legCmp != 0) return legCmp;
      return a.tournamentName.compareTo(b.tournamentName);
    });
    return result;
  }

  /// Mengembalikan hingga [limit] pertandingan terakhir yang sudah selesai
  /// dimainkan oleh [teamId] secara kronologis (terlama ke terbaru).
  List<MatchGame> getTeamRecentMatches(String teamId, {int limit = 5}) {
    if (limit <= 0) return const [];
    final seenIds = <String>{};
    final allPlayed = <MatchGame>[];

    void collectFrom(List<MatchGame> source) {
      for (final m in source) {
        if (!m.isFinished) continue;
        if (m.homeTeamId != teamId && m.awayTeamId != teamId) continue;
        if (seenIds.add(m.id)) {
          allPlayed.add(m);
        }
      }
    }

    collectFrom(_archivedMatches);
    collectFrom(_matches);

    allPlayed.sort((a, b) {
      final seasonCmp = a.seasonNumber.compareTo(b.seasonNumber);
      if (seasonCmp != 0) return seasonCmp;
      final gwCmp = a.gameweek.compareTo(b.gameweek);
      if (gwCmp != 0) return gwCmp;
      final legCmp = a.leg.compareTo(b.leg);
      if (legCmp != 0) return legCmp;
      return a.tournamentName.compareTo(b.tournamentName);
    });

    if (allPlayed.length <= limit) return allPlayed;
    return allPlayed.sublist(allPlayed.length - limit);
  }

  /// Mengumpulkan statistik Head-to-Head antara [teamAId] dan [teamBId] dari
  /// seluruh pertandingan selesai di musim aktif maupun arsip musim lalu
  /// ([_archivedMatches]), terdeduplikasi dan diurutkan terbaru ke terlama.
  HeadToHeadStats getHeadToHeadStats(String teamAId, String teamBId) {
    final seenIds = <String>{};
    final h2hMatches = <MatchGame>[];

    void collectFrom(List<MatchGame> source) {
      for (final m in source) {
        if (!m.isFinished) continue;
        final isPair = (m.homeTeamId == teamAId && m.awayTeamId == teamBId) ||
            (m.homeTeamId == teamBId && m.awayTeamId == teamAId);
        if (!isPair) continue;
        if (seenIds.add(m.id)) {
          h2hMatches.add(m);
        }
      }
    }

    collectFrom(_matches);
    collectFrom(_archivedMatches);

    h2hMatches.sort((a, b) {
      final seasonCmp = b.seasonNumber.compareTo(a.seasonNumber);
      if (seasonCmp != 0) return seasonCmp;
      final gwCmp = b.gameweek.compareTo(a.gameweek);
      if (gwCmp != 0) return gwCmp;
      final legCmp = b.leg.compareTo(a.leg);
      if (legCmp != 0) return legCmp;
      return b.tournamentName.compareTo(a.tournamentName);
    });

    var teamAWins = 0;
    var draws = 0;
    var teamBWins = 0;
    var teamAGoals = 0;
    var teamBGoals = 0;

    for (final m in h2hMatches) {
      final homeGoals = m.homeScore ?? 0;
      final awayGoals = m.awayScore ?? 0;
      if (m.homeTeamId == teamAId) {
        teamAGoals += homeGoals;
        teamBGoals += awayGoals;
      } else {
        teamAGoals += awayGoals;
        teamBGoals += homeGoals;
      }

      final winnerId = m.winnerTeamId;
      if (winnerId == teamAId) {
        teamAWins++;
      } else if (winnerId == teamBId) {
        teamBWins++;
      } else {
        draws++;
      }
    }

    return HeadToHeadStats(
      teamAId: teamAId,
      teamBId: teamBId,
      totalMeetings: h2hMatches.length,
      teamAWins: teamAWins,
      draws: draws,
      teamBWins: teamBWins,
      teamAGoals: teamAGoals,
      teamBGoals: teamBGoals,
      pastMatches: List.unmodifiable(h2hMatches),
    );
  }

  /// Mengumpulkan seluruh berita ([NewsEvent]) yang berkaitan dengan klub
  /// [teamId] / [teamName] dari musim aktif ([_newsEvents]) maupun seluruh
  /// arsip musim sebelumnya ([_archives]), diurutkan dari terbaru ke terlama.
  List<NewsEvent> getTeamNews(String teamId, String teamName) {
    final normalizedName = teamName.trim().toLowerCase();
    final seenIds = <String>{};
    final result = <NewsEvent>[];

    void collectFrom(List<NewsEvent> source) {
      for (final e in source) {
        if (seenIds.contains(e.id)) continue;

        final hasTeamId = e.teamId != null && e.teamId!.isNotEmpty;
        final hasSecondaryTeamId =
            e.secondaryTeamId != null && e.secondaryTeamId!.isNotEmpty;
        final matchesById = (hasTeamId && e.teamId == teamId) ||
            (hasSecondaryTeamId && e.secondaryTeamId == teamId);
        final matchesByName = !hasTeamId &&
            !hasSecondaryTeamId &&
            normalizedName.isNotEmpty &&
            (e.title.toLowerCase().contains(normalizedName) ||
                e.description.toLowerCase().contains(normalizedName));

        if (matchesById || matchesByName) {
          seenIds.add(e.id);
          result.add(e);
        }
      }
    }

    collectFrom(_newsEvents);
    for (final archive in _archives) {
      collectFrom(archive.newsEvents);
    }

    result.sort((a, b) {
      final seasonCmp = b.seasonNumber.compareTo(a.seasonNumber);
      if (seasonCmp != 0) return seasonCmp;
      final gwCmp = b.gameweek.compareTo(a.gameweek);
      if (gwCmp != 0) return gwCmp;
      return b.timestamp.compareTo(a.timestamp);
    });

    return result;
  }

  /// Mengembalikan tabel klasemen untuk turnamen tertentu (opsional filter [groupName]).
  List<StandingRow> getStandings(String tournamentId, {String? groupName}) {
    final rows = _standingsByTournament[tournamentId] ?? const [];
    if (groupName == null) return List.unmodifiable(rows);
    return rows.where((r) => r.groupName == groupName).toList();
  }

  /// Menghitung probabilitas Model Davidson pra-laga untuk kartu pertandingan.
  MatchProbabilities getMatchProbabilities(MatchGame match) {
    final home = getTeamById(match.homeTeamId);
    final away = getTeamById(match.awayTeamId);
    if (home == null || away == null) {
      return const MatchProbabilities(
        homeWin: 0.34,
        draw: 0.32,
        awayWin: 0.34,
      );
    }
    return _matchSimulator.calculateProbabilities(
      homeTeam: home,
      awayTeam: away,
      isNeutralVenue: match.isNeutralVenue,
    );
  }

  // ===========================================================================
  // Inisialisasi & Navigasi Pekan
  // ===========================================================================

  /// Memuat state tersimpan dari StorageService saat aplikasi dibuka.
  Future<void> initialize() async {
    final saved = await _storageService.loadGameState();
    if (saved != null) {
      _applySaveData(saved);
      if (_isSeasonStarted && _standingsByTournament.isEmpty) {
        _recalculateAllStandings();
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  void setCurrentGameweek(int gameweek) {
    final clamped = gameweek.clamp(1, maxGameweek);
    if (clamped == _currentGameweek) return;
    _currentGameweek = clamped;
    notifyListeners();
    _persist();
  }

  // ===========================================================================
  // Setup Awal 8 Liga (Liga A–H)
  // ===========================================================================

  /// Mengatur/menyimpan daftar tim (maksimal 20) untuk satu liga saat fase Setup.
  Future<void> setLeagueTeams(String leagueId, List<Team> leagueTeams) async {
    final normalized = leagueTeams.take(teamsPerLeague).map((team) {
      final hasColor = team.colorValue != 0;
      return team.copyWith(
        leagueId: leagueId,
        ovr: team.ovr.clamp(1, 100),
        seasonOvrStart: team.ovr.clamp(1, 100),
        colorValue: hasColor ? team.colorValue : _pickRandomClubColor(),
      );
    }).toList();

    _teams.removeWhere((t) => t.leagueId == leagueId);
    _teams.addAll(normalized);

    notifyListeners();
    await _persist();
  }

  /// Mem-parsing daftar teks massal format `"Nama Tim, OVR"` per baris.
  BulkTeamParseResult parseTeamsFromBulkText(String rawText, String leagueId) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final parsedTeams = <Team>[];
    final errors = <String>[];

    for (var i = 0; i < lines.length; i++) {
      if (parsedTeams.length >= teamsPerLeague) {
        errors.add(
          'Maksimal $teamsPerLeague tim per liga. Baris ke-${i + 1} dan seterusnya diabaikan.',
        );
        break;
      }

      final line = lines[i];
      final match = RegExp(r'^(.+?)[,;|\t]\s*(\d+)\s*$').firstMatch(line);
      if (match == null) {
        errors.add(
          'Baris ${i + 1} ("$line"): format harus "Nama Tim, OVR" (contoh: Garuda FC, 85).',
        );
        continue;
      }

      final name = match.group(1)!.trim();
      final ovr = int.tryParse(match.group(2)!.trim());

      if (name.isEmpty) {
        errors.add('Baris ${i + 1}: nama tim tidak boleh kosong.');
        continue;
      }
      if (ovr == null || ovr < 1 || ovr > 100) {
        errors.add('Baris ${i + 1} ("$name"): OVR harus angka antara 1–100.');
        continue;
      }

      parsedTeams.add(
        Team(
          id: _uuid.v4(),
          name: name,
          leagueId: leagueId,
          ovr: ovr,
          seasonOvrStart: ovr,
          colorValue: _pickRandomClubColor(),
        ),
      );
    }

    return BulkTeamParseResult(teams: parsedTeams, errors: errors);
  }

  /// Mem-parsing teks massal lalu langsung menyimpannya ke [leagueId] jika valid.
  Future<BulkTeamParseResult> applyBulkTextToLeague(
    String leagueId,
    String rawText,
  ) async {
    final result = parseTeamsFromBulkText(rawText, leagueId);
    if (result.teams.isNotEmpty) {
      await setLeagueTeams(leagueId, result.teams);
    }
    return result;
  }

  // ===========================================================================
  // Edit Data Tim (Nama, OVR, Logo) Kapan Saja
  // ===========================================================================

  /// Memperbarui nama, OVR (rentang 1–100), dan logo Base64 milik tim tertentu,
  /// menyinkronkan klasemen serta salinan nama pada arsip sejarah, lalu menyimpan
  /// perubahan secara otomatis ke [StorageService].
  Future<void> updateTeam(
    String teamId, {
    required String newName,
    required int newOvr,
    String? newLogoBase64,
    bool removeLogo = false,
  }) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        newName,
        'newName',
        'Nama tim tidak boleh kosong.',
      );
    }
    if (newOvr < 1 || newOvr > 100) {
      throw RangeError.range(
        newOvr,
        1,
        100,
        'newOvr',
        'OVR harus berada pada rentang 1–100.',
      );
    }

    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx == -1) return;

    final oldTeam = _teams[idx];
    final clampedOvr = newOvr.clamp(1, 100);
    final trimmedLogo = newLogoBase64?.trim();
    final shouldClearLogo =
        removeLogo || (trimmedLogo != null && trimmedLogo.isEmpty);

    _teams[idx] = oldTeam.copyWith(
      name: trimmedName,
      ovr: clampedOvr,
      lastOvrChange: clampedOvr != oldTeam.ovr
          ? clampedOvr - oldTeam.ovr
          : oldTeam.lastOvrChange,
      logoPath: shouldClearLogo ? null : trimmedLogo,
      clearLogoPath: shouldClearLogo,
    );

    if (trimmedName != oldTeam.name) {
      _syncTeamNameInArchives(teamId, trimmedName);
      _syncTeamNameInActiveInjuries(teamId, trimmedName);
    }

    if (_isSeasonStarted) {
      _recalculateAllStandings();
    }

    notifyListeners();
    await _persist();
  }

  void _syncTeamNameInActiveInjuries(String teamId, String newName) {
    for (var i = 0; i < _activeInjuries.length; i++) {
      if (_activeInjuries[i].teamId == teamId &&
          _activeInjuries[i].teamName != newName) {
        _activeInjuries[i] = _activeInjuries[i].copyWith(teamName: newName);
      }
    }
  }

  void _syncTeamNameInArchives(String teamId, String newName) {
    if (_archives.isEmpty) return;

    _archives = _archives.map((archive) {
      var changed = false;
      final updatedChampions = <String, TournamentChampionEntry>{};

      for (final entry in archive.championsMap.entries) {
        var val = entry.value;
        if (val.championTeamId == teamId && val.championTeamName != newName) {
          val = val.copyWith(championTeamName: newName);
          changed = true;
        }
        if (val.runnerUpTeamId == teamId && val.runnerUpTeamName != newName) {
          val = val.copyWith(runnerUpTeamName: newName);
          changed = true;
        }
        updatedChampions[entry.key] = val;
      }

      var topScoring = archive.topScoringTeam;
      if (topScoring != null &&
          topScoring.teamId == teamId &&
          topScoring.teamName != newName) {
        topScoring = topScoring.copyWith(teamName: newName);
        changed = true;
      }

      var bestDefense = archive.bestDefenseTeam;
      if (bestDefense != null &&
          bestDefense.teamId == teamId &&
          bestDefense.teamName != newName) {
        bestDefense = bestDefense.copyWith(teamName: newName);
        changed = true;
      }

      if (!changed) return archive;
      return archive.copyWith(
        championsMap: updatedChampions,
        topScoringTeam: topScoring,
        bestDefenseTeam: bestDefense,
      );
    }).toList();
  }

  /// Mengubah nama Liga atau Turnamen berdasarkan [tournamentId] tanpa mengubah
  /// ID internalnya. Mendukung ID dasar saat Setup (`'liga_a'`) maupun ID
  /// turnamen musiman saat musim berjalan (`'liga_a_s1'`, `'cup_a_s1'`, `'ucl_s2'`),
  /// lalu menyinkronkan salinan nama pada MatchGame, TeamSeasonHistory,
  /// SeasonArchive, dan NewsEvent serta menyimpannya ke [StorageService].
  Future<void> renameTournament(String tournamentId, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        newName,
        'newName',
        'Nama liga/turnamen tidak boleh kosong.',
      );
    }

    var tIdx = _tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1 && leagueIds.contains(tournamentId)) {
      final targetLeagueIdx = leagueIds.indexOf(tournamentId);
      tIdx = _tournaments.indexWhere(
        (t) =>
            t.type == TournamentType.localLeague &&
            t.leagueIndex == targetLeagueIdx,
      );
    }

    final baseKey = _resolveTournamentBaseKey(
      tournamentId,
      tIdx != -1 ? _tournaments[tIdx] : null,
    );
    if (baseKey != null) {
      _customTournamentNames[baseKey] = trimmedName;
    }

    if (tIdx != -1) {
      final oldTournament = _tournaments[tIdx];
      final oldName = oldTournament.name;
      _tournaments[tIdx] = oldTournament.copyWith(name: trimmedName);

      for (var i = 0; i < _matches.length; i++) {
        final match = _matches[i];
        if (match.tournamentId == oldTournament.id &&
            match.tournamentName != trimmedName) {
          _matches[i] = match.copyWith(tournamentName: trimmedName);
        }
      }

      for (var i = 0; i < _archivedMatches.length; i++) {
        final match = _archivedMatches[i];
        if (match.tournamentId == oldTournament.id &&
            match.tournamentName != trimmedName) {
          _archivedMatches[i] = match.copyWith(tournamentName: trimmedName);
        }
      }

      if (oldTournament.type == TournamentType.localLeague &&
          oldTournament.leagueIndex != null) {
        final baseLeagueId = leagueIds[oldTournament.leagueIndex!];
        _syncTournamentNameInTeamHistory(
          seasonNumber: oldTournament.seasonNumber,
          leagueId: baseLeagueId,
          newLeagueName: trimmedName,
        );
      } else if (oldTournament.isContinental) {
        _syncTournamentNameInTeamHistory(
          seasonNumber: oldTournament.seasonNumber,
          oldContinentalName: oldName,
          newContinentalName: trimmedName,
        );
      }

      _syncTournamentNameInArchives(
        tournamentId: oldTournament.id,
        seasonNumber: oldTournament.seasonNumber,
        oldName: oldName,
        newName: trimmedName,
      );

      if (oldName != trimmedName && oldName.isNotEmpty) {
        _syncTournamentNameInNews(
          tournamentId: oldTournament.id,
          oldName: oldName,
          newName: trimmedName,
        );
      }
    }

    notifyListeners();
    await _persist();
  }

  String? _resolveTournamentBaseKey(
    String tournamentId,
    Tournament? tournament,
  ) {
    if (leagueIds.contains(tournamentId)) return tournamentId;
    if (tournament != null) {
      if (tournament.type == TournamentType.localLeague &&
          tournament.leagueIndex != null &&
          tournament.leagueIndex! < leagueIds.length) {
        return leagueIds[tournament.leagueIndex!];
      }
      if (tournament.type == TournamentType.domesticCup &&
          tournament.leagueIndex != null) {
        return 'cup_${String.fromCharCode(97 + tournament.leagueIndex!)}';
      }
    }
    if (tournamentId.startsWith('ucl_')) return 'ucl';
    if (tournamentId.startsWith('winner_')) return 'winner';
    if (tournamentId.startsWith('federation_')) return 'federation';
    if (tournamentId.startsWith('mid_range_')) return 'mid_range';
    if (tournamentId.startsWith('challenger_')) return 'challenger';
    return null;
  }

  void _syncTournamentNameInTeamHistory({
    required int seasonNumber,
    String? leagueId,
    String? newLeagueName,
    String? oldContinentalName,
    String? newContinentalName,
  }) {
    for (var i = 0; i < _teams.length; i++) {
      final team = _teams[i];
      if (team.seasonHistory.isEmpty) continue;

      var changed = false;
      final updatedHistory = team.seasonHistory.map((h) {
        if (h.seasonNumber != seasonNumber) return h;

        if (leagueId != null &&
            newLeagueName != null &&
            h.leagueId == leagueId &&
            h.leagueName != newLeagueName) {
          changed = true;
          return h.copyWith(leagueName: newLeagueName);
        }

        if (oldContinentalName != null &&
            newContinentalName != null &&
            h.continentalTournamentName == oldContinentalName) {
          changed = true;
          return h.copyWith(continentalTournamentName: newContinentalName);
        }

        return h;
      }).toList();

      if (changed) {
        _teams[i] = team.copyWith(seasonHistory: updatedHistory);
      }
    }
  }

  void _syncTournamentNameInArchives({
    required String tournamentId,
    required int seasonNumber,
    required String oldName,
    required String newName,
  }) {
    if (_archives.isEmpty) return;

    _archives = _archives.map((archive) {
      var changed = false;
      final updatedChampions = <String, TournamentChampionEntry>{};

      for (final entry in archive.championsMap.entries) {
        var val = entry.value;
        if (val.tournamentId == tournamentId && val.tournamentName != newName) {
          val = val.copyWith(tournamentName: newName);
          changed = true;
        }
        updatedChampions[entry.key] = val;
      }

      var topScoring = archive.topScoringTeam;
      if (archive.seasonNumber == seasonNumber &&
          topScoring != null &&
          topScoring.tournamentName == oldName) {
        topScoring = topScoring.copyWith(tournamentName: newName);
        changed = true;
      }

      var bestDefense = archive.bestDefenseTeam;
      if (archive.seasonNumber == seasonNumber &&
          bestDefense != null &&
          bestDefense.tournamentName == oldName) {
        bestDefense = bestDefense.copyWith(tournamentName: newName);
        changed = true;
      }

      var biggestMatch = archive.biggestScoreMatch;
      if (biggestMatch != null &&
          biggestMatch.tournamentId == tournamentId &&
          biggestMatch.tournamentName != newName) {
        biggestMatch = biggestMatch.copyWith(tournamentName: newName);
        changed = true;
      }

      if (!changed) return archive;
      return archive.copyWith(
        championsMap: updatedChampions,
        topScoringTeam: topScoring,
        bestDefenseTeam: bestDefense,
        biggestScoreMatch: biggestMatch,
      );
    }).toList();
  }

  void _syncTournamentNameInNews({
    required String tournamentId,
    required String oldName,
    required String newName,
  }) {
    for (var i = 0; i < _newsEvents.length; i++) {
      final e = _newsEvents[i];
      if (e.tournamentId == tournamentId &&
          (e.title.contains(oldName) || e.description.contains(oldName))) {
        _newsEvents[i] = e.copyWith(
          title: e.title.replaceAll(oldName, newName),
          description: e.description.replaceAll(oldName, newName),
        );
      }
    }
  }

  // ===========================================================================
  // Memulai Musim 1
  // ===========================================================================

  /// Memulai Musim 1 setelah ke-8 liga masing-masing terisi 20 tim valid.
  Future<void> startFirstSeason() async {
    if (!canStartFirstSeason) {
      throw StateError(
        'Seluruh 8 liga (masing-masing 20 tim) harus terisi lengkap sebelum memulai Musim 1.',
      );
    }

    _currentSeason = 1;
    _currentGameweek = 1;
    _isSeasonStarted = true;
    _midSeasonTransferDone = false;
    _injuryAppliedWeeks = {};
    _archives = [];
    _newsEvents = [];
    _activeInjuries = [];
    _archivedMatches = [];

    _teams = _teams
        .map(
          (t) => t.copyWith(
            lastOvrChange: 0,
            seasonOvrStart: t.ovr,
          ),
        )
        .toList();

    final bundle = _fixtureGenerator.generateSeason(
      seasonNumber: 1,
      teams: _teams,
      customTournamentNames: _customTournamentNames,
    );
    _tournaments = bundle.tournaments;
    _matches = bundle.matches;
    _recalculateAllStandings();

    _addNewsEvent(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: 1,
        gameweek: 1,
        type: NewsEventType.general,
        title: 'Musim 1 Resmi Bergulir!',
        description:
            'Sebanyak 160 klub dari Liga A hingga Liga H siap bersaing di Liga Lokal dan Cup Domestik.',
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
    await _persist();
  }

  // ===========================================================================
  // Simulasi Pertandingan & Pekan
  // ===========================================================================

  /// Mensimulasikan satu pertandingan berdasarkan [matchId], memperbarui klasemen,
  /// memicu cedera mingguan bila perlu, memajukan babak gugur, dan menjalankan
  /// Transfer Window Week 19 jika Pekan 19 selesai.
  Future<MatchGame?> simulateSingleMatch(String matchId) async {
    final idx = _matches.indexWhere((m) => m.id == matchId);
    if (idx == -1) return null;

    final targetMatch = _matches[idx];
    if (targetMatch.isFinished) return targetMatch;

    _ensureWeeklyInjuriesApplied(targetMatch.gameweek);
    final simulated = _simulateMatchAtIndex(idx);
    if (simulated == null) return null;

    _updateStandingsForTournament(simulated.tournamentId);
    _checkAndAdvanceTournamentRounds(simulated.tournamentId);

    if (simulated.gameweek == 19) {
      _checkAndRunMidSeasonTransferWindow();
    }

    if (simulated.gameweek == _currentGameweek && isCurrentWeekCompleted) {
      _advanceCurrentGameweekIfNeeded();
    }

    notifyListeners();
    await _persist();
    return simulated;
  }

  /// Mensimulasikan seluruh pertandingan yang belum selesai pada pekan aktif ([_currentGameweek]).
  Future<void> simulateCurrentWeek() async {
    if (!_isSeasonStarted) return;

    final gw = _currentGameweek;
    _ensureWeeklyInjuriesApplied(gw);

    final affectedTournaments = <String>{};
    for (var i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      if (m.gameweek == gw && !m.isFinished) {
        final simulated = _simulateMatchAtIndex(i);
        if (simulated != null) {
          affectedTournaments.add(simulated.tournamentId);
        }
      }
    }

    for (final tournamentId in affectedTournaments) {
      _updateStandingsForTournament(tournamentId);
      _checkAndAdvanceTournamentRounds(tournamentId);
    }

    if (gw == 19) {
      _checkAndRunMidSeasonTransferWindow();
    }

    _advanceCurrentGameweekIfNeeded();

    notifyListeners();
    await _persist();
  }

  MatchGame? _simulateMatchAtIndex(int index) {
    final match = _matches[index];
    if (match.isFinished) return match;

    final teamsMap = _teamsById;
    final home = teamsMap[match.homeTeamId];
    final away = teamsMap[match.awayTeamId];
    if (home == null || away == null) return null;

    MatchGame? firstLeg;
    if (match.isKnockout && match.leg == 2 && match.tieId != null) {
      for (final candidate in _matches) {
        if (candidate.tieId == match.tieId && candidate.leg == 1) {
          firstLeg = candidate;
          break;
        }
      }
    }

    final simulated = _matchSimulator.simulateMatch(
      match: match,
      homeTeam: home,
      awayTeam: away,
      firstLegMatch: firstLeg,
    );

    _matches[index] = simulated;

    if (simulated.isChaoticMatch) {
      _addNewsEvent(
        NewsEvent(
          id: _uuid.v4(),
          seasonNumber: _currentSeason,
          gameweek: simulated.gameweek,
          type: NewsEventType.chaoticMatch,
          title:
              'Laga Gila! ${home.name} ${simulated.homeScore}-${simulated.awayScore} ${away.name}',
          description:
              'Terjadi hujan gol pada ${simulated.tournamentName} (${simulated.stageName}).',
          tournamentId: simulated.tournamentId,
          timestamp: DateTime.now(),
        ),
      );
    }

    return simulated;
  }

  void _ensureWeeklyInjuriesApplied(int gameweek) {
    // Pekan 1 menggunakan OVR awal; cedera baru mulai berpeluang muncul sejak Pekan 2.
    if (gameweek <= 1 || _injuryAppliedWeeks.contains(gameweek)) return;

    _injuryAppliedWeeks.add(gameweek);
    final result = _ovrManager.applyWeeklyInjuries(
      teams: _teams,
      currentInjuries: _activeInjuries,
      seasonNumber: _currentSeason,
      gameweek: gameweek,
    );
    _teams = result.updatedTeams;
    _activeInjuries = result.updatedInjuries;
    for (final event in result.events) {
      _addNewsEvent(event);
    }
    if (result.events.isNotEmpty && _isSeasonStarted) {
      _recalculateAllStandings();
    }
  }

  void _advanceInjuryRecoveryStep({
    required int seasonNumber,
    required int gameweek,
  }) {
    if (_activeInjuries.isEmpty) return;

    final result = _ovrManager.advanceInjuryRecovery(
      teams: _teams,
      currentInjuries: _activeInjuries,
      seasonNumber: seasonNumber,
      gameweek: gameweek,
    );
    _teams = result.updatedTeams;
    _activeInjuries = result.updatedInjuries;
    for (final event in result.events) {
      _addNewsEvent(event);
    }
    if (result.events.isNotEmpty && _isSeasonStarted) {
      _recalculateAllStandings();
    }
  }

  void _checkAndRunMidSeasonTransferWindow() {
    if (_midSeasonTransferDone) return;
    final week19Matches = _matches.where((m) => m.gameweek == 19).toList();
    if (week19Matches.isEmpty || !week19Matches.every((m) => m.isFinished)) {
      return;
    }

    final result = _ovrManager.applyTransferWindow(
      teams: _teams,
      seasonNumber: _currentSeason,
      gameweek: 19,
      isEndOfSeason: false,
      leagueNames: _customTournamentNames,
    );
    _teams = result.updatedTeams;
    for (final event in result.events) {
      _addNewsEvent(event);
    }
    _midSeasonTransferDone = true;
    if (result.events.isNotEmpty && _isSeasonStarted) {
      _recalculateAllStandings();
    }
  }

  void _advanceCurrentGameweekIfNeeded() {
    if (_currentGameweek >= maxGameweek) return;
    if (!isCurrentWeekCompleted) return;

    final oldGw = _currentGameweek;
    var nextGw = oldGw;

    // Cari pekan berikutnya yang memiliki pertandingan agar pengguna tidak terjebak di pekan kosong.
    for (var candidate = oldGw + 1; candidate <= maxGameweek; candidate++) {
      final hasMatches = _matches.any((m) => m.gameweek == candidate);
      if (hasMatches || candidate == maxGameweek) {
        nextGw = candidate;
        break;
      }
    }

    if (nextGw > oldGw) {
      _currentGameweek = nextGw;
      for (var week = oldGw + 1; week <= nextGw; week++) {
        _advanceInjuryRecoveryStep(
          seasonNumber: _currentSeason,
          gameweek: week,
        );
      }
    }
  }

  // ===========================================================================
  // Penutupan Musim & Transisi ke Musim Berikutnya
  // ===========================================================================

  /// Mengarsipkan musim berjalan ke [SeasonArchive], memperbarui histori tim,
  /// menjalankan Transfer Window akhir musim, dan membuat seluruh jadwal musim berikutnya.
  Future<void> endSeasonAndStartNext() async {
    if (!isCurrentSeasonCompleted) {
      throw StateError(
        'Seluruh pertandingan hingga Pekan 48 harus selesai sebelum menutup musim.',
      );
    }

    final prevSeason = _currentSeason;
    final teamsMap = _teamsById;

    // 1. Kumpulkan klasemen akhir Liga A–H (kunci base leagueId: 'liga_a'..'liga_h').
    final previousLeagueStandings = <String, List<StandingRow>>{};
    for (final t in _tournaments) {
      if (t.type == TournamentType.localLeague && t.leagueIndex != null) {
        final baseId = leagueIds[t.leagueIndex!];
        previousLeagueStandings[baseId] = getStandings(t.id);
      }
    }

    // 2. Bangun SeasonArchive musim berjalan.
    final archive = _buildSeasonArchive(
      seasonNumber: prevSeason,
      teamsMap: teamsMap,
      leagueStandingsByBaseId: previousLeagueStandings,
    );
    _archives.add(archive);

    // 3. Rekam histori performa musim ini ke dalam masing-masing objek Team.
    _teams = _recordSeasonHistoryOnTeams(
      seasonNumber: prevSeason,
      leagueStandingsByBaseId: previousLeagueStandings,
    );

    // 4. Jalankan Transfer Window akhir musim untuk musim baru.
    final nextSeason = prevSeason + 1;
    final transferResult = _ovrManager.applyTransferWindow(
      teams: _teams,
      seasonNumber: nextSeason,
      gameweek: 0,
      isEndOfSeason: true,
      leagueNames: _customTournamentNames,
    );
    _teams = transferResult.updatedTeams;

    // 5. Bangun turnamen & jadwal baru (termasuk 8 Cup & 5 Turnamen Kontinental).
    final nextBundle = _fixtureGenerator.generateSeason(
      seasonNumber: nextSeason,
      teams: _teams,
      previousSeasonLeagueStandings: previousLeagueStandings,
      customTournamentNames: _customTournamentNames,
    );

    // Arsipkan seluruh pertandingan selesai dari musim yang baru berakhir.
    final archivedIds = _archivedMatches.map((m) => m.id).toSet();
    for (final m in _matches) {
      if (m.isFinished && archivedIds.add(m.id)) {
        _archivedMatches.add(m);
      }
    }

    _currentSeason = nextSeason;
    _currentGameweek = 1;
    _midSeasonTransferDone = false;
    _injuryAppliedWeeks = {};
    _tournaments = nextBundle.tournaments;
    _matches = nextBundle.matches;
    _newsEvents = List<NewsEvent>.from(transferResult.events);
    _advanceInjuryRecoveryStep(
      seasonNumber: nextSeason,
      gameweek: 1,
    );
    _recalculateAllStandings();

    _addNewsEvent(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: nextSeason,
        gameweek: 1,
        type: NewsEventType.general,
        title: 'Musim $nextSeason Dimulai!',
        description:
            'Seluruh 14 turnamen (Liga Lokal, Cup Domestik, dan 5 Turnamen Kontinental) siap digelar.',
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
    await _persist();
  }

  // ===========================================================================
  // Export / Import Backup & Reset
  // ===========================================================================

  Future<String> exportJsonString() async {
    return _storageService.serializeToJsonString(_buildSaveData());
  }

  Future<void> importJsonString(String jsonStr) async {
    final loaded = await _storageService.importJsonString(jsonStr);
    _applySaveData(loaded);
    if (_isSeasonStarted && _standingsByTournament.isEmpty) {
      _recalculateAllStandings();
    }
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await _storageService.clearGameState();
    _isSeasonStarted = false;
    _currentSeason = 1;
    _currentGameweek = 1;
    _midSeasonTransferDone = false;
    _injuryAppliedWeeks = {};
    _teams = [];
    _tournaments = [];
    _matches = [];
    _standingsByTournament = {};
    _newsEvents = [];
    _archives = [];
    _customTournamentNames = {};
    _activeInjuries = [];
    _archivedMatches = [];
    notifyListeners();
  }

  // ===========================================================================
  // Helper Klasemen, Progresi Babak Gugur, & Arsip
  // ===========================================================================

  void _recalculateAllStandings() {
    _standingsByTournament = {};
    for (final t in _tournaments) {
      _updateStandingsForTournament(t.id);
    }
  }

  void _updateStandingsForTournament(String tournamentId) {
    final tournament = getTournamentById(tournamentId);
    if (tournament == null || !tournament.isActive) return;

    if (tournament.type == TournamentType.domesticCup) {
      return;
    }

    final teamsMap = _teamsById;
    if (tournament.type == TournamentType.continentalGroup) {
      final combined = <StandingRow>[];
      for (final entry in tournament.potsOrGroups.entries) {
        final groupRows = _fixtureGenerator.calculateStandings(
          tournamentId: tournament.id,
          teamIds: entry.value,
          matches: _matches,
          teamsById: teamsMap,
          groupName: entry.key,
        );
        combined.addAll(groupRows);
      }
      _standingsByTournament[tournament.id] = combined;
    } else {
      _standingsByTournament[tournament.id] =
          _fixtureGenerator.calculateStandings(
        tournamentId: tournament.id,
        teamIds: tournament.teamIds,
        matches: _matches,
        teamsById: teamsMap,
      );
    }
  }

  void _checkAndAdvanceTournamentRounds(String tournamentId) {
    final tIdx = _tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return;

    final tournament = _tournaments[tIdx];
    if (!tournament.isActive) return;

    switch (tournament.type) {
      case TournamentType.localLeague:
        _advanceLocalLeague(tIdx);
      case TournamentType.domesticCup:
        _advanceDomesticCup(tIdx);
      case TournamentType.continentalLeague:
        _advanceContinentalLeague(tIdx);
      case TournamentType.continentalGroup:
        _advanceContinentalGroup(tIdx);
    }
  }

  void _advanceLocalLeague(int tIdx) {
    final tournament = _tournaments[tIdx];
    final leagueMatches = getMatchesForTournament(tournament.id);
    if (leagueMatches.isEmpty) return;

    if (leagueMatches.every((m) => m.isFinished)) {
      if (tournament.championTeamId != null) return;
      final standings = getStandings(tournament.id);
      if (standings.length < 2) return;

      final championId = standings[0].teamId;
      final runnerUpId = standings[1].teamId;

      _tournaments[tIdx] = tournament.copyWith(
        currentStage: 'Selesai',
        championTeamId: championId,
        runnerUpTeamId: runnerUpId,
      );
      _awardTrophy(
        teamId: championId,
        trophyKey: 'local_league',
        tournament: _tournaments[tIdx],
      );
      return;
    }

    // Perbarui label pekan berjalan Liga Lokal.
    final unfinished = leagueMatches.where((m) => !m.isFinished).toList()
      ..sort((a, b) => a.gameweek.compareTo(b.gameweek));
    if (unfinished.isNotEmpty) {
      _tournaments[tIdx] = tournament.copyWith(
        currentStage: unfinished.first.stageName,
      );
    }
  }

  void _advanceDomesticCup(int tIdx) {
    final tournament = _tournaments[tIdx];
    final cupMatches = getMatchesForTournament(tournament.id);

    const stages = [
      (
        current: '16 Besar',
        next: 'Perempat Final',
        nextGw: FixtureGenerator.cupQuarterFinalGameweek,
      ),
      (
        current: 'Perempat Final',
        next: 'Semifinal',
        nextGw: FixtureGenerator.cupSemiFinalGameweek,
      ),
      (
        current: 'Semifinal',
        next: 'Final',
        nextGw: FixtureGenerator.cupFinalGameweek,
      ),
    ];

    for (final stage in stages) {
      final currentMatches = cupMatches
          .where((m) => m.stageName == stage.current)
          .toList()
        ..sort((a, b) => (a.bracketSlot ?? 0).compareTo(b.bracketSlot ?? 0));
      final nextExists = cupMatches.any((m) => m.stageName == stage.next);

      if (currentMatches.isNotEmpty &&
          !nextExists &&
          currentMatches.every((m) => m.isFinished)) {
        final winners = currentMatches
            .map((m) => m.winnerTeamId)
            .whereType<String>()
            .toList();
        if (winners.length < 2) return;

        final newMatches = _fixtureGenerator.generateSingleLegKnockoutRound(
          tournamentId: tournament.id,
          tournamentName: tournament.name,
          seasonNumber: tournament.seasonNumber,
          gameweek: stage.nextGw,
          stageName: stage.next,
          teamIds: winners,
        );
        _matches.addAll(newMatches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: stage.next);
        return;
      }
    }

    // Cek Final Cup Domestik
    final finalMatches =
        cupMatches.where((m) => m.stageName == 'Final').toList();
    if (finalMatches.isNotEmpty &&
        finalMatches.first.isFinished &&
        tournament.championTeamId == null) {
      final finalMatch = finalMatches.first;
      final championId = finalMatch.winnerTeamId;
      if (championId == null) return;
      final runnerUpId = championId == finalMatch.homeTeamId
          ? finalMatch.awayTeamId
          : finalMatch.homeTeamId;

      _tournaments[tIdx] = tournament.copyWith(
        currentStage: 'Selesai',
        championTeamId: championId,
        runnerUpTeamId: runnerUpId,
      );
      _awardTrophy(
        teamId: championId,
        trophyKey: 'domestic_cup',
        tournament: _tournaments[tIdx],
      );
    }
  }

  void _advanceContinentalLeague(int tIdx) {
    final tournament = _tournaments[tIdx];
    final tMatches = getMatchesForTournament(tournament.id);

    // 1. League Phase -> Play-off (Rank 9–24)
    final leaguePhaseMatches = tMatches.where((m) => !m.isKnockout).toList();
    final playoffExists =
        tMatches.any((m) => m.stageName.startsWith('Play-off'));

    if (leaguePhaseMatches.isNotEmpty &&
        !playoffExists &&
        leaguePhaseMatches.every((m) => m.isFinished)) {
      final standings = getStandings(tournament.id);
      final playoffMatches = _fixtureGenerator.generateContinentalPlayoffRound(
        tournament: tournament,
        standings: standings,
      );
      if (playoffMatches.isNotEmpty) {
        _matches.addAll(playoffMatches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: 'Play-off');
      }
      return;
    }

    // 2. Play-off -> 16 Besar (Top 8 + 8 pemenang Play-off)
    final playoffMatches =
        tMatches.where((m) => m.stageName.startsWith('Play-off')).toList();
    final r16Exists = tMatches.any((m) => m.stageName.startsWith('16 Besar'));

    if (playoffMatches.isNotEmpty &&
        !r16Exists &&
        playoffMatches.every((m) => m.isFinished)) {
      final winners = _resolveTwoLegStageWinners(playoffMatches);
      final standings = getStandings(tournament.id);
      final r16Matches = _fixtureGenerator.generateLeaguePhaseRound16(
        tournament: tournament,
        standings: standings,
        playoffWinners: winners,
      );
      if (r16Matches.isNotEmpty) {
        _matches.addAll(r16Matches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: '16 Besar');
      }
      return;
    }

    // 3. 16 Besar -> QF -> SF -> Final
    _advanceContinentalKnockoutStages(tIdx);
  }

  void _advanceContinentalGroup(int tIdx) {
    // Karena Peringkat 3 Mid Range turun ke 16 Besar Challenger,
    // evaluasi transisi Fase Grup untuk kedua turnamen grup secara terkoordinasi.
    _tryStartGroupRound16(
      tournamentId: 'mid_range_s$_currentSeason',
      isChallenger: false,
    );
    _tryStartGroupRound16(
      tournamentId: 'challenger_s$_currentSeason',
      isChallenger: true,
    );

    _advanceContinentalKnockoutStages(tIdx);
  }

  void _tryStartGroupRound16({
    required String tournamentId,
    required bool isChallenger,
  }) {
    final tIdx = _tournaments.indexWhere((t) => t.id == tournamentId);
    if (tIdx == -1) return;

    final tournament = _tournaments[tIdx];
    final tMatches = getMatchesForTournament(tournament.id);
    final groupMatches = tMatches.where((m) => !m.isKnockout).toList();
    final r16Exists = tMatches.any((m) => m.stageName.startsWith('16 Besar'));

    if (groupMatches.isEmpty ||
        r16Exists ||
        !groupMatches.every((m) => m.isFinished)) {
      return;
    }

    if (!isChallenger) {
      // Mid Range: Rank 1 vs Rank 2 tiap grup
      final rank1s = <String>[];
      final rank2s = <String>[];
      for (final groupName in tournament.potsOrGroups.keys) {
        final rows = getStandings(tournament.id, groupName: groupName);
        if (rows.length >= 2) {
          rank1s.add(rows[0].teamId);
          rank2s.add(rows[1].teamId);
        }
      }
      if (rank1s.length == 8 && rank2s.length == 8) {
        final r16Matches = _fixtureGenerator.generateGroupPhaseRound16(
          tournament: tournament,
          seededTeamIds: rank1s,
          unseededTeamIds: rank2s,
        );
        _matches.addAll(r16Matches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: '16 Besar');
      }
    } else {
      // Challenger: Juara grup Challenger vs Peringkat 3 grup Mid Range
      final midRangeId = 'mid_range_s$_currentSeason';
      final midRange = getTournamentById(midRangeId);
      if (midRange == null) return;
      final midRangeGroupMatches = getMatchesForTournament(midRangeId)
          .where((m) => !m.isKnockout)
          .toList();
      if (midRangeGroupMatches.isEmpty ||
          !midRangeGroupMatches.every((m) => m.isFinished)) {
        return;
      }

      final challengerRank1s = <String>[];
      for (final groupName in tournament.potsOrGroups.keys) {
        final rows = getStandings(tournament.id, groupName: groupName);
        if (rows.isNotEmpty) {
          challengerRank1s.add(rows[0].teamId);
        }
      }

      final midRangeRank3s = <String>[];
      for (final groupName in midRange.potsOrGroups.keys) {
        final rows = getStandings(midRangeId, groupName: groupName);
        if (rows.length >= 3) {
          midRangeRank3s.add(rows[2].teamId);
        }
      }

      if (challengerRank1s.length == 8 && midRangeRank3s.length == 8) {
        final r16Matches = _fixtureGenerator.generateGroupPhaseRound16(
          tournament: tournament,
          seededTeamIds: challengerRank1s,
          unseededTeamIds: midRangeRank3s,
        );
        _matches.addAll(r16Matches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: '16 Besar');
      }
    }
  }

  void _advanceContinentalKnockoutStages(int tIdx) {
    final tournament = _tournaments[tIdx];
    final tMatches = getMatchesForTournament(tournament.id);

    const twoLegTransitions = [
      (
        current: '16 Besar',
        next: 'Perempat Final',
        leg1Gw: FixtureGenerator.continentalQuarterFinalLeg1Gameweek,
        leg2Gw: FixtureGenerator.continentalQuarterFinalLeg2Gameweek,
      ),
      (
        current: 'Perempat Final',
        next: 'Semifinal',
        leg1Gw: FixtureGenerator.continentalSemiFinalLeg1Gameweek,
        leg2Gw: FixtureGenerator.continentalSemiFinalLeg2Gameweek,
      ),
    ];

    for (final stage in twoLegTransitions) {
      final currentMatches = tMatches
          .where((m) => m.stageName.startsWith(stage.current))
          .toList();
      final nextExists = tMatches.any((m) => m.stageName.startsWith(stage.next));

      if (currentMatches.isNotEmpty &&
          !nextExists &&
          currentMatches.every((m) => m.isFinished)) {
        final winners = _resolveTwoLegStageWinners(currentMatches);
        if (winners.length < 2) return;

        final pairings = <({String teamA, String teamB})>[
          for (var i = 0; i + 1 < winners.length; i += 2)
            (teamA: winners[i], teamB: winners[i + 1]),
        ];

        final nextMatches = _fixtureGenerator.generateTwoLegKnockoutRound(
          tournamentId: tournament.id,
          tournamentName: tournament.name,
          seasonNumber: tournament.seasonNumber,
          leg1Gameweek: stage.leg1Gw,
          leg2Gameweek: stage.leg2Gw,
          stageName: stage.next,
          pairings: pairings,
        );
        _matches.addAll(nextMatches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: stage.next);
        return;
      }
    }

    // Semifinal -> Final (1 Leg Netral)
    final sfMatches =
        tMatches.where((m) => m.stageName.startsWith('Semifinal')).toList();
    final finalExists = tMatches.any((m) => m.stageName == 'Final');
    if (sfMatches.isNotEmpty &&
        !finalExists &&
        sfMatches.every((m) => m.isFinished)) {
      final finalists = _resolveTwoLegStageWinners(sfMatches);
      if (finalists.length == 2) {
        final finalMatches = _fixtureGenerator.generateSingleLegKnockoutRound(
          tournamentId: tournament.id,
          tournamentName: tournament.name,
          seasonNumber: tournament.seasonNumber,
          gameweek: FixtureGenerator.continentalFinalGameweek,
          stageName: 'Final',
          teamIds: finalists,
        );
        _matches.addAll(finalMatches);
        _tournaments[tIdx] = tournament.copyWith(currentStage: 'Final');
        return;
      }
    }

    // Cek Final Kontinental
    final finalMatches = tMatches.where((m) => m.stageName == 'Final').toList();
    if (finalMatches.isNotEmpty &&
        finalMatches.first.isFinished &&
        tournament.championTeamId == null) {
      final finalMatch = finalMatches.first;
      final championId = finalMatch.winnerTeamId;
      if (championId == null) return;
      final runnerUpId = championId == finalMatch.homeTeamId
          ? finalMatch.awayTeamId
          : finalMatch.homeTeamId;

      _tournaments[tIdx] = tournament.copyWith(
        currentStage: 'Selesai',
        championTeamId: championId,
        runnerUpTeamId: runnerUpId,
      );
      _awardTrophy(
        teamId: championId,
        trophyKey: _continentalTrophyKey(tournament.id),
        tournament: _tournaments[tIdx],
      );
    }
  }

  List<String> _resolveTwoLegStageWinners(List<MatchGame> stageMatches) {
    final byTie = <String, List<MatchGame>>{};
    for (final m in stageMatches) {
      final key = m.tieId ?? m.id;
      byTie.putIfAbsent(key, () => []).add(m);
    }

    final sortedTies = byTie.values.toList()
      ..sort(
        (a, b) => (a.first.bracketSlot ?? 0).compareTo(b.first.bracketSlot ?? 0),
      );

    final winners = <String>[];
    for (final tieMatches in sortedTies) {
      tieMatches.sort((a, b) => a.leg.compareTo(b.leg));
      if (tieMatches.length >= 2) {
        winners.add(
          _fixtureGenerator.resolveTwoLegTieWinner(
            tieMatches[0],
            tieMatches[1],
          ),
        );
      } else if (tieMatches.length == 1 && tieMatches[0].winnerTeamId != null) {
        winners.add(tieMatches[0].winnerTeamId!);
      }
    }
    return winners;
  }

  String _continentalTrophyKey(String tournamentId) {
    if (tournamentId.startsWith('ucl_')) return 'champions_league';
    if (tournamentId.startsWith('winner_')) return 'winner_league';
    if (tournamentId.startsWith('federation_')) return 'federation_league';
    if (tournamentId.startsWith('mid_range_')) return 'mid_range_league';
    return 'challenger_league';
  }

  void _awardTrophy({
    required String teamId,
    required String trophyKey,
    required Tournament tournament,
  }) {
    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx == -1) return;

    final team = _teams[idx];
    final updatedTrophies = Map<String, int>.from(team.trophies);
    updatedTrophies[trophyKey] = (updatedTrophies[trophyKey] ?? 0) + 1;
    _teams[idx] = team.copyWith(trophies: updatedTrophies);

    _addNewsEvent(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: tournament.seasonNumber,
        gameweek: _currentGameweek,
        type: NewsEventType.tournamentResult,
        title: '${team.name} Juara ${tournament.name}!',
        description:
            '${team.name} resmi mengangkat trofi ${tournament.name} Musim ${tournament.seasonNumber}.',
        teamId: team.id,
        tournamentId: tournament.id,
        timestamp: DateTime.now(),
      ),
    );
  }

  SeasonArchive _buildSeasonArchive({
    required int seasonNumber,
    required Map<String, Team> teamsMap,
    required Map<String, List<StandingRow>> leagueStandingsByBaseId,
  }) {
    final championsMap = <String, TournamentChampionEntry>{};
    for (final t in _tournaments) {
      if (!t.isActive ||
          t.championTeamId == null ||
          t.runnerUpTeamId == null) {
        continue;
      }
      final champ = teamsMap[t.championTeamId!];
      final runner = teamsMap[t.runnerUpTeamId!];
      if (champ == null || runner == null) continue;

      championsMap[t.id] = TournamentChampionEntry(
        tournamentId: t.id,
        tournamentName: t.name,
        tournamentType: t.type,
        championTeamId: champ.id,
        championTeamName: champ.name,
        runnerUpTeamId: runner.id,
        runnerUpTeamName: runner.name,
      );
    }

    // Cari Tim Tersubur (GF terbanyak) & Pertahanan Terbaik (GA tersedikit) dari 8 Liga Lokal.
    TeamStatRecord? topScoring;
    TeamStatRecord? bestDefense;

    for (final entry in leagueStandingsByBaseId.entries) {
      final leagueName = getLeagueName(entry.key);
      for (final row in entry.value) {
        final team = teamsMap[row.teamId];
        if (team == null) continue;

        if (topScoring == null || row.goalsFor > topScoring.value) {
          topScoring = TeamStatRecord(
            teamId: team.id,
            teamName: team.name,
            tournamentName: leagueName,
            value: row.goalsFor,
            label: '${row.goalsFor} Gol',
          );
        }

        if (bestDefense == null || row.goalsAgainst < bestDefense.value) {
          bestDefense = TeamStatRecord(
            teamId: team.id,
            teamName: team.name,
            tournamentName: leagueName,
            value: row.goalsAgainst,
            label: '${row.goalsAgainst} Kebobolan',
          );
        }
      }
    }

    // Cari Pertandingan Skor Terbesar.
    MatchGame? biggestMatch;
    for (final m in _matches) {
      if (!m.isFinished) continue;
      if (biggestMatch == null) {
        biggestMatch = m;
        continue;
      }
      final currentGoals = m.totalGoals;
      final bestGoals = biggestMatch.totalGoals;
      if (currentGoals > bestGoals) {
        biggestMatch = m;
      } else if (currentGoals == bestGoals) {
        final currentMargin = ((m.homeScore ?? 0) - (m.awayScore ?? 0)).abs();
        final bestMargin =
            ((biggestMatch.homeScore ?? 0) - (biggestMatch.awayScore ?? 0))
                .abs();
        if (currentMargin > bestMargin) {
          biggestMatch = m;
        }
      }
    }

    return SeasonArchive(
      seasonNumber: seasonNumber,
      championsMap: championsMap,
      topScoringTeam: topScoring,
      bestDefenseTeam: bestDefense,
      biggestScoreMatch: biggestMatch,
      newsEvents: List<NewsEvent>.from(_newsEvents),
      archivedAt: DateTime.now(),
    );
  }

  List<Team> _recordSeasonHistoryOnTeams({
    required int seasonNumber,
    required Map<String, List<StandingRow>> leagueStandingsByBaseId,
  }) {
    final leagueRowByTeam = <String, ({String leagueName, StandingRow row})>{};
    for (final entry in leagueStandingsByBaseId.entries) {
      final leagueName = getLeagueName(entry.key);
      for (final row in entry.value) {
        leagueRowByTeam[row.teamId] = (leagueName: leagueName, row: row);
      }
    }

    final continentalTournaments =
        _tournaments.where((t) => t.isActive && t.isContinental).toList();

    return _teams.map((team) {
      final leagueInfo = leagueRowByTeam[team.id];
      final contInfo = _resolveContinentalAchievement(
        team.id,
        continentalTournaments,
      );

      final historyEntry = TeamSeasonHistory(
        seasonNumber: seasonNumber,
        leagueId: team.leagueId,
        leagueName: leagueInfo?.leagueName ?? team.leagueId,
        leagueRank: leagueInfo?.row.position ?? 0,
        continentalTournamentName: contInfo?.tournamentName,
        continentalAchievement: contInfo?.achievement,
        matchesPlayed: leagueInfo?.row.played ?? 0,
        goalsFor: leagueInfo?.row.goalsFor ?? 0,
        goalsAgainst: leagueInfo?.row.goalsAgainst ?? 0,
        ovrStart: team.seasonOvrStart,
        ovrEnd: team.ovr,
      );

      return team.copyWith(
        seasonHistory: [...team.seasonHistory, historyEntry],
      );
    }).toList();
  }

  ({String tournamentName, String achievement})? _resolveContinentalAchievement(
    String teamId,
    List<Tournament> continentalTournaments,
  ) {
    // Jika tim turun dari Mid Range ke Challenger 16 Besar, tampilkan pencapaian tertinggi / akhir.
    Tournament? participated;
    for (final t in continentalTournaments.reversed) {
      final playedInTournament = t.teamIds.contains(teamId) ||
          _matches.any(
            (m) =>
                m.tournamentId == t.id &&
                (m.homeTeamId == teamId || m.awayTeamId == teamId),
          );
      if (playedInTournament) {
        participated = t;
        break;
      }
    }
    if (participated == null) return null;

    if (participated.championTeamId == teamId) {
      return (tournamentName: participated.name, achievement: 'Juara');
    }
    if (participated.runnerUpTeamId == teamId) {
      return (tournamentName: participated.name, achievement: 'Runner-up');
    }

    final teamMatches = _matches
        .where(
          (m) =>
              m.tournamentId == participated!.id &&
              (m.homeTeamId == teamId || m.awayTeamId == teamId),
        )
        .toList();

    String achievement = participated.type == TournamentType.continentalLeague
        ? 'League Phase'
        : 'Fase Grup';
    if (teamMatches.any((m) => m.stageName.startsWith('Semifinal'))) {
      achievement = 'Semifinal';
    } else if (teamMatches.any((m) => m.stageName.startsWith('Perempat Final'))) {
      achievement = 'Perempat Final';
    } else if (teamMatches.any((m) => m.stageName.startsWith('16 Besar'))) {
      achievement = '16 Besar';
    } else if (teamMatches.any((m) => m.stageName.startsWith('Play-off'))) {
      achievement = 'Play-off';
    }

    return (tournamentName: participated.name, achievement: achievement);
  }

  void _addNewsEvent(NewsEvent event) {
    _newsEvents.insert(0, event);
  }

  int _pickRandomClubColor() {
    return _defaultClubColors[_random.nextInt(_defaultClubColors.length)];
  }

  GameSaveData _buildSaveData() {
    return GameSaveData(
      isSeasonStarted: _isSeasonStarted,
      currentSeason: _currentSeason,
      currentGameweek: _currentGameweek,
      midSeasonTransferDone: _midSeasonTransferDone,
      injuryAppliedWeeks: Set<int>.from(_injuryAppliedWeeks),
      teams: _teams,
      tournaments: _tournaments,
      matches: _matches,
      standingsByTournament: _standingsByTournament,
      newsEvents: _newsEvents,
      archives: _archives,
      customTournamentNames: _customTournamentNames,
      activeInjuries: _activeInjuries,
      archivedMatches: _archivedMatches,
    );
  }

  void _applySaveData(GameSaveData data) {
    _isSeasonStarted = data.isSeasonStarted;
    _currentSeason = data.currentSeason;
    _currentGameweek = data.currentGameweek;
    _midSeasonTransferDone = data.midSeasonTransferDone;
    _injuryAppliedWeeks = Set<int>.from(data.injuryAppliedWeeks);
    _teams = List<Team>.from(data.teams);
    _tournaments = List<Tournament>.from(data.tournaments);
    _matches = List<MatchGame>.from(data.matches);
    _standingsByTournament = data.standingsByTournament.map(
      (k, v) => MapEntry(k, List<StandingRow>.from(v)),
    );
    _newsEvents = List<NewsEvent>.from(data.newsEvents);
    _archives = List<SeasonArchive>.from(data.archives);
    _customTournamentNames = Map<String, String>.from(
      data.customTournamentNames,
    );
    _activeInjuries = List<ActiveInjury>.from(data.activeInjuries);
    _archivedMatches = List<MatchGame>.from(data.archivedMatches);
  }

  Future<void> _persist() async {
    await _storageService.saveGameState(_buildSaveData());
  }
}
