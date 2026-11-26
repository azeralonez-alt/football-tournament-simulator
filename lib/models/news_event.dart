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
  final String? tournamentId;
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
    this.tournamentId,
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
      tournamentId: json['tournamentId'] as String?,
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
      'tournamentId': tournamentId,
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
    String? tournamentId,
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
      tournamentId: tournamentId ?? this.tournamentId,
      ovrDelta: ovrDelta ?? this.ovrDelta,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
