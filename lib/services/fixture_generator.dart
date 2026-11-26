import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/match_game.dart';
import '../models/standing_row.dart';
import '../models/team.dart';
import '../models/tournament.dart';

/// Paket lengkap turnamen dan jadwal awal untuk satu musim baru.
class SeasonScheduleBundle {
  final List<Tournament> tournaments;
  final List<MatchGame> matches;

  const SeasonScheduleBundle({
    required this.tournaments,
    required this.matches,
  });
}

/// Generator jadwal terpadu (Pekan 1–48), pembagian Pot 1–4 & Grup A–H,
/// fase knockout, serta kalkulator klasemen dengan aturan tie-breaker lengkap.
class FixtureGenerator {
  static const List<String> leagueLetters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
  ];

  /// Pemetaan 38 Pekan Liga Lokal ke dalam Kalender Terpadu Pekan 1–48.
  /// Pekan 1–19 tepat jatuh pada Gameweek 1–19 agar Transfer Window Week 19 selaras.
  static const List<int> localLeagueGameweeks = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 24, 25, 26, 28, 29, 30, 32, 33, 34, 36, 37, 38, 40, 41, 43, 46,
  ];

  /// Slot gameweek untuk 4 babak Cup Domestik (16 Besar, QF, SF, Final).
  static const int cupRound16Gameweek = 6;
  static const int cupQuarterFinalGameweek = 14;
  static const int cupSemiFinalGameweek = 45;
  static const int cupFinalGameweek = 48;

  /// Slot gameweek untuk 8 Matchday League Phase (Champions, Winner, Federation).
  static const List<int> continentalLeaguePhaseGameweeks = [
    3, 7, 11, 15, 18, 22, 23, 27,
  ];

  /// Slot gameweek untuk Fase Grup Mid Range (5 MD) & Challenger (6 MD).
  static const List<int> continentalGroupPhaseGameweeks = [
    3, 7, 11, 15, 18, 22,
  ];

  /// Slot gameweek fase knockout Kontinental.
  static const int continentalPlayoffLeg1Gameweek = 31;
  static const int continentalPlayoffLeg2Gameweek = 35;
  static const int continentalRound16Leg1Gameweek = 37;
  static const int continentalRound16Leg2Gameweek = 39;
  static const int continentalQuarterFinalLeg1Gameweek = 42;
  static const int continentalQuarterFinalLeg2Gameweek = 44;
  static const int continentalSemiFinalLeg1Gameweek = 45;
  static const int continentalSemiFinalLeg2Gameweek = 47;
  static const int continentalFinalGameweek = 48;

  final Random _random;
  final Uuid _uuid;

  FixtureGenerator({Random? random, Uuid? uuid})
      : _random = random ?? Random(),
        _uuid = uuid ?? const Uuid();

  /// Menghasilkan seluruh turnamen dan jadwal awal satu musim (Musim 1 atau Musim 2+).
  ///
  /// Pada Musim 1, peserta Cup diambil dari 16 tim dengan OVR tertinggi di tiap liga,
  /// sedangkan 5 Turnamen Kontinental berstatus tidak aktif (`isActive: false`).
  /// Pada Musim 2+, [previousSeasonLeagueStandings] digunakan untuk mengisi peserta Cup
  /// (Rank 1–16) serta mengkualifikasi seluruh 160 tim ke 5 Turnamen Kontinental.
  SeasonScheduleBundle generateSeason({
    required int seasonNumber,
    required List<Team> teams,
    Map<String, List<StandingRow>>? previousSeasonLeagueStandings,
    Map<String, String>? customTournamentNames,
  }) {
    final tournaments = <Tournament>[];
    final matches = <MatchGame>[];

    final teamsById = {for (final t in teams) t.id: t};

    // 1. Buat 8 Liga Lokal (Liga A–H) & 8 Cup Domestik (Cup Liga A–H).
    for (var i = 0; i < leagueLetters.length; i++) {
      final letter = leagueLetters[i];
      final baseLeagueId = 'liga_${letter.toLowerCase()}';
      final leagueTeams =
          teams.where((t) => t.leagueId == baseLeagueId).toList();
      final leagueTeamIds = leagueTeams.map((t) => t.id).toList();

      final leagueTournamentId = '${baseLeagueId}_s$seasonNumber';
      final customLeagueName = customTournamentNames?[baseLeagueId]?.trim();
      final leagueName = (customLeagueName != null && customLeagueName.isNotEmpty)
          ? customLeagueName
          : 'Liga $letter';

      tournaments.add(
        Tournament(
          id: leagueTournamentId,
          name: leagueName,
          type: TournamentType.localLeague,
          seasonNumber: seasonNumber,
          leagueIndex: i,
          teamIds: leagueTeamIds,
          isActive: true,
          currentStage: 'Pekan 1',
        ),
      );

      matches.addAll(
        generateDoubleRoundRobinMatches(
          tournamentId: leagueTournamentId,
          tournamentName: leagueName,
          seasonNumber: seasonNumber,
          teamIds: leagueTeamIds,
          gameweeks: localLeagueGameweeks,
        ),
      );

      // Peserta Cup Domestik (16 tim)
      final List<String> cupTeamIds;
      final prevStandings = previousSeasonLeagueStandings?[baseLeagueId];
      if (seasonNumber >= 2 &&
          prevStandings != null &&
          prevStandings.length >= 16) {
        cupTeamIds = prevStandings.take(16).map((r) => r.teamId).toList();
      } else {
        final sortedByOvr = List<Team>.from(leagueTeams)
          ..sort((a, b) => b.ovr.compareTo(a.ovr));
        cupTeamIds = sortedByOvr.take(16).map((t) => t.id).toList();
      }

      final cupBaseId = 'cup_${letter.toLowerCase()}';
      final cupTournamentId = '${cupBaseId}_s$seasonNumber';
      final customCupName = customTournamentNames?[cupBaseId]?.trim();
      final cupName = (customCupName != null && customCupName.isNotEmpty)
          ? customCupName
          : 'Cup $leagueName';
      tournaments.add(
        Tournament(
          id: cupTournamentId,
          name: cupName,
          type: TournamentType.domesticCup,
          seasonNumber: seasonNumber,
          leagueIndex: i,
          teamIds: cupTeamIds,
          isActive: true,
          currentStage: '16 Besar',
        ),
      );

      matches.addAll(
        generateSingleLegKnockoutRound(
          tournamentId: cupTournamentId,
          tournamentName: cupName,
          seasonNumber: seasonNumber,
          gameweek: cupRound16Gameweek,
          stageName: '16 Besar',
          teamIds: cupTeamIds,
          shuffleTeams: true,
        ),
      );
    }

    // 2. Buat 5 Turnamen Kontinental.
    if (seasonNumber == 1 || previousSeasonLeagueStandings == null) {
      tournaments.addAll(
        _buildInactiveContinentalPlaceholders(
          seasonNumber,
          customTournamentNames: customTournamentNames,
        ),
      );
    } else {
      final continentalBundle = _buildActiveContinentalTournaments(
        seasonNumber: seasonNumber,
        teamsById: teamsById,
        previousLeagueStandings: previousSeasonLeagueStandings,
        customTournamentNames: customTournamentNames,
      );
      tournaments.addAll(continentalBundle.tournaments);
      matches.addAll(continentalBundle.matches);
    }

    return SeasonScheduleBundle(tournaments: tournaments, matches: matches);
  }

  /// Menghasilkan jadwal Double Round-Robin (38 pekan untuk 20 tim) dengan Circle Method.
  List<MatchGame> generateDoubleRoundRobinMatches({
    required String tournamentId,
    required String tournamentName,
    required int seasonNumber,
    required List<String> teamIds,
    required List<int> gameweeks,
  }) {
    if (teamIds.length < 2) return [];

    final shuffled = List<String>.from(teamIds)..shuffle(_random);
    if (shuffled.length.isOdd) {
      shuffled.add('__BYE__');
    }

    final n = shuffled.length;
    final halfSeasonRounds = n - 1;
    final matchesPerRound = n ~/ 2;
    final firstHalfPairs = <List<({String home, String away})>>[];

    final rotating = List<String>.from(shuffled);
    for (var round = 0; round < halfSeasonRounds; round++) {
      final roundPairs = <({String home, String away})>[];
      for (var i = 0; i < matchesPerRound; i++) {
        final t1 = rotating[i];
        final t2 = rotating[n - 1 - i];
        if (t1 == '__BYE__' || t2 == '__BYE__') continue;

        final swapHomeAway = (i == 0 && round.isOdd) || (i > 0 && (round + i).isOdd);
        roundPairs.add(
          swapHomeAway ? (home: t2, away: t1) : (home: t1, away: t2),
        );
      }
      firstHalfPairs.add(roundPairs);

      // Rotasi semua elemen kecuali indeks 0.
      final last = rotating.removeLast();
      rotating.insert(1, last);
    }

    final result = <MatchGame>[];
    // Paruh pertama (Week 1..19)
    for (var r = 0; r < firstHalfPairs.length; r++) {
      final gw = r < gameweeks.length ? gameweeks[r] : r + 1;
      for (final pair in firstHalfPairs[r]) {
        result.add(
          MatchGame(
            id: _uuid.v4(),
            tournamentId: tournamentId,
            tournamentName: tournamentName,
            seasonNumber: seasonNumber,
            gameweek: gw,
            stageName: 'Pekan ${r + 1}',
            homeTeamId: pair.home,
            awayTeamId: pair.away,
          ),
        );
      }
    }

    // Paruh kedua (Week 20..38, kandang-tandang dibalik)
    for (var r = 0; r < firstHalfPairs.length; r++) {
      final roundIndex = halfSeasonRounds + r;
      final gw = roundIndex < gameweeks.length
          ? gameweeks[roundIndex]
          : roundIndex + 1;
      for (final pair in firstHalfPairs[r]) {
        result.add(
          MatchGame(
            id: _uuid.v4(),
            tournamentId: tournamentId,
            tournamentName: tournamentName,
            seasonNumber: seasonNumber,
            gameweek: gw,
            stageName: 'Pekan ${roundIndex + 1}',
            homeTeamId: pair.away,
            awayTeamId: pair.home,
          ),
        );
      }
    }

    return result;
  }

  /// Menghasilkan satu babak knockout 1 leg di tempat netral (misal Cup Domestik atau Final).
  List<MatchGame> generateSingleLegKnockoutRound({
    required String tournamentId,
    required String tournamentName,
    required int seasonNumber,
    required int gameweek,
    required String stageName,
    required List<String> teamIds,
    bool shuffleTeams = false,
  }) {
    final ordered = List<String>.from(teamIds);
    if (shuffleTeams) {
      ordered.shuffle(_random);
    }

    final matches = <MatchGame>[];
    for (var i = 0; i + 1 < ordered.length; i += 2) {
      final slot = i ~/ 2;
      matches.add(
        MatchGame(
          id: _uuid.v4(),
          tournamentId: tournamentId,
          tournamentName: tournamentName,
          seasonNumber: seasonNumber,
          gameweek: gameweek,
          stageName: stageName,
          bracketSlot: slot,
          leg: 1,
          isKnockout: true,
          isNeutralVenue: true,
          homeTeamId: ordered[i],
          awayTeamId: ordered[i + 1],
        ),
      );
    }
    return matches;
  }

  /// Menghasilkan satu babak knockout 2 leg (kandang-tandang).
  /// [pairings] adalah daftar pasangan (seedA, seedB) yang sudah tersusun sesuai bagan.
  List<MatchGame> generateTwoLegKnockoutRound({
    required String tournamentId,
    required String tournamentName,
    required int seasonNumber,
    required int leg1Gameweek,
    required int leg2Gameweek,
    required String stageName,
    required List<({String teamA, String teamB})> pairings,
  }) {
    final matches = <MatchGame>[];
    for (var slot = 0; slot < pairings.length; slot++) {
      final pair = pairings[slot];
      final tieId = _uuid.v4();

      // Leg 1: teamB tuan rumah (atau sesuai pairing), Leg 2 dibalik.
      matches.add(
        MatchGame(
          id: _uuid.v4(),
          tournamentId: tournamentId,
          tournamentName: tournamentName,
          seasonNumber: seasonNumber,
          gameweek: leg1Gameweek,
          stageName: '$stageName • Leg 1',
          tieId: tieId,
          bracketSlot: slot,
          leg: 1,
          isKnockout: true,
          isNeutralVenue: false,
          homeTeamId: pair.teamB,
          awayTeamId: pair.teamA,
        ),
      );

      matches.add(
        MatchGame(
          id: _uuid.v4(),
          tournamentId: tournamentId,
          tournamentName: tournamentName,
          seasonNumber: seasonNumber,
          gameweek: leg2Gameweek,
          stageName: '$stageName • Leg 2',
          tieId: tieId,
          bracketSlot: slot,
          leg: 2,
          isKnockout: true,
          isNeutralVenue: false,
          homeTeamId: pair.teamA,
          awayTeamId: pair.teamB,
        ),
      );
    }
    return matches;
  }

  /// Menentukan pemenang dari pasangan knockout 2 leg yang sudah selesai.
  String resolveTwoLegTieWinner(MatchGame leg1, MatchGame leg2) {
    final leg1HomeScore = leg1.homeScore ?? 0;
    final leg1AwayScore = leg1.awayScore ?? 0;
    final leg2HomeScore = leg2.homeScore ?? 0;
    final leg2AwayScore = leg2.awayScore ?? 0;

    // Di Leg 2, homeTeam adalah awayTeam dari Leg 1.
    final leg2HomeAgg = leg1AwayScore + leg2HomeScore;
    final leg2AwayAgg = leg1HomeScore + leg2AwayScore;

    if (leg2HomeAgg > leg2AwayAgg) return leg2.homeTeamId;
    if (leg2AwayAgg > leg2HomeAgg) return leg2.awayTeamId;

    if (leg2.hasPenaltyShootout) {
      if ((leg2.homePenaltyScore ?? 0) > (leg2.awayPenaltyScore ?? 0)) {
        return leg2.homeTeamId;
      }
      return leg2.awayTeamId;
    }

    return leg2.homeTeamId;
  }

  /// Menghasilkan babak Play-off 2 leg (Rank 9–24) untuk turnamen League Phase
  /// (Champions, Winner, Federation League).
  List<MatchGame> generateContinentalPlayoffRound({
    required Tournament tournament,
    required List<StandingRow> standings,
  }) {
    if (standings.length < 24) return [];

    final seeded = standings.sublist(8, 16).map((r) => r.teamId).toList();
    final unseeded = standings.sublist(16, 24).map((r) => r.teamId).toList()
      ..shuffle(_random);

    final pairings = <({String teamA, String teamB})>[
      for (var i = 0; i < 8; i++)
        (teamA: seeded[i], teamB: unseeded[i]),
    ];

    return generateTwoLegKnockoutRound(
      tournamentId: tournament.id,
      tournamentName: tournament.name,
      seasonNumber: tournament.seasonNumber,
      leg1Gameweek: continentalPlayoffLeg1Gameweek,
      leg2Gameweek: continentalPlayoffLeg2Gameweek,
      stageName: 'Play-off',
      pairings: pairings,
    );
  }

  /// Menghasilkan babak 16 Besar 2 leg untuk turnamen League Phase
  /// (Rank 1–8 bertemu 8 pemenang Play-off).
  List<MatchGame> generateLeaguePhaseRound16({
    required Tournament tournament,
    required List<StandingRow> standings,
    required List<String> playoffWinners,
  }) {
    if (standings.length < 8 || playoffWinners.length < 8) return [];

    final top8 = standings.sublist(0, 8).map((r) => r.teamId).toList();
    final winners = List<String>.from(playoffWinners)..shuffle(_random);

    final pairings = <({String teamA, String teamB})>[
      for (var i = 0; i < 8; i++)
        (teamA: top8[i], teamB: winners[i]),
    ];

    return generateTwoLegKnockoutRound(
      tournamentId: tournament.id,
      tournamentName: tournament.name,
      seasonNumber: tournament.seasonNumber,
      leg1Gameweek: continentalRound16Leg1Gameweek,
      leg2Gameweek: continentalRound16Leg2Gameweek,
      stageName: '16 Besar',
      pairings: pairings,
    );
  }

  /// Menghasilkan babak 16 Besar 2 leg untuk turnamen Fase Grup
  /// (Mid Range: Juara vs Runner-up grup; Challenger: Juara grup vs Peringkat 3 Mid Range).
  List<MatchGame> generateGroupPhaseRound16({
    required Tournament tournament,
    required List<String> seededTeamIds,
    required List<String> unseededTeamIds,
  }) {
    if (seededTeamIds.length < 8 || unseededTeamIds.length < 8) return [];

    final seeded = List<String>.from(seededTeamIds)..shuffle(_random);
    final unseeded = List<String>.from(unseededTeamIds)..shuffle(_random);

    final pairings = <({String teamA, String teamB})>[
      for (var i = 0; i < 8; i++)
        (teamA: seeded[i], teamB: unseeded[i]),
    ];

    return generateTwoLegKnockoutRound(
      tournamentId: tournament.id,
      tournamentName: tournament.name,
      seasonNumber: tournament.seasonNumber,
      leg1Gameweek: continentalRound16Leg1Gameweek,
      leg2Gameweek: continentalRound16Leg2Gameweek,
      stageName: '16 Besar',
      pairings: pairings,
    );
  }

  /// Menghitung tabel klasemen lengkap dengan urutan tie-breaker resmi PRD:
  /// 1. Poin (PTS)
  /// 2. Selisih Gol (GD = GF - GA)
  /// 3. Jumlah Gol Dicetak (GF)
  /// 4. Poin Head-to-Head antar tim yang seri
  /// 5. Selisih Gol Head-to-Head antar tim yang seri
  /// 6. Gol Tandang Head-to-Head antar tim yang seri
  /// 7. Perbandingan OVR tim (dan urutan deterministik ID jika identik)
  List<StandingRow> calculateStandings({
    required String tournamentId,
    required List<String> teamIds,
    required List<MatchGame> matches,
    required Map<String, Team> teamsById,
    String? groupName,
  }) {
    final stats = <String, _MutableStanding>{
      for (final id in teamIds) id: _MutableStanding(id),
    };

    // Hanya proses pertandingan fase liga/grup (non-knockout) yang sudah selesai.
    final relevantMatches = matches.where((m) {
      if (m.tournamentId != tournamentId || !m.isFinished || m.isKnockout) {
        return false;
      }
      if (groupName != null && m.groupName != groupName) {
        return false;
      }
      return stats.containsKey(m.homeTeamId) && stats.containsKey(m.awayTeamId);
    }).toList()
      ..sort((a, b) => a.gameweek.compareTo(b.gameweek));

    for (final m in relevantMatches) {
      final hg = m.homeScore ?? 0;
      final ag = m.awayScore ?? 0;
      final home = stats[m.homeTeamId]!;
      final away = stats[m.awayTeamId]!;

      home.played++;
      away.played++;
      home.goalsFor += hg;
      home.goalsAgainst += ag;
      away.goalsFor += ag;
      away.goalsAgainst += hg;

      if (hg > ag) {
        home.won++;
        home.points += 3;
        home.form.add('W');
        away.lost++;
        away.form.add('L');
      } else if (hg < ag) {
        away.won++;
        away.points += 3;
        away.form.add('W');
        home.lost++;
        home.form.add('L');
      } else {
        home.drawn++;
        home.points += 1;
        home.form.add('D');
        away.drawn++;
        away.points += 1;
        away.form.add('D');
      }
    }

    // Kelompokkan sementara berdasarkan (points, gd, gf) untuk evaluasi Head-to-Head
    // hanya di antara tim-tim yang benar-benar seri pada tiga kriteria awal.
    final entries = stats.values.toList();
    entries.sort((a, b) {
      final ptsCmp = b.points.compareTo(a.points);
      if (ptsCmp != 0) return ptsCmp;
      final gdCmp = a.goalDifference == b.goalDifference
          ? 0
          : b.goalDifference.compareTo(a.goalDifference);
      if (gdCmp != 0) return gdCmp;
      return b.goalsFor.compareTo(a.goalsFor);
    });

    final sortedEntries = <_MutableStanding>[];
    var idx = 0;
    while (idx < entries.length) {
      final anchor = entries[idx];
      var end = idx + 1;
      while (end < entries.length &&
          entries[end].points == anchor.points &&
          entries[end].goalDifference == anchor.goalDifference &&
          entries[end].goalsFor == anchor.goalsFor) {
        end++;
      }

      if (end - idx == 1) {
        sortedEntries.add(anchor);
      } else {
        final tiedGroup = entries.sublist(idx, end);
        final tiedIds = tiedGroup.map((e) => e.teamId).toSet();
        final h2hStats = _computeHeadToHead(tiedIds, relevantMatches);

        tiedGroup.sort((a, b) {
          final h2hA = h2hStats[a.teamId]!;
          final h2hB = h2hStats[b.teamId]!;

          final h2hPtsCmp = h2hB.points.compareTo(h2hA.points);
          if (h2hPtsCmp != 0) return h2hPtsCmp;

          final h2hGdCmp = h2hB.goalDifference.compareTo(h2hA.goalDifference);
          if (h2hGdCmp != 0) return h2hGdCmp;

          final h2hAwayCmp = h2hB.awayGoals.compareTo(h2hA.awayGoals);
          if (h2hAwayCmp != 0) return h2hAwayCmp;

          final ovrA = teamsById[a.teamId]?.ovr ?? 0;
          final ovrB = teamsById[b.teamId]?.ovr ?? 0;
          final ovrCmp = ovrB.compareTo(ovrA);
          if (ovrCmp != 0) return ovrCmp;

          return a.teamId.compareTo(b.teamId);
        });

        sortedEntries.addAll(tiedGroup);
      }

      idx = end;
    }

    return [
      for (var i = 0; i < sortedEntries.length; i++)
        StandingRow(
          teamId: sortedEntries[i].teamId,
          tournamentId: tournamentId,
          groupName: groupName,
          position: i + 1,
          played: sortedEntries[i].played,
          won: sortedEntries[i].won,
          drawn: sortedEntries[i].drawn,
          lost: sortedEntries[i].lost,
          goalsFor: sortedEntries[i].goalsFor,
          goalsAgainst: sortedEntries[i].goalsAgainst,
          points: sortedEntries[i].points,
          form: sortedEntries[i].form.length <= 5
              ? List<String>.from(sortedEntries[i].form)
              : sortedEntries[i].form.sublist(sortedEntries[i].form.length - 5),
        ),
    ];
  }

  Map<String, _HeadToHeadStat> _computeHeadToHead(
    Set<String> tiedIds,
    List<MatchGame> matches,
  ) {
    final map = {for (final id in tiedIds) id: _HeadToHeadStat()};
    for (final m in matches) {
      if (!tiedIds.contains(m.homeTeamId) || !tiedIds.contains(m.awayTeamId)) {
        continue;
      }
      final hg = m.homeScore ?? 0;
      final ag = m.awayScore ?? 0;
      final home = map[m.homeTeamId]!;
      final away = map[m.awayTeamId]!;

      home.goalsFor += hg;
      home.goalsAgainst += ag;
      away.goalsFor += ag;
      away.goalsAgainst += hg;
      if (!m.isNeutralVenue) {
        away.awayGoals += ag;
      }

      if (hg > ag) {
        home.points += 3;
      } else if (hg < ag) {
        away.points += 3;
      } else {
        home.points += 1;
        away.points += 1;
      }
    }
    return map;
  }

  String _resolveContinentalName(
    String key,
    String fallback,
    Map<String, String>? customTournamentNames,
  ) {
    final custom = customTournamentNames?[key]?.trim();
    return (custom != null && custom.isNotEmpty) ? custom : fallback;
  }

  List<Tournament> _buildInactiveContinentalPlaceholders(
    int seasonNumber, {
    Map<String, String>? customTournamentNames,
  }) {
    return [
      Tournament(
        id: 'ucl_s$seasonNumber',
        name: _resolveContinentalName(
          'ucl',
          'Champions League',
          customTournamentNames,
        ),
        type: TournamentType.continentalLeague,
        seasonNumber: seasonNumber,
        tier: 1,
        isActive: false,
        currentStage: 'Mulai Musim 2',
      ),
      Tournament(
        id: 'winner_s$seasonNumber',
        name: _resolveContinentalName(
          'winner',
          'Winner League',
          customTournamentNames,
        ),
        type: TournamentType.continentalLeague,
        seasonNumber: seasonNumber,
        tier: 2,
        isActive: false,
        currentStage: 'Mulai Musim 2',
      ),
      Tournament(
        id: 'federation_s$seasonNumber',
        name: _resolveContinentalName(
          'federation',
          'Federation League',
          customTournamentNames,
        ),
        type: TournamentType.continentalLeague,
        seasonNumber: seasonNumber,
        tier: 3,
        isActive: false,
        currentStage: 'Mulai Musim 2',
      ),
      Tournament(
        id: 'mid_range_s$seasonNumber',
        name: _resolveContinentalName(
          'mid_range',
          'Mid Range League',
          customTournamentNames,
        ),
        type: TournamentType.continentalGroup,
        seasonNumber: seasonNumber,
        tier: 4,
        isActive: false,
        currentStage: 'Mulai Musim 2',
      ),
      Tournament(
        id: 'challenger_s$seasonNumber',
        name: _resolveContinentalName(
          'challenger',
          'Challenger League',
          customTournamentNames,
        ),
        type: TournamentType.continentalGroup,
        seasonNumber: seasonNumber,
        tier: 5,
        isActive: false,
        currentStage: 'Mulai Musim 2',
      ),
    ];
  }

  SeasonScheduleBundle _buildActiveContinentalTournaments({
    required int seasonNumber,
    required Map<String, Team> teamsById,
    required Map<String, List<StandingRow>> previousLeagueStandings,
    Map<String, String>? customTournamentNames,
  }) {
    final tournaments = <Tournament>[];
    final matches = <MatchGame>[];

    List<String> teamsAtRank(int oneBasedRank) {
      final list = <String>[];
      for (final letter in leagueLetters) {
        final baseId = 'liga_${letter.toLowerCase()}';
        final standings = previousLeagueStandings[baseId];
        if (standings != null && standings.length >= oneBasedRank) {
          list.add(standings[oneBasedRank - 1].teamId);
        }
      }
      return list;
    }

    // 1–3. Champions (Rank 1-4), Winner (Rank 5-8), Federation (Rank 9-12)
    final leaguePhaseConfigs = [
      (
        id: 'ucl_s$seasonNumber',
        name: _resolveContinentalName(
          'ucl',
          'Champions League',
          customTournamentNames,
        ),
        tier: 1,
        startRank: 1,
      ),
      (
        id: 'winner_s$seasonNumber',
        name: _resolveContinentalName(
          'winner',
          'Winner League',
          customTournamentNames,
        ),
        tier: 2,
        startRank: 5,
      ),
      (
        id: 'federation_s$seasonNumber',
        name: _resolveContinentalName(
          'federation',
          'Federation League',
          customTournamentNames,
        ),
        tier: 3,
        startRank: 9,
      ),
    ];

    for (final cfg in leaguePhaseConfigs) {
      final pots = <String, List<String>>{};
      final allIds = <String>[];
      for (var p = 0; p < 4; p++) {
        final potTeams = teamsAtRank(cfg.startRank + p)..shuffle(_random);
        pots['Pot ${p + 1}'] = potTeams;
        allIds.addAll(potTeams);
      }

      tournaments.add(
        Tournament(
          id: cfg.id,
          name: cfg.name,
          type: TournamentType.continentalLeague,
          seasonNumber: seasonNumber,
          tier: cfg.tier,
          teamIds: allIds,
          potsOrGroups: pots,
          isActive: true,
          currentStage: 'League Phase',
        ),
      );

      matches.addAll(
        _generateUclLeaguePhaseMatches(
          tournamentId: cfg.id,
          tournamentName: cfg.name,
          seasonNumber: seasonNumber,
          pots: pots,
          gameweeks: continentalLeaguePhaseGameweeks,
        ),
      );
    }

    // 4. Mid Range League (Rank 13–17 -> 40 tim -> 8 Grup x 5 tim, Single RR)
    final midRangeRanks = [13, 14, 15, 16, 17];
    final midRangeGroups = _drawBalancedGroups(
      ranks: midRangeRanks,
      teamsAtRank: teamsAtRank,
      groupCount: 8,
    );
    final midRangeTeamIds = midRangeGroups.values.expand((e) => e).toList();
    final midRangeId = 'mid_range_s$seasonNumber';
    final midRangeName = _resolveContinentalName(
      'mid_range',
      'Mid Range League',
      customTournamentNames,
    );

    tournaments.add(
      Tournament(
        id: midRangeId,
        name: midRangeName,
        type: TournamentType.continentalGroup,
        seasonNumber: seasonNumber,
        tier: 4,
        teamIds: midRangeTeamIds,
        potsOrGroups: midRangeGroups,
        isActive: true,
        currentStage: 'Fase Grup',
      ),
    );

    matches.addAll(
      _generateGroupStageMatches(
        tournamentId: midRangeId,
        tournamentName: midRangeName,
        seasonNumber: seasonNumber,
        groups: midRangeGroups,
        isDoubleRoundRobin: false,
        gameweeks: continentalGroupPhaseGameweeks,
      ),
    );

    // 5. Challenger League (Rank 18–20 -> 24 tim -> 8 Grup x 3 tim, Double RR)
    final challengerRanks = [18, 19, 20];
    final challengerGroups = _drawBalancedGroups(
      ranks: challengerRanks,
      teamsAtRank: teamsAtRank,
      groupCount: 8,
    );
    final challengerTeamIds =
        challengerGroups.values.expand((e) => e).toList();
    final challengerId = 'challenger_s$seasonNumber';
    final challengerName = _resolveContinentalName(
      'challenger',
      'Challenger League',
      customTournamentNames,
    );

    tournaments.add(
      Tournament(
        id: challengerId,
        name: challengerName,
        type: TournamentType.continentalGroup,
        seasonNumber: seasonNumber,
        tier: 5,
        teamIds: challengerTeamIds,
        potsOrGroups: challengerGroups,
        isActive: true,
        currentStage: 'Fase Grup',
      ),
    );

    matches.addAll(
      _generateGroupStageMatches(
        tournamentId: challengerId,
        tournamentName: challengerName,
        seasonNumber: seasonNumber,
        groups: challengerGroups,
        isDoubleRoundRobin: true,
        gameweeks: continentalGroupPhaseGameweeks,
      ),
    );

    return SeasonScheduleBundle(tournaments: tournaments, matches: matches);
  }

  /// Generator jadwal League Phase (32 tim, Pot 1–4, 8 matchday).
  /// Menjamin setiap tim bermain 8 laga: 1 kandang & 1 tandang melawan 2 tim dari tiap pot.
  List<MatchGame> _generateUclLeaguePhaseMatches({
    required String tournamentId,
    required String tournamentName,
    required int seasonNumber,
    required Map<String, List<String>> pots,
    required List<int> gameweeks,
  }) {
    final p0 = pots['Pot 1'] ?? [];
    final p1 = pots['Pot 2'] ?? [];
    final p2 = pots['Pot 3'] ?? [];
    final p3 = pots['Pot 4'] ?? [];
    if (p0.length != 8 || p1.length != 8 || p2.length != 8 || p3.length != 8) {
      return [];
    }

    final allPots = [p0, p1, p2, p3];
    // 8 matchdays masing-masing berisi 16 pertandingan (1-factor sempurna).
    final matchdays = List.generate(8, (_) => <({String home, String away})>[]);

    // MD 0 & 1: Intra-pot (masing-masing 1 Home & 1 Away dalam satu pot).
    for (final pot in allPots) {
      for (var i = 0; i < 8; i += 2) {
        matchdays[0].add((home: pot[i], away: pot[(i + 1) % 8]));
      }
      for (var i = 1; i < 8; i += 2) {
        matchdays[1].add((home: pot[i], away: pot[(i + 1) % 8]));
      }
    }

    // MD 2–7: Inter-pot (pasangan pot (0,1)+(2,3), (0,2)+(1,3), (0,3)+(1,2)).
    final potPairSets = [
      [(0, 1), (2, 3)],
      [(0, 2), (1, 3)],
      [(0, 3), (1, 2)],
    ];

    for (var s = 0; s < potPairSets.length; s++) {
      final mdHome = 2 + (s * 2);
      final mdAway = mdHome + 1;
      for (final (aIdx, bIdx) in potPairSets[s]) {
        final potA = allPots[aIdx];
        final potB = allPots[bIdx];
        final shift1 = _random.nextInt(8);
        final shift2 = (shift1 + 1 + _random.nextInt(7)) % 8;

        for (var i = 0; i < 8; i++) {
          matchdays[mdHome].add((home: potA[i], away: potB[(i + shift1) % 8]));
          matchdays[mdAway].add((home: potB[(i + shift2) % 8], away: potA[i]));
        }
      }
    }

    // Acak urutan 8 matchday agar pertemuan intra-pot & antar-pot tersebar alami.
    final mdOrder = List.generate(8, (i) => i)..shuffle(_random);
    final result = <MatchGame>[];

    for (var md = 0; md < 8; md++) {
      final gw = md < gameweeks.length ? gameweeks[md] : md + 1;
      for (final pair in matchdays[mdOrder[md]]) {
        result.add(
          MatchGame(
            id: _uuid.v4(),
            tournamentId: tournamentId,
            tournamentName: tournamentName,
            seasonNumber: seasonNumber,
            gameweek: gw,
            stageName: 'League Phase MD ${md + 1}',
            homeTeamId: pair.home,
            awayTeamId: pair.away,
          ),
        );
      }
    }

    return result;
  }

  Map<String, List<String>> _drawBalancedGroups({
    required List<int> ranks,
    required List<String> Function(int rank) teamsAtRank,
    required int groupCount,
  }) {
    final groups = <String, List<String>>{
      for (var i = 0; i < groupCount; i++) 'Grup ${leagueLetters[i]}': [],
    };

    for (final rank in ranks) {
      final pot = teamsAtRank(rank)..shuffle(_random);
      for (var i = 0; i < pot.length && i < groupCount; i++) {
        groups['Grup ${leagueLetters[i]}']!.add(pot[i]);
      }
    }

    return groups;
  }

  List<MatchGame> _generateGroupStageMatches({
    required String tournamentId,
    required String tournamentName,
    required int seasonNumber,
    required Map<String, List<String>> groups,
    required bool isDoubleRoundRobin,
    required List<int> gameweeks,
  }) {
    final result = <MatchGame>[];

    for (final entry in groups.entries) {
      final groupName = entry.key;
      final groupTeams = List<String>.from(entry.value)..shuffle(_random);
      if (groupTeams.length < 2) continue;

      final rounds = _buildRoundRobinRounds(
        groupTeams,
        doubleRoundRobin: isDoubleRoundRobin,
      );

      for (var r = 0; r < rounds.length; r++) {
        final gw = r < gameweeks.length ? gameweeks[r] : r + 1;
        for (final pair in rounds[r]) {
          result.add(
            MatchGame(
              id: _uuid.v4(),
              tournamentId: tournamentId,
              tournamentName: tournamentName,
              seasonNumber: seasonNumber,
              gameweek: gw,
              stageName: '$groupName • MD ${r + 1}',
              groupName: groupName,
              homeTeamId: pair.home,
              awayTeamId: pair.away,
            ),
          );
        }
      }
    }

    return result;
  }

  List<List<({String home, String away})>> _buildRoundRobinRounds(
    List<String> teams, {
    required bool doubleRoundRobin,
  }) {
    final list = List<String>.from(teams);
    if (list.length.isOdd) {
      list.add('__BYE__');
    }

    final n = list.length;
    final halfRounds = n - 1;
    final halfSize = n ~/ 2;
    final firstHalf = <List<({String home, String away})>>[];

    for (var round = 0; round < halfRounds; round++) {
      final pairs = <({String home, String away})>[];
      for (var i = 0; i < halfSize; i++) {
        final t1 = list[i];
        final t2 = list[n - 1 - i];
        if (t1 == '__BYE__' || t2 == '__BYE__') continue;

        final swap = (i == 0 && round.isOdd) || (i > 0 && (round + i).isOdd);
        pairs.add(swap ? (home: t2, away: t1) : (home: t1, away: t2));
      }
      firstHalf.add(pairs);

      final last = list.removeLast();
      list.insert(1, last);
    }

    if (!doubleRoundRobin) {
      return firstHalf;
    }

    final secondHalf = <List<({String home, String away})>>[
      for (final round in firstHalf)
        [for (final p in round) (home: p.away, away: p.home)],
    ];

    return [...firstHalf, ...secondHalf];
  }
}

class _MutableStanding {
  final String teamId;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;
  final List<String> form = [];

  _MutableStanding(this.teamId);

  int get goalDifference => goalsFor - goalsAgainst;
}

class _HeadToHeadStat {
  int points = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int awayGoals = 0;

  int get goalDifference => goalsFor - goalsAgainst;
}
