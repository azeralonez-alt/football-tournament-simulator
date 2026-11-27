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

/// Pengelola dinamika Overall Rating (OVR):
/// 1. Sistem Ekosistem Transfer Seimbang Lintas Region (Transfer Window).
/// 2. Sistem Cedera & Pemulihan Dinamis.
class OvrManager {
  static const double injuryChancePerWeek = 0.015; // 1.5% peluang per pekan
  static const int minTeamOvrAfterInjury = 40;
  static const int minTeamOvrLimit = 40;

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

  /// Menjalankan Sistem Ekosistem Transfer Seimbang Lintas Region:
  /// - Memilih 35%–50% tim lintas 160 klub (maksimal 1 event utama per tim).
  /// - Jalur A (~10% event, 1–3 kejadian): Eksodus Massal & Mega Transfer Terpecah.
  /// - Jalur B (~60% event): Transfer Antar-Klub 1-on-1 Lintas Region (+X / -X).
  /// - Jalur C (~30% event): Perubahan Organik Seimbang (Promosi Akademi +X / Regenerasi Skuad -X).
  OvrUpdateResult applyTransferWindow({
    required List<Team> teams,
    required int seasonNumber,
    required int gameweek,
    required bool isEndOfSeason,
    Map<String, String>? leagueNames,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final windowLabel = isEndOfSeason
        ? 'Transfer Window Akhir Musim'
        : 'Transfer Window Tengah Musim';

    // Reset lastOvrChange dan perbarui seasonOvrStart (jika akhir musim) untuk semua tim.
    final workingTeams = teams
        .map(
          (t) => t.copyWith(
            lastOvrChange: 0,
            seasonOvrStart: isEndOfSeason ? t.ovr : t.seasonOvrStart,
          ),
        )
        .toList();

    if (workingTeams.length < 2) {
      return OvrUpdateResult(updatedTeams: workingTeams, events: const []);
    }

    final indexById = <String, int>{
      for (var i = 0; i < workingTeams.length; i++) workingTeams[i].id: i,
    };
    final usedTeamIds = <String>{};
    final events = <NewsEvent>[];

    // 1. Seleksi kuota peserta bursa transfer (35%–50% dari total tim).
    final participationRatio = 0.35 + (_random.nextDouble() * 0.15);
    final targetActiveTeams =
        (workingTeams.length * participationRatio).round().clamp(2, workingTeams.length);

    // 2A. Jalur Langka: 1–3 kejadian Eksodus Massal atau Mega Transfer Terpecah.
    final rareEventCount = workingTeams.length >= 12 ? 1 + _random.nextInt(3) : 0;
    for (var i = 0; i < rareEventCount; i++) {
      if (usedTeamIds.length + 3 > targetActiveTeams) break;
      final preferExodus = _random.nextBool();
      final applied = preferExodus
          ? (_runExodusEvent(
                workingTeams: workingTeams,
                indexById: indexById,
                usedTeamIds: usedTeamIds,
                events: events,
                seasonNumber: seasonNumber,
                gameweek: gameweek,
                isEndOfSeason: isEndOfSeason,
                windowLabel: windowLabel,
                leagueNames: leagueNames,
                now: now,
              ) ||
              _runMegaTransferEvent(
                workingTeams: workingTeams,
                indexById: indexById,
                usedTeamIds: usedTeamIds,
                events: events,
                seasonNumber: seasonNumber,
                gameweek: gameweek,
                isEndOfSeason: isEndOfSeason,
                windowLabel: windowLabel,
                leagueNames: leagueNames,
                now: now,
              ))
          : (_runMegaTransferEvent(
                workingTeams: workingTeams,
                indexById: indexById,
                usedTeamIds: usedTeamIds,
                events: events,
                seasonNumber: seasonNumber,
                gameweek: gameweek,
                isEndOfSeason: isEndOfSeason,
                windowLabel: windowLabel,
                leagueNames: leagueNames,
                now: now,
              ) ||
              _runExodusEvent(
                workingTeams: workingTeams,
                indexById: indexById,
                usedTeamIds: usedTeamIds,
                events: events,
                seasonNumber: seasonNumber,
                gameweek: gameweek,
                isEndOfSeason: isEndOfSeason,
                windowLabel: windowLabel,
                leagueNames: leagueNames,
                now: now,
              ));

      if (!applied) break;
    }

    // Alokasi sisa kuota peserta ke Jalur B (~60% event) dan Jalur C (~30% event).
    // Karena 1 event Jalur B = 2 tim dan 1 event Jalur C = 1 tim (dipasangkan + & -),
    // proporsi sisa tim menjadi ~80% untuk Jalur B dan ~20% untuk Jalur C.
    final remainingBudget = max(0, targetActiveTeams - usedTeamIds.length);
    final oneOnOneCount = ((remainingBudget * 0.80) / 2).floor();
    final organicPairCount = max(0, ((remainingBudget - (oneOnOneCount * 2)) / 2).floor());

    // 2B. Jalur Utama: Transfer Antar-Klub 1-on-1 Lintas Region.
    for (var i = 0; i < oneOnOneCount; i++) {
      final executed = _runOneOnOneCrossRegionTransfer(
        workingTeams: workingTeams,
        indexById: indexById,
        usedTeamIds: usedTeamIds,
        events: events,
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        isEndOfSeason: isEndOfSeason,
        windowLabel: windowLabel,
        leagueNames: leagueNames,
        now: now,
      );
      if (!executed) break;
    }

    // 2C. Jalur Organik Seimbang: Pasangan Promosi Akademi (+X) & Regenerasi Skuad (-X).
    for (var i = 0; i < organicPairCount; i++) {
      final executed = _runBalancedOrganicPair(
        workingTeams: workingTeams,
        indexById: indexById,
        usedTeamIds: usedTeamIds,
        events: events,
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        isEndOfSeason: isEndOfSeason,
        windowLabel: windowLabel,
        now: now,
      );
      if (!executed) break;
    }

    return OvrUpdateResult(updatedTeams: workingTeams, events: events);
  }

  bool _runExodusEvent({
    required List<Team> workingTeams,
    required Map<String, int> indexById,
    required Set<String> usedTeamIds,
    required List<NewsEvent> events,
    required int seasonNumber,
    required int gameweek,
    required bool isEndOfSeason,
    required String windowLabel,
    required Map<String, String>? leagueNames,
    required DateTime now,
  }) {
    final victimCandidates = workingTeams
        .where((t) => !usedTeamIds.contains(t.id) && t.ovr >= 65)
        .toList();
    if (victimCandidates.isEmpty) return false;

    final victim = victimCandidates[_random.nextInt(victimCandidates.length)];
    final buyerPool = workingTeams
        .where((t) =>
            t.id != victim.id && !usedTeamIds.contains(t.id) && t.ovr <= 96)
        .toList();
    if (buyerPool.length < 2) return false;

    var totalPenalty = _rollRareTransferPoints();
    final maxPossiblePenalty = victim.ovr - minTeamOvrLimit;
    if (maxPossiblePenalty < 4) return false;
    totalPenalty = min(totalPenalty, maxPossiblePenalty);

    final minParts = max(2, (totalPenalty / 3.0).ceil());
    final maxParts = min(4, buyerPool.length);
    if (maxParts < 2) return false;

    var effectiveParts = minParts;
    if (maxParts < minParts) {
      totalPenalty = min(totalPenalty, maxParts * 3);
      effectiveParts = maxParts;
    } else {
      final upper = min(maxParts, totalPenalty);
      if (upper > minParts) {
        effectiveParts = minParts + _random.nextInt(upper - minParts + 1);
      }
    }

    final buyers = _pickCrossRegionPartners(
      pool: buyerPool,
      originLeagueId: victim.leagueId,
      count: effectiveParts,
    );
    if (buyers.length < effectiveParts) return false;

    final parts = _splitPoints(totalPenalty, effectiveParts);
    final buyerSummaries = <String>[];

    // Terapkan kenaikan ke tim pembeli terlebih dahulu untuk memastikan angka persis.
    var totalDistributed = 0;
    for (var i = 0; i < buyers.length; i++) {
      final buyer = buyers[i];
      final part = parts[i];
      final newOvr = min(100, buyer.ovr + part);
      final actualGain = newOvr - buyer.ovr;
      totalDistributed += actualGain;

      final bIdx = indexById[buyer.id]!;
      workingTeams[bIdx] = buyer.copyWith(
        ovr: newOvr,
        lastOvrChange: actualGain,
        seasonOvrStart: isEndOfSeason ? newOvr : buyer.seasonOvrStart,
      );
      usedTeamIds.add(buyer.id);

      final buyerLeague = _leagueDisplayName(buyer.leagueId, leagueNames);
      buyerSummaries.add('${buyer.name} ($buyerLeague +$actualGain)');

      final victimLeague = _leagueDisplayName(victim.leagueId, leagueNames);
      events.add(
        NewsEvent(
          id: _uuid.v4(),
          seasonNumber: seasonNumber,
          gameweek: gameweek,
          type: NewsEventType.transferWindow,
          title: '$windowLabel: ${buyer.name} (+$actualGain OVR)',
          description:
              '${buyer.name} ($buyerLeague) menampung pemain eksodus dari ${victim.name} ($victimLeague). OVR meningkat dari ${buyer.ovr} menjadi $newOvr (+$actualGain).',
          teamId: buyer.id,
          tournamentId: buyer.leagueId,
          ovrDelta: actualGain,
          timestamp: now,
        ),
      );
    }

    final appliedPenalty = min(totalDistributed, victim.ovr - minTeamOvrLimit);
    final victimNewOvr = victim.ovr - appliedPenalty;
    final vIdx = indexById[victim.id]!;
    workingTeams[vIdx] = victim.copyWith(
      ovr: victimNewOvr,
      lastOvrChange: -appliedPenalty,
      seasonOvrStart: isEndOfSeason ? victimNewOvr : victim.seasonOvrStart,
    );
    usedTeamIds.add(victim.id);

    events.add(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        type: NewsEventType.transferWindow,
        title: 'Eksodus Besar! ${victim.name} (-$appliedPenalty OVR)',
        description:
            '${victim.name} ditinggal sejumlah pemain andalan pada $windowLabel sehingga OVR turun dari ${victim.ovr} menjadi $victimNewOvr (-$appliedPenalty). Para pemainnya ditampung oleh ${buyerSummaries.join(', ')}.',
        teamId: victim.id,
        tournamentId: victim.leagueId,
        ovrDelta: -appliedPenalty,
        timestamp: now,
      ),
    );

    return true;
  }

