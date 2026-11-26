import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/active_injury.dart';
import '../models/news_event.dart';
import '../models/team.dart';

/// Hasil pembaruan OVR seluruh tim beserta catatan berita yang dihasilkan.
class OvrUpdateResult {
  final List<Team> updatedTeams;
  final List<NewsEvent> events;

  const OvrUpdateResult({
    required this.updatedTeams,
    required this.events,
  });
}

/// Hasil pemrosesan cedera baru maupun pemulihan cedera mingguan.
class InjuryProcessResult {
  final List<Team> updatedTeams;
  final List<ActiveInjury> updatedInjuries;
  final List<NewsEvent> events;

  const InjuryProcessResult({
    required this.updatedTeams,
    required this.updatedInjuries,
    required this.events,
  });
}

/// Pengelola dinamika Overall Rating (OVR): Transfer Window & Sistem Cedera/Pemulihan Dinamis.
class OvrManager {
  static const double injuryChancePerWeek = 0.015; // 1.5% peluang per pekan
  static const int minTeamOvrAfterInjury = 40;

  static const List<({String name, int weeks})> _shortInjuries = [
    (name: 'Memar Otot / Benturan', weeks: 1),
    (name: 'Kelelahan Otot Akut', weeks: 1),
    (name: 'Keseleo Pergelangan Kaki Ringan', weeks: 2),
    (name: 'Cedera Otot Betis Ringan', weeks: 2),
  ];

  static const List<({String name, int weeks})> _mediumInjuries = [
    (name: 'Cedera Hamstring', weeks: 3),
    (name: 'Cedera Pangkal Paha / Groin', weeks: 3),
    (name: 'Cedera Otot Paha Depan', weeks: 4),
    (name: 'Bahu Terkilir / Memar Rusuk', weeks: 4),
    (name: 'Cedera Ligamen Lutut Ringan / MCL', weeks: 5),
  ];

  static const List<({String name, int weeks})> _longInjuries = [
    (name: 'Robekan Otot Hamstring Parah', weeks: 6),
    (name: 'Cedera Meniskus Lutut', weeks: 8),
    (name: 'Patah Tulang Metatarsal', weeks: 10),
  ];

  static const List<({String name, int weeks})> _veryLongInjuries = [
    (name: 'Robek Tendon Achilles', weeks: 16),
    (name: 'Cedera Ligamen Lutut Parah / ACL', weeks: 20),
  ];

  final Random _random;
  final Uuid _uuid;

  OvrManager({Random? random, Uuid? uuid})
      : _random = random ?? Random(),
        _uuid = uuid ?? const Uuid();

