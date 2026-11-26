import 'match_game.dart';
import 'news_event.dart';
import 'tournament.dart';

/// Ringkasan juara dan runner-up satu turnamen pada suatu musim.
class TournamentChampionEntry {
  final String tournamentId;
  final String tournamentName;
  final TournamentType tournamentType;
  final String championTeamId;
  final String championTeamName;
  final String runnerUpTeamId;
  final String runnerUpTeamName;

  const TournamentChampionEntry({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentType,
    required this.championTeamId,
    required this.championTeamName,
    required this.runnerUpTeamId,
    required this.runnerUpTeamName,
  });

  factory TournamentChampionEntry.fromJson(Map<String, dynamic> json) {
    return TournamentChampionEntry(
      tournamentId: json['tournamentId'] as String,
      tournamentName: json['tournamentName'] as String,
      tournamentType: TournamentType.fromJson(json['tournamentType'] as String),
      championTeamId: json['championTeamId'] as String,
      championTeamName: json['championTeamName'] as String,
      runnerUpTeamId: json['runnerUpTeamId'] as String,
      runnerUpTeamName: json['runnerUpTeamName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'tournamentType': tournamentType.toJson(),
      'championTeamId': championTeamId,
      'championTeamName': championTeamName,
      'runnerUpTeamId': runnerUpTeamId,
      'runnerUpTeamName': runnerUpTeamName,
    };
  }

  TournamentChampionEntry copyWith({
    String? tournamentId,
    String? tournamentName,
    TournamentType? tournamentType,
    String? championTeamId,
    String? championTeamName,
    String? runnerUpTeamId,
    String? runnerUpTeamName,
  }) {
    return TournamentChampionEntry(
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      tournamentType: tournamentType ?? this.tournamentType,
      championTeamId: championTeamId ?? this.championTeamId,
      championTeamName: championTeamName ?? this.championTeamName,
      runnerUpTeamId: runnerUpTeamId ?? this.runnerUpTeamId,
      runnerUpTeamName: runnerUpTeamName ?? this.runnerUpTeamName,
    );
  }
}

/// Rekor statistik tim dalam satu musim (misal Tim Tersubur / Pertahanan Terbaik).
class TeamStatRecord {
  final String teamId;
  final String teamName;
  final String? tournamentName;
  final int value;
  final String label;

  const TeamStatRecord({
    required this.teamId,
    required this.teamName,
    this.tournamentName,
    required this.value,
    required this.label,
  });

  factory TeamStatRecord.fromJson(Map<String, dynamic> json) {
    return TeamStatRecord(
      teamId: json['teamId'] as String,
      teamName: json['teamName'] as String,
      tournamentName: json['tournamentName'] as String?,
      value: json['value'] as int,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'tournamentName': tournamentName,
      'value': value,
      'label': label,
    };
  }

  TeamStatRecord copyWith({
    String? teamId,
    String? teamName,
    String? tournamentName,
    int? value,
    String? label,
  }) {
    return TeamStatRecord(
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      tournamentName: tournamentName ?? this.tournamentName,
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }
}

/// Arsip sejarah lengkap untuk satu musim yang telah selesai.
class SeasonArchive {
  final int seasonNumber;
  final Map<String, TournamentChampionEntry> championsMap;
  final TeamStatRecord? topScoringTeam;
  final TeamStatRecord? bestDefenseTeam;
  final MatchGame? biggestScoreMatch;
  final List<NewsEvent> newsEvents;
  final DateTime archivedAt;

  const SeasonArchive({
    required this.seasonNumber,
    this.championsMap = const {},
    this.topScoringTeam,
    this.bestDefenseTeam,
    this.biggestScoreMatch,
    this.newsEvents = const [],
    required this.archivedAt,
  });

  List<TournamentChampionEntry> get championsList =>
      championsMap.values.toList();

  factory SeasonArchive.fromJson(Map<String, dynamic> json) {
    final championsRaw = json['championsMap'] as Map<String, dynamic>? ?? {};
    final eventsRaw = json['newsEvents'] as List<dynamic>? ?? [];

    return SeasonArchive(
      seasonNumber: json['seasonNumber'] as int,
      championsMap: championsRaw.map(
        (key, value) => MapEntry(
          key,
          TournamentChampionEntry.fromJson(value as Map<String, dynamic>),
        ),
      ),
      topScoringTeam: json['topScoringTeam'] != null
          ? TeamStatRecord.fromJson(
              json['topScoringTeam'] as Map<String, dynamic>,
            )
          : null,
      bestDefenseTeam: json['bestDefenseTeam'] != null
          ? TeamStatRecord.fromJson(
              json['bestDefenseTeam'] as Map<String, dynamic>,
            )
          : null,
      biggestScoreMatch: json['biggestScoreMatch'] != null
          ? MatchGame.fromJson(
              json['biggestScoreMatch'] as Map<String, dynamic>,
            )
          : null,
      newsEvents: eventsRaw
          .map((e) => NewsEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      archivedAt: DateTime.parse(json['archivedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasonNumber': seasonNumber,
      'championsMap': championsMap.map((k, v) => MapEntry(k, v.toJson())),
      'topScoringTeam': topScoringTeam?.toJson(),
      'bestDefenseTeam': bestDefenseTeam?.toJson(),
      'biggestScoreMatch': biggestScoreMatch?.toJson(),
      'newsEvents': newsEvents.map((e) => e.toJson()).toList(),
      'archivedAt': archivedAt.toIso8601String(),
    };
  }

  SeasonArchive copyWith({
    int? seasonNumber,
    Map<String, TournamentChampionEntry>? championsMap,
    TeamStatRecord? topScoringTeam,
    TeamStatRecord? bestDefenseTeam,
    MatchGame? biggestScoreMatch,
    List<NewsEvent>? newsEvents,
    DateTime? archivedAt,
  }) {
    return SeasonArchive(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      championsMap: championsMap ??
          Map<String, TournamentChampionEntry>.from(this.championsMap),
      topScoringTeam: topScoringTeam ?? this.topScoringTeam,
      bestDefenseTeam: bestDefenseTeam ?? this.bestDefenseTeam,
      biggestScoreMatch: biggestScoreMatch ?? this.biggestScoreMatch,
      newsEvents: newsEvents ?? List<NewsEvent>.from(this.newsEvents),
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