  bool _runMegaTransferEvent({
    required List<Team> workingTeams,
    required Map<String, int> indexById,
    required Set<String> usedTeamIds,
    required List<NewsEvent> events,
    required int seasonNumber,
    required int gameweek,
    required bool isEndOfSeason,
    required String windowLabel,
    required Map<String, String>? leagueNames,
    required DateTime now,
  }) {
    final sultanCandidates = workingTeams
        .where((t) => !usedTeamIds.contains(t.id) && t.ovr <= 90)
        .toList();
    if (sultanCandidates.isEmpty) return false;

    final sultan = sultanCandidates[_random.nextInt(sultanCandidates.length)];
    final sellerPool = workingTeams
        .where((t) =>
            t.id != sultan.id && !usedTeamIds.contains(t.id) && t.ovr >= 60)
        .toList();
    if (sellerPool.length < 2) return false;

    var totalBonus = _rollRareTransferPoints();
    final maxPossibleBonus = 100 - sultan.ovr;
    if (maxPossibleBonus < 4) return false;
    totalBonus = min(totalBonus, maxPossibleBonus);

    final minParts = max(2, (totalBonus / 3.0).ceil());
    final maxParts = min(4, sellerPool.length);
    if (maxParts < 2) return false;

    var effectiveParts = minParts;
    if (maxParts < minParts) {
      totalBonus = min(totalBonus, maxParts * 3);
      effectiveParts = maxParts;
    } else {
      final upper = min(maxParts, totalBonus);
      if (upper > minParts) {
        effectiveParts = minParts + _random.nextInt(upper - minParts + 1);
      }
    }

    final sellers = _pickCrossRegionPartners(
      pool: sellerPool,
      originLeagueId: sultan.leagueId,
      count: effectiveParts,
    );
    if (sellers.length < effectiveParts) return false;

    final parts = _splitPoints(totalBonus, effectiveParts);
    final sellerSummaries = <String>[];
    final sultanLeague = _leagueDisplayName(sultan.leagueId, leagueNames);

    var totalAcquired = 0;
    for (var i = 0; i < sellers.length; i++) {
      final seller = sellers[i];
      final part = parts[i];
      final newOvr = max(minTeamOvrLimit, seller.ovr - part);
      final actualLoss = seller.ovr - newOvr;
      totalAcquired += actualLoss;

      final sIdx = indexById[seller.id]!;
      workingTeams[sIdx] = seller.copyWith(
        ovr: newOvr,
        lastOvrChange: -actualLoss,
        seasonOvrStart: isEndOfSeason ? newOvr : seller.seasonOvrStart,
      );
      usedTeamIds.add(seller.id);

      final sellerLeague = _leagueDisplayName(seller.leagueId, leagueNames);
      sellerSummaries.add('${seller.name} ($sellerLeague -$actualLoss)');

      events.add(
        NewsEvent(
          id: _uuid.v4(),
          seasonNumber: seasonNumber,
          gameweek: gameweek,
          type: NewsEventType.transferWindow,
          title: '$windowLabel: ${seller.name} (-$actualLoss OVR)',
          description:
              '${seller.name} ($sellerLeague) melepas pemain ke ${sultan.name} ($sultanLeague). OVR turun dari ${seller.ovr} menjadi $newOvr (-$actualLoss).',
          teamId: seller.id,
          tournamentId: seller.leagueId,
          ovrDelta: -actualLoss,
          timestamp: now,
        ),
      );
    }

    final appliedBonus = min(totalAcquired, 100 - sultan.ovr);
    final sultanNewOvr = sultan.ovr + appliedBonus;
    final kIdx = indexById[sultan.id]!;
    workingTeams[kIdx] = sultan.copyWith(
      ovr: sultanNewOvr,
      lastOvrChange: appliedBonus,
      seasonOvrStart: isEndOfSeason ? sultanNewOvr : sultan.seasonOvrStart,
    );
    usedTeamIds.add(sultan.id);

    events.add(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        type: NewsEventType.transferWindow,
        title: 'Mega Transfer! ${sultan.name} (+$appliedBonus OVR)',
        description:
            '${sultan.name} memborong pemain bintang pada $windowLabel dari ${sellerSummaries.join(', ')}. OVR melonjak dari ${sultan.ovr} menjadi $sultanNewOvr (+$appliedBonus).',
        teamId: sultan.id,
        tournamentId: sultan.leagueId,
        ovrDelta: appliedBonus,
        timestamp: now,
      ),
    );