  /// Menjalankan Transfer Window (setelah Week 19 atau Akhir Musim).
  ///
  /// Distribusi probabilitas sesuai PRD:
  /// - 70%: -3, -2, -1, +1, +2, +3 (masing-masing ~11.67%)
  /// - 20%: -4, 0, +4 (masing-masing ~6.67%)
  /// - 8%: -5, +5 (masing-masing 4%)
  /// - 2% (Golden Era): +6, +7, +8, +9, +10 (masing-masing 0.4%)
  OvrUpdateResult applyTransferWindow({
    required List<Team> teams,
    required int seasonNumber,
    required int gameweek,
    required bool isEndOfSeason,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final updatedTeams = <Team>[];
    final events = <NewsEvent>[];
    final windowLabel =
        isEndOfSeason ? 'Transfer Window Akhir Musim' : 'Transfer Window Tengah Musim';

    for (final team in teams) {
      final rawDelta = _rollTransferDelta();
      final newOvr = (team.ovr + rawDelta).clamp(1, 100);
      final actualDelta = newOvr - team.ovr;

      final updatedTeam = team.copyWith(
        ovr: newOvr,
        lastOvrChange: actualDelta,
        seasonOvrStart: isEndOfSeason ? newOvr : team.seasonOvrStart,
      );
      updatedTeams.add(updatedTeam);

      if (actualDelta != 0) {
        final isGoldenEra = actualDelta >= 6;
        final sign = actualDelta > 0 ? '+' : '';
        final title = isGoldenEra
            ? 'Golden Era! ${team.name} ($sign$actualDelta OVR)'
            : '$windowLabel: ${team.name} ($sign$actualDelta OVR)';
        final description = isGoldenEra
            ? '${team.name} mengalami lonjakan generasi emas di $windowLabel. OVR naik dari ${team.ovr} menjadi $newOvr.'
            : actualDelta > 0
                ? 'Rekrutan baru memperkuat ${team.name}. OVR meningkat dari ${team.ovr} menjadi $newOvr ($sign$actualDelta).'
                : 'Perubahan skuad melemahkan ${team.name}. OVR turun dari ${team.ovr} menjadi $newOvr ($actualDelta).';

        events.add(
          NewsEvent(
            id: _uuid.v4(),
            seasonNumber: seasonNumber,
            gameweek: gameweek,
            type: NewsEventType.transferWindow,
            title: title,
            description: description,
            teamId: team.id,
            tournamentId: team.leagueId,
            ovrDelta: actualDelta,
            timestamp: now,
          ),
        );
      }
    }

    return OvrUpdateResult(updatedTeams: updatedTeams, events: events);
  }

  /// Mensimulasikan peluang cedera acak (1.5% per tim) pada suatu pekan dengan
  /// dua tabel probabilitas terpisah: peran pemain (penalti OVR) & jenis cedera
  /// (estimasi durasi pekan + deviasi aktual acak).
  InjuryProcessResult applyWeeklyInjuries({
    required List<Team> teams,
    required List<ActiveInjury> currentInjuries,
    required int seasonNumber,
    required int gameweek,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final updatedTeams = <Team>[];
    final updatedInjuries = List<ActiveInjury>.from(currentInjuries);
    final events = <NewsEvent>[];

    for (final team in teams) {
      if (team.ovr <= minTeamOvrAfterInjury ||
          _random.nextDouble() >= injuryChancePerWeek) {
        updatedTeams.add(team);
        continue;
      }

      final role = _rollPlayerRole();
      final injuryType = _rollInjuryCatalog();
      final deviation = _rollRecoveryDeviation();
      final actualWeeks = max(1, injuryType.weeks + deviation);

      final newOvr = max(minTeamOvrAfterInjury, team.ovr - role.ovrPenalty);
      final appliedPenalty = team.ovr - newOvr;
      if (appliedPenalty <= 0) {
        updatedTeams.add(team);
        continue;
      }

      updatedTeams.add(
        team.copyWith(
          ovr: newOvr,
          lastOvrChange: -appliedPenalty,
        ),
      );

      updatedInjuries.add(
        ActiveInjury(
          id: _uuid.v4(),
          teamId: team.id,
          teamName: team.name,
          leagueId: team.leagueId,
          playerRole: role.role,
          injuryName: injuryType.name,
          ovrPenalty: appliedPenalty,
          startSeason: seasonNumber,
          startWeek: gameweek,
          estimatedWeeks: injuryType.weeks,
          actualWeeks: actualWeeks,
          weeksElapsed: 0,
        ),
      );

      events.add(
        NewsEvent(
          id: _uuid.v4(),
          seasonNumber: seasonNumber,
          gameweek: gameweek,
          type: NewsEventType.injury,
          title: 'Cedera ${role.role}: ${team.name} (-$appliedPenalty OVR)',
          description:
              '${role.role} ${team.name} mengalami ${injuryType.name} pada Pekan $gameweek. OVR turun dari ${team.ovr} menjadi $newOvr. Diperkirakan menepi selama ${injuryType.weeks} pekan.',
          teamId: team.id,
          tournamentId: team.leagueId,
          ovrDelta: -appliedPenalty,
          timestamp: now,
        ),
      );
    }

    return InjuryProcessResult(
      updatedTeams: updatedTeams,
      updatedInjuries: updatedInjuries,
      events: events,
    );
  }

  /// Memajukan progres pemulihan sebanyak 1 pekan untuk seluruh cedera aktif.
  /// Jika [weeksElapsed] >= [actualWeeks], OVR tim dikembalikan otomatis
  /// (maksimal 100), cedera dihapus, dan berita pemulihan ditambahkan.
  InjuryProcessResult advanceInjuryRecovery({
    required List<Team> teams,
    required List<ActiveInjury> currentInjuries,
    required int seasonNumber,
    required int gameweek,
    DateTime? timestamp,
  }) {
    if (currentInjuries.isEmpty) {
      return InjuryProcessResult(
        updatedTeams: teams,
        updatedInjuries: currentInjuries,
        events: const [],
      );
    }

    final now = timestamp ?? DateTime.now();
    final updatedTeams = List<Team>.from(teams);
    final teamIndexById = <String, int>{
      for (var i = 0; i < updatedTeams.length; i++) updatedTeams[i].id: i,
    };

    final remainingInjuries = <ActiveInjury>[];
    final events = <NewsEvent>[];

    for (final injury in currentInjuries) {
      final progressed = injury.copyWith(weeksElapsed: injury.weeksElapsed + 1);
      if (progressed.weeksElapsed < progressed.actualWeeks) {
        remainingInjuries.add(progressed);
        continue;
      }

      final tIdx = teamIndexById[progressed.teamId];
      if (tIdx != null) {
        final team = updatedTeams[tIdx];
        final restoredOvr = min(100, team.ovr + progressed.ovrPenalty);
        final actualGain = restoredOvr - team.ovr;

        updatedTeams[tIdx] = team.copyWith(
          ovr: restoredOvr,
          lastOvrChange: actualGain,
        );

        final comparisonText = _formatRecoveryComparison(
          estimatedWeeks: progressed.estimatedWeeks,
          actualWeeks: progressed.actualWeeks,
        );

        events.add(
          NewsEvent(
            id: _uuid.v4(),
            seasonNumber: seasonNumber,
            gameweek: gameweek,
            type: NewsEventType.injury,
            title:
                'Pemulihan ${progressed.playerRole}: ${team.name} (+${progressed.ovrPenalty} OVR)',
            description:
                '${progressed.playerRole} ${team.name} telah pulih dari ${progressed.injuryName}. OVR naik kembali dari ${team.ovr} menjadi $restoredOvr (+${progressed.ovrPenalty}). $comparisonText',
            teamId: team.id,
            tournamentId: team.leagueId,
            ovrDelta: progressed.ovrPenalty,
            timestamp: now,
          ),
        );
      }
    }

    return InjuryProcessResult(
      updatedTeams: updatedTeams,
      updatedInjuries: remainingInjuries,
      events: events,
    );
  }

  String _formatRecoveryComparison({
    required int estimatedWeeks,
    required int actualWeeks,
  }) {
    final diff = actualWeeks - estimatedWeeks;
    if (diff < 0) {
      return 'Pulih ${-diff} pekan lebih cepat dari perkiraan awal ($actualWeeks vs $estimatedWeeks pekan).';
    }
    if (diff > 0) {
      return 'Pemulihan molor $diff pekan lebih lama dari perkiraan awal ($actualWeeks vs $estimatedWeeks pekan).';
    }
    return 'Pulih tepat waktu sesuai perkiraan tim medis ($actualWeeks pekan).';
  }

  /// Tabel A — Tingkat Kepentingan Pemain:
  /// 45% Pemain Pelapis (-1), 35% Pemain Inti (-2), 15% Pemain Kunci (-3), 5% Pemain Bintang (-4).
  ({String role, int ovrPenalty}) _rollPlayerRole() {
    final roll = _random.nextDouble() * 100.0;
    if (roll < 45.0) return (role: 'Pemain Pelapis', ovrPenalty: 1);
    if (roll < 80.0) return (role: 'Pemain Inti', ovrPenalty: 2);
    if (roll < 95.0) return (role: 'Pemain Kunci', ovrPenalty: 3);
    return (role: 'Pemain Bintang', ovrPenalty: 4);
  }

  /// Tabel B — Katalog Jenis Cedera Sepak Bola:
  /// 50% Singkat, 32% Menengah, 13% Lama, 5% Sangat Lama.
  ({String name, int weeks}) _rollInjuryCatalog() {
    final roll = _random.nextDouble() * 100.0;
    if (roll < 50.0) {
      return _shortInjuries[_random.nextInt(_shortInjuries.length)];
    }
    if (roll < 82.0) {
      return _mediumInjuries[_random.nextInt(_mediumInjuries.length)];
    }
    if (roll < 95.0) {
      return _longInjuries[_random.nextInt(_longInjuries.length)];
    }
    return _veryLongInjuries[_random.nextInt(_veryLongInjuries.length)];
  }

  /// Deviasi acak waktu sembuh aktual terhadap perkiraan awal:
  /// 35% (0), 45% (±1), 13% (±2), 5% (±3), 2% (±4).
  int _rollRecoveryDeviation() {
    final roll = _random.nextDouble() * 100.0;
    if (roll < 35.0) return 0;
    if (roll < 57.5) return -1;
    if (roll < 80.0) return 1;
    if (roll < 86.5) return -2;
    if (roll < 93.0) return 2;
    if (roll < 95.5) return -3;
    if (roll < 98.0) return 3;
    if (roll < 99.0) return -4;
    return 4;
  }

  /// Mengundi nilai perubahan OVR Transfer Window sesuai bobot probabilitas PRD.
  int _rollTransferDelta() {
    final roll = _random.nextDouble() * 100.0;

    if (roll < 70.0) {
      const common = [-3, -2, -1, 1, 2, 3];
      return common[_random.nextInt(common.length)];
    }
    if (roll < 90.0) {
      const uncommon = [-4, 0, 4];
      return uncommon[_random.nextInt(uncommon.length)];
    }
    if (roll < 98.0) {
      const rare = [-5, 5];
      return rare[_random.nextInt(rare.length)];
    }
    const goldenEra = [6, 7, 8, 9, 10];
    return goldenEra[_random.nextInt(goldenEra.length)];
  }
}
