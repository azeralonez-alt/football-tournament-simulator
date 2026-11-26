import 'dart:math';

/// Representasi cedera pemain yang sedang aktif pada sebuah klub.
///
/// [ovrPenalty] ditentukan oleh tingkat kepentingan pemain ([playerRole]),
/// sedangkan [estimatedWeeks] ditentukan oleh jenis cedera ([injuryName]).
/// [actualWeeks] menyimpan durasi sembuh sebenarnya (termasuk deviasi acak)
/// dan dirahasiakan dari tampilan sampai pemain benar-benar pulih.
class ActiveInjury {
  final String id;
  final String teamId;
  final String teamName;
  final String leagueId;
  final String playerRole;
  final String injuryName;
  final int ovrPenalty;
  final int startSeason;
  final int startWeek;
  final int estimatedWeeks;
  final int actualWeeks;
  final int weeksElapsed;

  const ActiveInjury({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.leagueId,
    required this.playerRole,
    required this.injuryName,
    required this.ovrPenalty,
    required this.startSeason,
    required this.startWeek,
    required this.estimatedWeeks,
    required this.actualWeeks,
    this.weeksElapsed = 0,
  });

  /// Estimasi sisa waktu kembali yang ditampilkan pada UI (minimal 1 pekan).
  int get remainingEstimatedWeeks => max(1, estimatedWeeks - weeksElapsed);

  /// True jika waktu pemulihan aktual sudah terpenuhi.
  bool get isRecovered => weeksElapsed >= actualWeeks;

  factory ActiveInjury.fromJson(Map<String, dynamic> json) {
    return ActiveInjury(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      teamName: (json['teamName'] as String?) ?? '',
      leagueId: (json['leagueId'] as String?) ?? '',
      playerRole: (json['playerRole'] as String?) ?? 'Pemain Inti',
      injuryName: (json['injuryName'] as String?) ?? 'Cedera Otot',
      ovrPenalty: ((json['ovrPenalty'] as num?)?.toInt() ?? 1).clamp(1, 4),
      startSeason: (json['startSeason'] as num?)?.toInt() ?? 1,
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      estimatedWeeks: max(1, (json['estimatedWeeks'] as num?)?.toInt() ?? 1),
      actualWeeks: max(1, (json['actualWeeks'] as num?)?.toInt() ?? 1),
      weeksElapsed: max(0, (json['weeksElapsed'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teamId': teamId,
      'teamName': teamName,
      'leagueId': leagueId,
      'playerRole': playerRole,
      'injuryName': injuryName,
      'ovrPenalty': ovrPenalty,
      'startSeason': startSeason,
      'startWeek': startWeek,
      'estimatedWeeks': estimatedWeeks,
      'actualWeeks': actualWeeks,
      'weeksElapsed': weeksElapsed,
    };
  }

  ActiveInjury copyWith({
    String? id,
    String? teamId,
    String? teamName,
    String? leagueId,
    String? playerRole,
    String? injuryName,
    int? ovrPenalty,
    int? startSeason,
    int? startWeek,
    int? estimatedWeeks,
    int? actualWeeks,
    int? weeksElapsed,
  }) {
    return ActiveInjury(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      leagueId: leagueId ?? this.leagueId,
      playerRole: playerRole ?? this.playerRole,
      injuryName: injuryName ?? this.injuryName,
      ovrPenalty: ovrPenalty ?? this.ovrPenalty,
      startSeason: startSeason ?? this.startSeason,
      startWeek: startWeek ?? this.startWeek,
      estimatedWeeks: estimatedWeeks ?? this.estimatedWeeks,
      actualWeeks: actualWeeks ?? this.actualWeeks,
      weeksElapsed: weeksElapsed ?? this.weeksElapsed,
    );
  }
}
