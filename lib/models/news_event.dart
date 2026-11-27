/// Kategori event dalam log berita ekosistem turnamen.
enum NewsEventType {
  transferWindow,
  injury,
  chaoticMatch,
  tournamentResult,
  general;

  String toJson() => name;

  static NewsEventType fromJson(String value) {
    return NewsEventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NewsEventType.general,
    );
  }
}

/// Catatan berita atau peristiwa penting (transfer window, cedera, upset, juara).
class NewsEvent {
  final String id;
  final int seasonNumber;
  final int gameweek;
  final NewsEventType type;
  final String title;
  final String description;
  final String? teamId;
  final String? secondaryTeamId;
  final String? tournamentId;
  final String? secondaryTournamentId;
  final int? ovrDelta;
  final DateTime timestamp;

  const NewsEvent({
    required this.id,
    required this.seasonNumber,
    required this.gameweek,
    required this.type,
    required this.title,
    required this.description,
    this.teamId,
    this.secondaryTeamId,
    this.tournamentId,
    this.secondaryTournamentId,
    this.ovrDelta,
    required this.timestamp,
  });

  factory NewsEvent.fromJson(Map<String, dynamic> json) {
    return NewsEvent(
      id: json['id'] as String,
      seasonNumber: json['seasonNumber'] as int,
      gameweek: json['gameweek'] as int,
      type: NewsEventType.fromJson(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      teamId: json['teamId'] as String?,
      secondaryTeamId: json['secondaryTeamId'] as String?,
      tournamentId: json['tournamentId'] as String?,
      secondaryTournamentId: json['secondaryTournamentId'] as String?,
      ovrDelta: json['ovrDelta'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seasonNumber': seasonNumber,
      'gameweek': gameweek,
      'type': type.toJson(),
      'title': title,
      'description': description,
      'teamId': teamId,
      'secondaryTeamId': secondaryTeamId,
      'tournamentId': tournamentId,
      'secondaryTournamentId': secondaryTournamentId,
      'ovrDelta': ovrDelta,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  NewsEvent copyWith({
    String? id,
    int? seasonNumber,
    int? gameweek,
    NewsEventType? type,
    String? title,
    String? description,
    String? teamId,
    String? secondaryTeamId,
    String? tournamentId,
    String? secondaryTournamentId,
    int? ovrDelta,
    DateTime? timestamp,
  }) {
    return NewsEvent(
      id: id ?? this.id,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      gameweek: gameweek ?? this.gameweek,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      teamId: teamId ?? this.teamId,
      secondaryTeamId: secondaryTeamId ?? this.secondaryTeamId,
      tournamentId: tournamentId ?? this.tournamentId,
      secondaryTournamentId:
          secondaryTournamentId ?? this.secondaryTournamentId,
      ovrDelta: ovrDelta ?? this.ovrDelta,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