    return true;
  }

  bool _runOneOnOneCrossRegionTransfer({
    required List<Team> workingTeams,
    required Map<String, int> indexById,
    required Set<String> usedTeamIds,
    required List<NewsEvent> events,
    required int seasonNumber,
    required int gameweek,
    required bool isEndOfSeason,
    required String windowLabel,
    required Map<String, String>? leagueNames,
    required DateTime now,
  }) {
    final buyerCandidates = workingTeams
        .where((t) => !usedTeamIds.contains(t.id) && t.ovr <= 97)
        .toList();
    if (buyerCandidates.isEmpty) return false;

    final buyer = buyerCandidates[_random.nextInt(buyerCandidates.length)];
    final allSellerCandidates = workingTeams
        .where((t) =>
            t.id != buyer.id && !usedTeamIds.contains(t.id) && t.ovr >= 55)
        .toList();
    if (allSellerCandidates.isEmpty) return false;

    // Utamakan pasangan dari region/liga berbeda bila tersedia.
    final crossRegionSellers = allSellerCandidates
        .where((t) => t.leagueId != buyer.leagueId)
        .toList();
    final sellerPool =
        crossRegionSellers.isNotEmpty ? crossRegionSellers : allSellerCandidates;
    final seller = sellerPool[_random.nextInt(sellerPool.length)];

    final rawX = _rollStandardTransferPoints();
    final maxAllowedGain = 100 - buyer.ovr;
    final maxAllowedLoss = seller.ovr - minTeamOvrLimit;
    final actualX = min(rawX, min(maxAllowedGain, maxAllowedLoss));
    if (actualX <= 0) return false;

    final buyerNewOvr = buyer.ovr + actualX;
    final sellerNewOvr = seller.ovr - actualX;

    final bIdx = indexById[buyer.id]!;
    final sIdx = indexById[seller.id]!;

    workingTeams[bIdx] = buyer.copyWith(
      ovr: buyerNewOvr,
      lastOvrChange: actualX,
      seasonOvrStart: isEndOfSeason ? buyerNewOvr : buyer.seasonOvrStart,
    );
    workingTeams[sIdx] = seller.copyWith(
      ovr: sellerNewOvr,
      lastOvrChange: -actualX,
      seasonOvrStart: isEndOfSeason ? sellerNewOvr : seller.seasonOvrStart,
    );
    usedTeamIds.add(buyer.id);
    usedTeamIds.add(seller.id);

    final buyerLeague = _leagueDisplayName(buyer.leagueId, leagueNames);
    final sellerLeague = _leagueDisplayName(seller.leagueId, leagueNames);

    events.add(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        type: NewsEventType.transferWindow,
        title:
            'Transfer Lintas Region: ${buyer.name} (+$actualX OVR) merekrut pemain dari ${seller.name} (-$actualX OVR)',
        description:
            '${buyer.name} ($buyerLeague) mendatangkan pemain baru dari ${seller.name} ($sellerLeague) pada $windowLabel. OVR ${buyer.name} naik ${buyer.ovr}→$buyerNewOvr, sedangkan ${seller.name} turun ${seller.ovr}→$sellerNewOvr.',
        teamId: buyer.id,
        secondaryTeamId: seller.id,
        tournamentId: buyer.leagueId,
        secondaryTournamentId: seller.leagueId,
        ovrDelta: actualX,
        timestamp: now,
      ),
    );

    return true;
  }

  bool _runBalancedOrganicPair({
    required List<Team> workingTeams,
    required Map<String, int> indexById,
    required Set<String> usedTeamIds,
    required List<NewsEvent> events,
    required int seasonNumber,
    required int gameweek,
    required bool isEndOfSeason,
    required String windowLabel,
    required DateTime now,
  }) {
    final x = _rollStandardTransferPoints();

    final posCandidates = workingTeams
        .where((t) => !usedTeamIds.contains(t.id) && (100 - t.ovr) >= x)
        .toList();
    if (posCandidates.isEmpty) return false;
    final posTeam = posCandidates[_random.nextInt(posCandidates.length)];

    final negCandidates = workingTeams
        .where((t) =>
            t.id != posTeam.id &&
            !usedTeamIds.contains(t.id) &&
            (t.ovr - minTeamOvrLimit) >= x)
        .toList();
    if (negCandidates.isEmpty) return false;
    final negTeam = negCandidates[_random.nextInt(negCandidates.length)];

    final posNewOvr = posTeam.ovr + x;
    final negNewOvr = negTeam.ovr - x;

    final pIdx = indexById[posTeam.id]!;
    final nIdx = indexById[negTeam.id]!;

    workingTeams[pIdx] = posTeam.copyWith(
      ovr: posNewOvr,
      lastOvrChange: x,
      seasonOvrStart: isEndOfSeason ? posNewOvr : posTeam.seasonOvrStart,
    );
    workingTeams[nIdx] = negTeam.copyWith(
      ovr: negNewOvr,
      lastOvrChange: -x,
      seasonOvrStart: isEndOfSeason ? negNewOvr : negTeam.seasonOvrStart,
    );

    usedTeamIds.add(posTeam.id);
    usedTeamIds.add(negTeam.id);

    events.add(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        type: NewsEventType.transferWindow,
        title: 'Promosi Akademi: ${posTeam.name} (+$x OVR)',
        description:
            '${posTeam.name} mengorbitkan talenta muda berbakat dari akademi pada $windowLabel. OVR meningkat dari ${posTeam.ovr} menjadi $posNewOvr (+$x).',
        teamId: posTeam.id,
        tournamentId: posTeam.leagueId,
        ovrDelta: x,
        timestamp: now,
      ),
    );

    events.add(
      NewsEvent(
        id: _uuid.v4(),
        seasonNumber: seasonNumber,
        gameweek: gameweek,
        type: NewsEventType.transferWindow,
        title: 'Regenerasi Skuad: ${negTeam.name} (-$x OVR)',
        description:
            'Beberapa pemain senior ${negTeam.name} pensiun atau mengalami penurunan performa pada $windowLabel. OVR turun dari ${negTeam.ovr} menjadi $negNewOvr (-$x).',
        teamId: negTeam.id,
        tournamentId: negTeam.leagueId,
        ovrDelta: -x,
        timestamp: now,
      ),
    );

    return true;
  }

  /// Memilih [count] tim partner dari [pool] dengan memprioritaskan tim dari
  /// liga berbeda ([originLeagueId]) agar tercipta perpindahan lintas region.
  List<Team> _pickCrossRegionPartners({
    required List<Team> pool,
    required String originLeagueId,
    required int count,
  }) {
    final differentRegion =
        pool.where((t) => t.leagueId != originLeagueId).toList()..shuffle(_random);
    final sameRegion =
        pool.where((t) => t.leagueId == originLeagueId).toList()..shuffle(_random);
    final combined = [...differentRegion, ...sameRegion];
    if (combined.length < count) return [];
    return combined.take(count).toList();
  }

  /// Memecah [total] menjadi [parts] bagian bernilai `1..3` yang berjumlah tepat [total].
  List<int> _splitPoints(int total, int parts) {
    final result = List<int>.filled(parts, 1);
    var remaining = total - parts;
    while (remaining > 0) {
      final eligibleIndices = <int>[
        for (var i = 0; i < result.length; i++)
          if (result[i] < 3) i,
      ];
      if (eligibleIndices.isEmpty) break;
      final chosen = eligibleIndices[_random.nextInt(eligibleIndices.length)];
      result[chosen]++;
      remaining--;
    }
    return result;
  }

  String _leagueDisplayName(
    String leagueId,
    Map<String, String>? leagueNames,
  ) {
    final custom = leagueNames?[leagueId]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final letter = leagueId.split('_').last.toUpperCase();
    return 'Liga $letter';
  }

  /// Besaran poin langka (Jalur A):
  /// 4 (40%), 5 (25%), 6 (15%), 7 (10%), 8 (5%), 9 (3%), 10 (2%).
  int _rollRareTransferPoints() {
    final roll = _random.nextInt(100);
    if (roll < 40) return 4;
    if (roll < 65) return 5;
    if (roll < 80) return 6;
    if (roll < 90) return 7;
    if (roll < 95) return 8;
    if (roll < 98) return 9;
    return 10;
  }

  /// Besaran nilai transfer standar (Jalur B & C):
  /// 1 OVR (55%), 2 OVR (30%), 3 OVR (15%).
  int _rollStandardTransferPoints() {
    final roll = _random.nextInt(100);
    if (roll < 55) return 1;
    if (roll < 85) return 2;
    return 3;
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
}
