/// Representasi satu pertandingan dalam kalender terpadu (Pekan 1–48).
class MatchGame {
  final String id;
  final String tournamentId;
  final String tournamentName;
  final int seasonNumber;
  final int gameweek;
  final String stageName;
  final String? groupName;
  final String? tieId;
  final int? bracketSlot;
  final int leg;
  final bool isKnockout;
  final bool isNeutralVenue;
  final String homeTeamId;
  final String awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final int? homePenaltyScore;
  final int? awayPenaltyScore;
  final bool isFinished;
  final bool isChaoticMatch;

  const MatchGame({
    required this.id,
    required this.tournamentId,
    this.tournamentName = '',
    required this.seasonNumber,
    required this.gameweek,
    required this.stageName,
    this.groupName,
    this.tieId,
    this.bracketSlot,
    this.leg = 1,
    this.isKnockout = false,
    this.isNeutralVenue = false,
    required this.homeTeamId,
    required this.awayTeamId,
    this.homeScore,
    this.awayScore,
    this.homePenaltyScore,
    this.awayPenaltyScore,
    this.isFinished = false,
    this.isChaoticMatch = false,
  });

  bool get hasPenaltyShootout =>
      homePenaltyScore != null && awayPenaltyScore != null;

  int get totalGoals => (homeScore ?? 0) + (awayScore ?? 0);

  /// Mengembalikan ID pemenang untuk laga tunggal yang sudah selesai, atau null jika seri.
  String? get winnerTeamId {
    if (!isFinished || homeScore == null || awayScore == null) return null;
    if (homeScore! > awayScore!) return homeTeamId;
    if (awayScore! > homeScore!) return awayTeamId;
    if (hasPenaltyShootout) {
      if (homePenaltyScore! > awayPenaltyScore!) return homeTeamId;
      if (awayPenaltyScore! > homePenaltyScore!) return awayTeamId;
    }
    return null;
  }

  factory MatchGame.fromJson(Map<String, dynamic> json) {
    return MatchGame(
      id: json['id'] as String,
      tournamentId: json['tournamentId'] as String,
      tournamentName: (json['tournamentName'] as String?) ?? '',
      seasonNumber: json['seasonNumber'] as int,
      gameweek: json['gameweek'] as int,
      stageName: json['stageName'] as String,
      groupName: json['groupName'] as String?,
      tieId: json['tieId'] as String?,
      bracketSlot: json['bracketSlot'] as int?,
      leg: (json['leg'] as int?) ?? 1,
      isKnockout: (json['isKnockout'] as bool?) ?? false,
      isNeutralVenue: (json['isNeutralVenue'] as bool?) ?? false,
      homeTeamId: json['homeTeamId'] as String,
      awayTeamId: json['awayTeamId'] as String,
      homeScore: json['homeScore'] as int?,
      awayScore: json['awayScore'] as int?,
      homePenaltyScore: json['homePenaltyScore'] as int?,
      awayPenaltyScore: json['awayPenaltyScore'] as int?,
      isFinished: (json['isFinished'] as bool?) ?? false,
      isChaoticMatch: (json['isChaoticMatch'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'seasonNumber': seasonNumber,
      'gameweek': gameweek,
      'stageName': stageName,
      'groupName': groupName,
      'tieId': tieId,
      'bracketSlot': bracketSlot,
      'leg': leg,
      'isKnockout': isKnockout,
      'isNeutralVenue': isNeutralVenue,
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'homePenaltyScore': homePenaltyScore,
      'awayPenaltyScore': awayPenaltyScore,
      'isFinished': isFinished,
      'isChaoticMatch': isChaoticMatch,
    };
  }

  MatchGame copyWith({
    String? id,
    String? tournamentId,
    String? tournamentName,
    int? seasonNumber,
    int? gameweek,
    String? stageName,
    String? groupName,
    String? tieId,
    int? bracketSlot,
    int? leg,
    bool? isKnockout,
    bool? isNeutralVenue,
    String? homeTeamId,
    String? awayTeamId,
    int? homeScore,
    int? awayScore,
    int? homePenaltyScore,
    int? awayPenaltyScore,
    bool? isFinished,
    bool? isChaoticMatch,
  }) {
    return MatchGame(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      gameweek: gameweek ?? this.gameweek,
      stageName: stageName ?? this.stageName,
      groupName: groupName ?? this.groupName,
      tieId: tieId ?? this.tieId,
      bracketSlot: bracketSlot ?? this.bracketSlot,
      leg: leg ?? this.leg,
      isKnockout: isKnockout ?? this.isKnockout,
      isNeutralVenue: isNeutralVenue ?? this.isNeutralVenue,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      homePenaltyScore: homePenaltyScore ?? this.homePenaltyScore,
      awayPenaltyScore: awayPenaltyScore ?? this.awayPenaltyScore,
      isFinished: isFinished ?? this.isFinished,
      isChaoticMatch: isChaoticMatch ?? this.isChaoticMatch,
    );
  }
}
