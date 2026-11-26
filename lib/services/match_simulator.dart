import 'dart:math';

import '../models/match_game.dart';
import '../models/team.dart';

/// Hasil probabilitas Model Davidson untuk pra-laga (Menang Home / Seri / Menang Away).
class MatchProbabilities {
  final double homeWin;
  final double draw;
  final double awayWin;

  const MatchProbabilities({
    required this.homeWin,
    required this.draw,
    required this.awayWin,
  });

  int get homeWinPercent => (homeWin * 100).round();
  int get drawPercent => (draw * 100).round();
  int get awayWinPercent => (awayWin * 100).round();
}

/// Mesin simulasi pertandingan berbasis Model Davidson, Distribusi Poisson,
/// Chaotic Event, dan Adu Penalti fase gugur.
class MatchSimulator {
  static const int homeAdvantageBonus = 2;
  static const double davidsonScaleS = 15.0;
  static const double davidsonDrawNu = 0.8;
  static const double chaoticMatchChance = 0.02;
  static const int maxPoissonGoals = 10;

  final Random _random;

  MatchSimulator({Random? random}) : _random = random ?? Random();

  /// Menghitung selisih kekuatan (Delta OVR) dengan mempertimbangkan bonus kandang.
  double calculateOvrDelta({
    required int homeOvr,
    required int awayOvr,
    required bool isNeutralVenue,
  }) {
    final bonus = isNeutralVenue ? 0 : homeAdvantageBonus;
    return ((homeOvr + bonus) - awayOvr).toDouble();
  }

  /// Menghitung peluang Menang / Seri / Kalah menggunakan Model Davidson.
  MatchProbabilities calculateProbabilities({
    required Team homeTeam,
    required Team awayTeam,
    required bool isNeutralVenue,
  }) {
    final delta = calculateOvrDelta(
      homeOvr: homeTeam.ovr,
      awayOvr: awayTeam.ovr,
      isNeutralVenue: isNeutralVenue,
    );

    final r = pow(10, delta / davidsonScaleS).toDouble();
    final drawTerm = davidsonDrawNu * sqrt(r);
    final denominator = r + 1.0 + drawTerm;

    return MatchProbabilities(
      homeWin: r / denominator,
      draw: drawTerm / denominator,
      awayWin: 1.0 / denominator,
    );
  }

  /// Menghitung rata-rata gol ekspektasi (lambda) untuk kedua tim.
  ({double homeLambda, double awayLambda}) calculateExpectedGoals({
    required Team homeTeam,
    required Team awayTeam,
    required int seasonNumber,
    required bool isNeutralVenue,
  }) {
    final delta = calculateOvrDelta(
      homeOvr: homeTeam.ovr,
      awayOvr: awayTeam.ovr,
      isNeutralVenue: isNeutralVenue,
    );

    final homeOvrLambda = max(0.25, 1.35 + (delta * 0.05));
    final awayOvrLambda = max(0.25, 1.35 - (delta * 0.05));

    if (seasonNumber < 2) {
      return (homeLambda: homeOvrLambda, awayLambda: awayOvrLambda);
    }

    final homeAvgGf = homeTeam.lastSeasonAvgGoalsFor;
    final awayAvgGa = awayTeam.lastSeasonAvgGoalsAgainst;
    final awayAvgGf = awayTeam.lastSeasonAvgGoalsFor;
    final homeAvgGa = homeTeam.lastSeasonAvgGoalsAgainst;

    final double homeLambda;
    if (homeAvgGf != null && awayAvgGa != null) {
      final historyTerm = (homeAvgGf + awayAvgGa) / 2.0;
      homeLambda = max(0.25, (0.7 * homeOvrLambda) + (0.3 * historyTerm));
    } else {
      homeLambda = homeOvrLambda;
    }

    final double awayLambda;
    if (awayAvgGf != null && homeAvgGa != null) {
      final historyTerm = (awayAvgGf + homeAvgGa) / 2.0;
      awayLambda = max(0.25, (0.7 * awayOvrLambda) + (0.3 * historyTerm));
    } else {
      awayLambda = awayOvrLambda;
    }

    return (homeLambda: homeLambda, awayLambda: awayLambda);
  }

