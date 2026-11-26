/// Satu baris peringkat tim pada tabel klasemen liga atau fase grup.
class StandingRow {
  final String teamId;
  final String tournamentId;
  final String? groupName;
  final int position;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int points;
  final List<String> form;

  const StandingRow({
    required this.teamId,
    required this.tournamentId,
    this.groupName,
    this.position = 0,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.points = 0,
    this.form = const [],
  });

  /// Selisih gol (GD = GF - GA).
  int get goalDifference => goalsFor - goalsAgainst;

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    return StandingRow(
      teamId: json['teamId'] as String,
      tournamentId: json['tournamentId'] as String,
      groupName: json['groupName'] as String?,
      position: (json['position'] as int?) ?? 0,
      played: (json['played'] as int?) ?? 0,
      won: (json['won'] as int?) ?? 0,
      drawn: (json['drawn'] as int?) ?? 0,
      lost: (json['lost'] as int?) ?? 0,
      goalsFor: (json['goalsFor'] as int?) ?? 0,
      goalsAgainst: (json['goalsAgainst'] as int?) ?? 0,
      points: (json['points'] as int?) ?? 0,
      form: (json['form'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'tournamentId': tournamentId,
      'groupName': groupName,
      'position': position,
      'played': played,
      'won': won,
      'drawn': drawn,
      'lost': lost,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'points': points,
      'form': form,
    };
  }

  StandingRow copyWith({
    String? teamId,
    String? tournamentId,
    String? groupName,
    int? position,
    int? played,
    int? won,
    int? drawn,
    int? lost,
    int? goalsFor,
    int? goalsAgainst,
    int? points,
    List<String>? form,
  }) {
    return StandingRow(
      teamId: teamId ?? this.teamId,
      tournamentId: tournamentId ?? this.tournamentId,
      groupName: groupName ?? this.groupName,
      position: position ?? this.position,
      played: played ?? this.played,
      won: won ?? this.won,
      drawn: drawn ?? this.drawn,
      lost: lost ?? this.lost,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      points: points ?? this.points,
      form: form ?? List<String>.from(this.form),
    );
  }
}
