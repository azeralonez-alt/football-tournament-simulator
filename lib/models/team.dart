/// Riwayat performa tim pada satu musim tertentu.
class TeamSeasonHistory {
  final int seasonNumber;
  final String leagueId;
  final String leagueName;
  final int leagueRank;
  final String? continentalTournamentName;
  final String? continentalAchievement;
  final int matchesPlayed;
  final int goalsFor;
  final int goalsAgainst;
  final int ovrStart;
  final int ovrEnd;

  const TeamSeasonHistory({
    required this.seasonNumber,
    required this.leagueId,
    required this.leagueName,
    required this.leagueRank,
    this.continentalTournamentName,
    this.continentalAchievement,
    required this.matchesPlayed,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.ovrStart,
    required this.ovrEnd,
  });

  double get avgGoalsFor =>
      matchesPlayed > 0 ? goalsFor / matchesPlayed : 0.0;

  double get avgGoalsAgainst =>
      matchesPlayed > 0 ? goalsAgainst / matchesPlayed : 0.0;

  factory TeamSeasonHistory.fromJson(Map<String, dynamic> json) {
    return TeamSeasonHistory(
      seasonNumber: json['seasonNumber'] as int,
      leagueId: json['leagueId'] as String,
      leagueName: json['leagueName'] as String,
      leagueRank: json['leagueRank'] as int,
      continentalTournamentName: json['continentalTournamentName'] as String?,
      continentalAchievement: json['continentalAchievement'] as String?,
      matchesPlayed: (json['matchesPlayed'] as int?) ?? 0,
      goalsFor: (json['goalsFor'] as int?) ?? 0,
      goalsAgainst: (json['goalsAgainst'] as int?) ?? 0,
      ovrStart: (json['ovrStart'] as int?) ?? 70,
      ovrEnd: (json['ovrEnd'] as int?) ?? 70,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasonNumber': seasonNumber,
      'leagueId': leagueId,
      'leagueName': leagueName,
      'leagueRank': leagueRank,
      'continentalTournamentName': continentalTournamentName,
      'continentalAchievement': continentalAchievement,
      'matchesPlayed': matchesPlayed,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'ovrStart': ovrStart,
      'ovrEnd': ovrEnd,
    };
  }

  TeamSeasonHistory copyWith({
    int? seasonNumber,
    String? leagueId,
    String? leagueName,
    int? leagueRank,
    String? continentalTournamentName,
    String? continentalAchievement,
    int? matchesPlayed,
    int? goalsFor,
    int? goalsAgainst,
    int? ovrStart,
    int? ovrEnd,
  }) {
    return TeamSeasonHistory(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      leagueId: leagueId ?? this.leagueId,
      leagueName: leagueName ?? this.leagueName,
      leagueRank: leagueRank ?? this.leagueRank,
      continentalTournamentName:
          continentalTournamentName ?? this.continentalTournamentName,
      continentalAchievement:
          continentalAchievement ?? this.continentalAchievement,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      ovrStart: ovrStart ?? this.ovrStart,
      ovrEnd: ovrEnd ?? this.ovrEnd,
    );
  }
}

/// Representasi klub sepak bola dalam ekosistem turnamen.
class Team {
  final String id;
  final String name;
  final String leagueId;
  final int ovr;
  final int lastOvrChange;
  final int seasonOvrStart;
  final String? logoPath;
  final int colorValue;
  final Map<String, int> trophies;
  final List<TeamSeasonHistory> seasonHistory;

  const Team({
    required this.id,
    required this.name,
    required this.leagueId,
    required this.ovr,
    this.lastOvrChange = 0,
    int? seasonOvrStart,
    this.logoPath,
    this.colorValue = 0xFF1D4ED8,
    this.trophies = const {},
    this.seasonHistory = const [],
  }) : seasonOvrStart = seasonOvrStart ?? ovr;

  /// Selisih OVR sejak awal musim berjalan.
  int get seasonOvrDelta => ovr - seasonOvrStart;

  /// Total seluruh trofi yang telah diraih klub.
  int get totalTrophies =>
      trophies.values.fold(0, (sum, count) => sum + count);

  /// Inisial 3 huruf untuk avatar perisai jika tidak memiliki logo khusus.
  String get initials {
    final clean = name.trim();
    if (clean.isEmpty) return 'FC';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return (parts[0][0] + parts[1][0] + parts[2][0]).toUpperCase();
    }
    if (parts.length == 2) {
      final first = parts[0][0];
      final second = parts[1].length >= 2
          ? parts[1].substring(0, 2)
          : parts[1][0];
      return (first + second).toUpperCase();
    }
    return clean.length >= 3
        ? clean.substring(0, 3).toUpperCase()
        : clean.toUpperCase();
  }

  /// Rata-rata gol dicetak per laga dari musim terakhir (untuk formula Musim 2+).
  double? get lastSeasonAvgGoalsFor =>
      seasonHistory.isNotEmpty ? seasonHistory.last.avgGoalsFor : null;

  /// Rata-rata kebobolan per laga dari musim terakhir (untuk formula Musim 2+).
  double? get lastSeasonAvgGoalsAgainst =>
      seasonHistory.isNotEmpty ? seasonHistory.last.avgGoalsAgainst : null;

  factory Team.fromJson(Map<String, dynamic> json) {
    final trophiesRaw = json['trophies'] as Map<String, dynamic>? ?? {};
    final historyRaw = json['seasonHistory'] as List<dynamic>? ?? [];
    final parsedOvr = (json['ovr'] as int).clamp(1, 100);

    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      leagueId: json['leagueId'] as String,
      ovr: parsedOvr,
      lastOvrChange: (json['lastOvrChange'] as int?) ?? 0,
      seasonOvrStart: (json['seasonOvrStart'] as int?) ?? parsedOvr,
      logoPath: (json['logoPath'] ?? json['logoBase64']) as String?,
      colorValue: (json['colorValue'] as int?) ?? 0xFF1D4ED8,
      trophies: trophiesRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      seasonHistory: historyRaw
          .map((e) => TeamSeasonHistory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'leagueId': leagueId,
      'ovr': ovr.clamp(1, 100),
      'lastOvrChange': lastOvrChange,
      'seasonOvrStart': seasonOvrStart,
      'logoPath': logoPath,
      'colorValue': colorValue,
      'trophies': trophies,
      'seasonHistory': seasonHistory.map((e) => e.toJson()).toList(),
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? leagueId,
    int? ovr,
    int? lastOvrChange,
    int? seasonOvrStart,
    String? logoPath,
    bool clearLogoPath = false,
    int? colorValue,
    Map<String, int>? trophies,
    List<TeamSeasonHistory>? seasonHistory,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      leagueId: leagueId ?? this.leagueId,
      ovr: (ovr ?? this.ovr).clamp(1, 100),
      lastOvrChange: lastOvrChange ?? this.lastOvrChange,
      seasonOvrStart: seasonOvrStart ?? this.seasonOvrStart,
      logoPath: clearLogoPath ? null : (logoPath ?? this.logoPath),
      colorValue: colorValue ?? this.colorValue,
      trophies: trophies ?? Map<String, int>.from(this.trophies),
      seasonHistory:
          seasonHistory ?? List<TeamSeasonHistory>.from(this.seasonHistory),
    );
  }
}