  /// Mensimulasikan satu pertandingan penuh beserta Chaotic Event dan Adu Penalti jika seri di fase gugur.
  ///
  /// Untuk laga knockout 2 leg pada [match.leg] == 2, sertakan [firstLegMatch]
  /// agar sistem dapat mengevaluasi skor agregat sebelum memutuskan adu penalti.
  MatchGame simulateMatch({
    required MatchGame match,
    required Team homeTeam,
    required Team awayTeam,
    MatchGame? firstLegMatch,
  }) {
    final lambdas = calculateExpectedGoals(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      seasonNumber: match.seasonNumber,
      isNeutralVenue: match.isNeutralVenue,
    );

    var homeLambda = lambdas.homeLambda;
    var awayLambda = lambdas.awayLambda;

    // Anomali Chaotic Match (peluang 2%): salah satu tim mendapat lonjakan lambda
    // sehingga memungkinkan skor > 5 gol atau kejutan besar (upset).
    final chaoticTriggered = _random.nextDouble() < chaoticMatchChance;
    final boostHome = _random.nextBool();
    if (chaoticTriggered) {
      final boost = 2.5 + _random.nextDouble() * 1.5; // +2.5 hingga +4.0
      if (boostHome) {
        homeLambda += boost;
      } else {
        awayLambda += boost;
      }
    }

    var homeScore = _samplePoisson(homeLambda);
    var awayScore = _samplePoisson(awayLambda);

    // Pastikan jika Chaotic Match terpicu tetapi angka random kebetulan kecil,
    // tetap terasa lonjakan gol (> 5 gol untuk tim yang mendapat boost).
    if (chaoticTriggered) {
      if (boostHome && homeScore <= 5) {
        homeScore = 6 + _random.nextInt(3);
      } else if (!boostHome && awayScore <= 5) {
        awayScore = 6 + _random.nextInt(3);
      }
    }

    int? homePen;
    int? awayPen;

    if (match.isKnockout) {
      final needsPenalties = _shouldPlayPenalties(
        match: match,
        homeScore: homeScore,
        awayScore: awayScore,
        firstLegMatch: firstLegMatch,
      );

      if (needsPenalties) {
        final penalties = _simulatePenaltyShootout(
          homeOvr: homeTeam.ovr,
          awayOvr: awayTeam.ovr,
          isNeutralVenue: match.isNeutralVenue,
        );
        homePen = penalties.homePenalties;
        awayPen = penalties.awayPenalties;
      }
    }

    final isChaotic =
        chaoticTriggered || (homeScore + awayScore > 5) || homeScore > 5 || awayScore > 5;

    return match.copyWith(
      homeScore: homeScore,
      awayScore: awayScore,
      homePenaltyScore: homePen,
      awayPenaltyScore: awayPen,
      isFinished: true,
      isChaoticMatch: isChaotic,
    );
  }

  /// Menentukan apakah adu penalti perlu dijalankan untuk laga fase gugur.
  bool _shouldPlayPenalties({
    required MatchGame match,
    required int homeScore,
    required int awayScore,
    MatchGame? firstLegMatch,
  }) {
    // Knockout 1 leg (Cup League atau Final) -> seri di waktu normal langsung penalti.
    if (match.leg == 1 && match.isNeutralVenue) {
      return homeScore == awayScore;
    }

    // Knockout 2 leg pada Leg 2 -> cek skor agregat tanpa aturan gol tandang.
    if (match.leg == 2 && firstLegMatch != null) {
      final leg1Home = firstLegMatch.homeScore ?? 0;
      final leg1Away = firstLegMatch.awayScore ?? 0;

      // Di Leg 2, homeTeam adalah tim away pada Leg 1, dan awayTeam adalah tim home pada Leg 1.
      final currentHomeAggregate = leg1Away + homeScore;
      final currentAwayAggregate = leg1Home + awayScore;
      return currentHomeAggregate == currentAwayAggregate;
    }

    return false;
  }

  /// Membangkitkan jumlah gol dari distribusi Poisson kumulatif:
  /// P(k) = (lambda^k * e^-lambda) / k! untuk k = 0..10.
  int _samplePoisson(double lambda) {
    final u = _random.nextDouble();
    final expNegLambda = exp(-lambda);
    var p = expNegLambda;
    var cumulative = p;

    for (var k = 0; k < maxPoissonGoals; k++) {
      if (u <= cumulative) {
        return k;
      }
      p = p * lambda / (k + 1);
      cumulative += p;
    }
    return maxPoissonGoals;
  }

  /// Simulasi adu penalti 5 penendang (+ sudden death jika imbang).
  /// Peluang masuk per tendangan: 75% + (Delta * 0.3%).
  ({int homePenalties, int awayPenalties}) _simulatePenaltyShootout({
    required int homeOvr,
    required int awayOvr,
    required bool isNeutralVenue,
  }) {
    final delta = calculateOvrDelta(
      homeOvr: homeOvr,
      awayOvr: awayOvr,
      isNeutralVenue: isNeutralVenue,
    );

    final homeSuccessProb = (0.75 + (delta * 0.003)).clamp(0.50, 0.95);
    final awaySuccessProb = (0.75 + (-delta * 0.003)).clamp(0.50, 0.95);

    var homePen = 0;
    var awayPen = 0;

    // 5 penendang utama dengan pengecekan selisih tak terkejar.
    for (var round = 0; round < 5; round++) {
      if (_random.nextDouble() < homeSuccessProb) {
        homePen++;
      }
      final remainingHomeAfter = 4 - round;
      final remainingAwayBefore = 5 - round;
      if (homePen - awayPen > remainingAwayBefore ||
          awayPen - homePen > remainingHomeAfter) {
        return (homePenalties: homePen, awayPenalties: awayPen);
      }

      if (_random.nextDouble() < awaySuccessProb) {
        awayPen++;
      }
      final remainingAfter = 4 - round;
      if (homePen - awayPen > remainingAfter ||
          awayPen - homePen > remainingAfter) {
        return (homePenalties: homePen, awayPenalties: awayPen);
      }
    }

    // Sudden death jika masih imbang setelah 5 tendangan.
    while (homePen == awayPen) {
      final homeScored = _random.nextDouble() < homeSuccessProb;
      final awayScored = _random.nextDouble() < awaySuccessProb;
      if (homeScored) homePen++;
      if (awayScored) awayPen++;
    }

    return (homePenalties: homePen, awayPenalties: awayPen);
  }
}
