/// Jenis turnamen dalam ekosistem simulator.
enum TournamentType {
  localLeague,
  domesticCup,
  continentalLeague,
  continentalGroup;

  String toJson() => name;

  static TournamentType fromJson(String value) {
    return TournamentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TournamentType.localLeague,
    );
  }
}

/// Representasi turnamen (Liga Lokal, Cup Domestik, atau Turnamen Kontinental).
class Tournament {
  final String id;
  final String name;
  final TournamentType type;
  final int seasonNumber;
  final int? leagueIndex;
  final int? tier;
  final List<String> teamIds;
  final Map<String, List<String>> potsOrGroups;
  final bool isActive;
  final String currentStage;
  final String? championTeamId;
  final String? runnerUpTeamId;

  const Tournament({
    required this.id,
    required this.name,
    required this.type,
    required this.seasonNumber,
    this.leagueIndex,
    this.tier,
    this.teamIds = const [],
    this.potsOrGroups = const {},
    this.isActive = true,
    this.currentStage = 'Belum Dimulai',
    this.championTeamId,
    this.runnerUpTeamId,
  });

  bool get isContinental =>
      type == TournamentType.continentalLeague ||
      type == TournamentType.continentalGroup;

  bool get isKnockoutOnly => type == TournamentType.domesticCup;

  factory Tournament.fromJson(Map<String, dynamic> json) {
    final potsRaw = json['potsOrGroups'] as Map<String, dynamic>? ?? {};

    return Tournament(
      id: json['id'] as String,
      name: json['name'] as String,
      type: TournamentType.fromJson(json['type'] as String),
      seasonNumber: json['seasonNumber'] as int,
      leagueIndex: json['leagueIndex'] as int?,
      tier: json['tier'] as int?,
      teamIds: (json['teamIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      potsOrGroups: potsRaw.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((e) => e as String).toList(),
        ),
      ),
      isActive: (json['isActive'] as bool?) ?? true,
      currentStage: (json['currentStage'] as String?) ?? 'Belum Dimulai',
      championTeamId: json['championTeamId'] as String?,
      runnerUpTeamId: json['runnerUpTeamId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toJson(),
      'seasonNumber': seasonNumber,
      'leagueIndex': leagueIndex,
      'tier': tier,
      'teamIds': teamIds,
      'potsOrGroups': potsOrGroups,
      'isActive': isActive,
      'currentStage': currentStage,
      'championTeamId': championTeamId,
      'runnerUpTeamId': runnerUpTeamId,
    };
  }

  Tournament copyWith({
    String? id,
    String? name,
    TournamentType? type,
    int? seasonNumber,
    int? leagueIndex,
    int? tier,
    List<String>? teamIds,
    Map<String, List<String>>? potsOrGroups,
    bool? isActive,
    String? currentStage,
    String? championTeamId,
    String? runnerUpTeamId,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      leagueIndex: leagueIndex ?? this.leagueIndex,
      tier: tier ?? this.tier,
      teamIds: teamIds ?? List<String>.from(this.teamIds),
      potsOrGroups: potsOrGroups ??
          this.potsOrGroups.map(
            (k, v) => MapEntry(k, List<String>.from(v)),
          ),
      isActive: isActive ?? this.isActive,
      currentStage: currentStage ?? this.currentStage,
      championTeamId: championTeamId ?? this.championTeamId,
      runnerUpTeamId: runnerUpTeamId ?? this.runnerUpTeamId,
    );
  }
}
