import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_game.dart';
import '../models/standing_row.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/team_avatar.dart';
import 'tournament_detail_screen.dart';

/// Tab 1: Halaman daftar seluruh turnamen (5 Kontinental, 8 Liga Lokal A–H, 8 Cup Domestik A–H).
/// Seluruh kartu bebas scroll vertikal internal agar scrolling halaman utama tetap mulus.
class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  void _openDetail(BuildContext context, Tournament tournament) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentDetailScreen(tournamentId: tournament.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final tournaments = provider.tournaments;
    final teamsById = {for (final t in provider.teams) t.id: t};

    final continental = tournaments.where((t) => t.isContinental).toList()
      ..sort((a, b) => (a.tier ?? 99).compareTo(b.tier ?? 99));

    final localLeagues = tournaments
        .where((t) => t.type == TournamentType.localLeague)
        .toList()
      ..sort((a, b) => (a.leagueIndex ?? 99).compareTo(b.leagueIndex ?? 99));

    final domesticCups = tournaments
        .where((t) => t.type == TournamentType.domesticCup)
        .toList()
      ..sort((a, b) => (a.leagueIndex ?? 99).compareTo(b.leagueIndex ?? 99));

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 680 ? 2 : 1;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                title: 'Turnamen Kontinental',
                badge: '${continental.length} Ajang',
              ),
              const SizedBox(height: 10),
              if (continental.isEmpty)
                const _EmptyTournamentNotice(
                  message: 'Data turnamen kontinental belum tersedia.',
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: continental.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent:
                        continental.every((t) => !t.isActive) ? 140 : 260,
                  ),
                  itemBuilder: (context, index) {
                    final t = continental[index];
                    return _DynamicTournamentCard(
                      tournament: t,
                      provider: provider,
                      teamsById: teamsById,
                      onTap: () => _openDetail(context, t),
                    );
                  },
                ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Liga Lokal (A–H)',
                badge: '${localLeagues.length} Liga • 20 Tim',
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: localLeagues.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 260,
                ),
                itemBuilder: (context, index) {
                  final league = localLeagues[index];
                  return _DynamicTournamentCard(
                    tournament: league,
                    provider: provider,
                    teamsById: teamsById,
                    onTap: () => _openDetail(context, league),
                  );
                },
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Cup Domestik (A–H)',
                badge: '${domesticCups.length} Piala • 16 Tim',
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: domesticCups.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 260,
                ),
                itemBuilder: (context, index) {
                  final cup = domesticCups[index];
                  return _DynamicTournamentCard(
                    tournament: cup,
                    provider: provider,
                    teamsById: teamsById,
                    onTap: () => _openDetail(context, cup),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String badge;

  const _SectionHeader({required this.title, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.sectionHeader,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            badge,
            style: AppTheme.badge.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _DynamicTournamentCard extends StatelessWidget {
  final Tournament tournament;
  final GameStateProvider provider;
  final Map<String, Team> teamsById;
  final VoidCallback onTap;

  const _DynamicTournamentCard({
    required this.tournament,
    required this.provider,
    required this.teamsById,
    required this.onTap,
  });

  Color _accentColor() {
    if (tournament.type == TournamentType.localLeague) {
      return AppTheme.primaryBrand;
    }
    if (tournament.type == TournamentType.domesticCup) {
      return AppTheme.zoneChallenger;
    }
    switch (tournament.tier) {
      case 1:
        return AppTheme.zoneChampions;
      case 2:
        return AppTheme.zoneWinner;
      case 3:
        return AppTheme.zoneFederation;
      case 4:
        return AppTheme.zoneMidRange;
      case 5:
        return AppTheme.zoneChallenger;
      default:
        return AppTheme.secondaryAccent;
    }
  }

  String _continentalSubtitle(int? tier) {
    switch (tier) {
      case 1:
        return 'Rank 1–4 Liga A–H • Mulai Musim 2';
      case 2:
        return 'Rank 5–8 Liga A–H • Mulai Musim 2';
      case 3:
        return 'Rank 9–12 Liga A–H • Mulai Musim 2';
      case 4:
        return 'Rank 13–17 Liga A–H • Mulai Musim 2';
      case 5:
        return 'Rank 18–20 Liga A–H • Mulai Musim 2';
      default:
        return 'Mulai Musim 2';
    }
  }

  ({String left, String right}) _footerTexts({
    required bool isCompleted,
    required bool isCupOrKnockout,
    required bool hasMatches,
  }) {
    final teamCount = tournament.teamIds.length;
    if (!tournament.isActive || !hasMatches) {
      return (left: 'Belum Dimulai', right: 'Info Turnamen');
    }
    if (isCompleted) {
      return (
        left: 'Musim ${tournament.seasonNumber} Selesai',
        right: isCupOrKnockout ? 'Lihat Bagan Lengkap' : 'Lihat Klasemen',
      );
    }
    if (isCupOrKnockout) {
      return (left: tournament.currentStage, right: 'Bagan Lengkap');
    }
    final weekLabel = tournament.currentStage.trim().isNotEmpty
        ? tournament.currentStage
        : 'Pekan ${provider.currentGameweek}';
    final countLabel = teamCount > 0 ? 'Semua $teamCount Tim' : 'Semua Tim';
    return (left: weekLabel, right: countLabel);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final matches = provider.getMatchesForTournament(tournament.id);
    var champion = tournament.championTeamId != null
        ? teamsById[tournament.championTeamId!]
        : null;
    if (champion == null &&
        tournament.type == TournamentType.localLeague &&
        matches.isNotEmpty &&
        matches.every((m) => m.isFinished)) {
      final rows = provider.getStandings(tournament.id);
      if (rows.isNotEmpty) {
        champion = teamsById[rows.first.teamId];
      }
    }

    final hasKnockout = matches.any((m) => m.isKnockout);
    final isCupOrKnockout = tournament.type == TournamentType.domesticCup ||
        (tournament.isContinental && hasKnockout);

    final footer = _footerTexts(
      isCompleted: champion != null,
      isCupOrKnockout: isCupOrKnockout,
      hasMatches: matches.isNotEmpty,
    );

    return Material(
      color: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.borderHairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(accent),
            const Divider(height: 1, color: AppTheme.borderHairline),
            Expanded(
              child: _buildMiddleContent(
                matches: matches,
                champion: champion,
                hasKnockout: hasKnockout,
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderHairline),
            _buildFooter(
              leftLabel: footer.left,
              rightLabel: footer.right,
              accent: accent,
              isCompleted: champion != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    final isLeague = tournament.type == TournamentType.localLeague;
    final leagueLetter = (tournament.leagueIndex != null &&
            tournament.leagueIndex! >= 0 &&
            tournament.leagueIndex! < 8)
        ? String.fromCharCode(65 + tournament.leagueIndex!)
        : '?';

    return Container(
      color: AppTheme.surfaceSubtle.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: isLeague
                ? Text(
                    leagueLetter,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  )
                : Icon(
                    tournament.isContinental
                        ? Icons.public_rounded
                        : Icons.emoji_events_rounded,
                    size: 15,
                    color: accent,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tournament.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.cardTitle.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: tournament.isActive
                  ? accent.withValues(alpha: 0.12)
                  : AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color: tournament.isActive
                    ? accent.withValues(alpha: 0.25)
                    : AppTheme.borderHairline,
              ),
            ),
            child: Text(
              tournament.isActive ? 'M${tournament.seasonNumber}' : 'Non-Aktif',
              style: AppTheme.badge.copyWith(
                color: tournament.isActive ? accent : AppTheme.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleContent({
    required List<MatchGame> matches,
    required Team? champion,
    required bool hasKnockout,
  }) {
    // 1. Belum bergulir / belum punya pertandingan (contoh: Kontinental Musim 1).
    if (!tournament.isActive || matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 19,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum Bergulir',
                    style: AppTheme.cardTitle.copyWith(fontSize: 13),
                  ),
                  Text(
                    tournament.isContinental
                        ? _continentalSubtitle(tournament.tier)
                        : 'Menunggu jadwal pertandingan',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Sudah ada Tim Juara -> Showcase Juara.
    if (champion != null) {
      final rows = provider.getStandings(tournament.id);
      StandingRow? championRow;
      for (final r in rows) {
        if (r.teamId == champion.id) {
          championRow = r;
          break;
        }
      }

      final isCup = tournament.type == TournamentType.domesticCup;
      final badgeText = isCup
          ? 'JUARA CUP MUSIM ${tournament.seasonNumber}'
          : 'JUARA MUSIM ${tournament.seasonNumber}';
      final summaryText = championRow != null
          ? '${championRow.points} pts • OVR ${champion.ovr}'
          : 'OVR Akhir ${champion.ovr}';

      return _ChampionShowcaseBody(
        champion: champion,
        badgeText: badgeText,
        summaryText: summaryText,
      );
    }

    // 3. Cup Domestik atau Kontinental fase Knockout -> Mini-Bracket horizontal-only.
    if (tournament.type == TournamentType.domesticCup ||
        (tournament.isContinental && hasKnockout)) {
      return _MiniKnockoutBracket(
        matches: matches,
        teamsById: teamsById,
      );
    }

    // 4. Liga Lokal atau Kontinental League/Group Phase -> 5 Tim Teratas statis (Column).
    return _TopFiveStandingsBody(
      tournament: tournament,
      rows: provider.getStandings(tournament.id),
      teamsById: teamsById,
    );
  }

  Widget _buildFooter({
    required String leftLabel,
    required String rightLabel,
    required Color accent,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Text(
            leftLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.badge.copyWith(
              color: isCompleted ? accent : AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    rightLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AppTheme.badge.copyWith(
                      color: isCompleted ? accent : AppTheme.primaryBrand,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isCompleted ? accent : AppTheme.primaryBrand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFiveStandingsBody extends StatelessWidget {
  final Tournament tournament;
  final List<StandingRow> rows;
  final Map<String, Team> teamsById;

  const _TopFiveStandingsBody({
    required this.tournament,
    required this.rows,
    required this.teamsById,
  });

  List<({Team team, int points})> _buildTopFiveEntries() {
    final hasAnyPlayed = rows.any((r) => r.played > 0);
    if (rows.isEmpty || !hasAnyPlayed) {
      final participants = tournament.teamIds
          .map((id) => teamsById[id])
          .whereType<Team>()
          .toList()
        ..sort((a, b) {
          final ovrCmp = b.ovr.compareTo(a.ovr);
          return ovrCmp != 0 ? ovrCmp : a.name.compareTo(b.name);
        });
      return [
        for (final t in participants.take(5)) (team: t, points: 0),
      ];
    }

    final sortedRows = List<StandingRow>.from(rows);
    if (tournament.type == TournamentType.continentalGroup) {
      sortedRows.sort((a, b) {
        final ptsCmp = b.points.compareTo(a.points);
        if (ptsCmp != 0) return ptsCmp;
        final gdCmp = b.goalDifference.compareTo(a.goalDifference);
        if (gdCmp != 0) return gdCmp;
        final gfCmp = b.goalsFor.compareTo(a.goalsFor);
        if (gfCmp != 0) return gfCmp;
        final ovrA = teamsById[a.teamId]?.ovr ?? 0;
        final ovrB = teamsById[b.teamId]?.ovr ?? 0;
        return ovrB.compareTo(ovrA);
      });
    }

    final entries = <({Team team, int points})>[];
    for (final row in sortedRows) {
      final team = teamsById[row.teamId];
      if (team == null) continue;
      entries.add((team: team, points: row.points));
      if (entries.length == 5) break;
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildTopFiveEntries();
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada peserta.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderHairline,
              ),
            _TopTeamRow(
              rank: i + 1,
              team: entries[i].team,
              points: entries[i].points,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopTeamRow extends StatelessWidget {
  final int rank;
  final Team team;
  final int points;

  const _TopTeamRow({
    required this.rank,
    required this.team,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final ovrPalette = AppTheme.ovrColors(team.ovr);

    return SizedBox(
      height: 31,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: AppTheme.tabularNumberBold.copyWith(
                fontSize: 11,
                color: rank == 1 ? AppTheme.primaryBrand : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TeamAvatar(
            name: team.name,
            logoPath: team.logoPath,
            colorValue: team.colorValue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyPrimary.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$points pts',
            style: AppTheme.tabularNumberBold.copyWith(
              fontSize: 11.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: ovrPalette.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color: ovrPalette.foreground.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'OVR ${team.ovr}',
              style: AppTheme.badge.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ovrPalette.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChampionShowcaseBody extends StatelessWidget {
  final Team champion;
  final String badgeText;
  final String summaryText;

  const _ChampionShowcaseBody({
    required this.champion,
    required this.badgeText,
    required this.summaryText,
  });

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFD97706);
    const goldBg = Color(0xFFFEF3C7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            goldBg.withValues(alpha: 0.35),
            AppTheme.surfaceCard,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              TeamAvatar(
                name: champion.name,
                logoPath: champion.logoPath,
                colorValue: champion.colorValue,
                size: 48,
              ),
              Positioned(
                top: -6,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: goldBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 14,
                    color: goldColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            champion.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.sectionHeader.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: goldBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: goldColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badgeText,
              style: AppTheme.badge.copyWith(
                color: const Color(0xFF92400E),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summaryText,
            style: AppTheme.badge.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKnockoutBracket extends StatelessWidget {
  final List<MatchGame> matches;
  final Map<String, Team> teamsById;

  const _MiniKnockoutBracket({
    required this.matches,
    required this.teamsById,
  });

  List<({String title, List<List<MatchGame>> ties})> _buildVisibleStages(
    List<MatchGame> knockoutMatches,
  ) {
    const allStages = [
      'Play-off',
      '16 Besar',
      'Perempat Final',
      'Semifinal',
      'Final',
    ];

    final rawStages = <({String title, List<List<MatchGame>> ties})>[];
    for (final stage in allStages) {
      final stageMatches = knockoutMatches
          .where((m) => m.stageName.startsWith(stage))
          .toList();
      if (stageMatches.isEmpty) continue;

      final byTie = <String, List<MatchGame>>{};
      for (final m in stageMatches) {
        final key = m.tieId ?? m.id;
        byTie.putIfAbsent(key, () => []).add(m);
      }

      final ties = byTie.values.toList()
        ..sort(
          (a, b) =>
              (a.first.bracketSlot ?? 0).compareTo(b.first.bracketSlot ?? 0),
        );
      rawStages.add((title: stage, ties: ties));
    }

    if (rawStages.isEmpty) return const [];

    // Jika sudah masuk babak dengan <= 4 laga (Perempat Final s.d. Final),
    // tampilkan rangkaian babak tersebut agar selaras maksimal 4 duel per kolom.
    final compactStartIdx =
        rawStages.indexWhere((col) => col.ties.length <= 4);
    if (compactStartIdx != -1) {
      return rawStages.sublist(compactStartIdx);
    }

    // Jika baru ada babak awal dengan > 4 laga (misal 16 Besar / Play-off),
    // tampilkan maksimal 4 duel dari babak aktif/terbaru tanpa scroll vertikal.
    final latestStage = rawStages.last;
    final unfinishedFirst = [
      ...latestStage.ties.where((t) => t.any((m) => !m.isFinished)),
      ...latestStage.ties.where((t) => t.every((m) => m.isFinished)),
    ].take(4).toList()
      ..sort(
        (a, b) =>
            (a.first.bracketSlot ?? 0).compareTo(b.first.bracketSlot ?? 0),
      );

    return [
      (
        title: '${latestStage.title} (4/${latestStage.ties.length})',
        ties: unfinishedFirst,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final knockoutMatches = matches.where((m) => m.isKnockout).toList();
    if (knockoutMatches.isEmpty) {
      return const Center(
        child: Text(
          'Menunggu babak gugur...',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }

    final stageColumns = _buildVisibleStages(knockoutMatches);
    if (stageColumns.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada bagan gugur.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }

    const double duelStackHeight = 148.0;

    return SingleChildScrollView(
      primary: false,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < stageColumns.length; c++) ...[
            SizedBox(
              width: 154,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      stageColumns[c].title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.badge.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: duelStackHeight,
                    child: Column(
                      children: [
                        for (final tie in stageColumns[c].ties.take(4))
                          Expanded(
                            child: Center(
                              child: _MiniBracketDuelBox(
                                tieMatches: tie,
                                teamsById: teamsById,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (c < stageColumns.length - 1)
              _BracketConnectorColumn(
                leftTieCount: math.min(4, stageColumns[c].ties.length),
                rightTieCount: math.min(4, stageColumns[c + 1].ties.length),
                height: duelStackHeight,
              ),
          ],
        ],
      ),
    );
  }
}

class _BracketConnectorColumn extends StatelessWidget {
  final int leftTieCount;
  final int rightTieCount;
  final double height;

  const _BracketConnectorColumn({
    required this.leftTieCount,
    required this.rightTieCount,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final canPair = rightTieCount > 0 && leftTieCount == rightTieCount * 2;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: SizedBox(
        width: 16,
        height: height,
        child: canPair
            ? Column(
                children: [
                  for (var i = 0; i < rightTieCount; i++)
                    Expanded(
                      child: CustomPaint(
                        painter: _BracketPairLinesPainter(),
                        size: Size.infinite,
                      ),
                    ),
                ],
              )
            : CustomPaint(
                painter: _HorizontalConnectorPainter(),
                size: Size.infinite,
              ),
      ),
    );
  }
}

class _BracketPairLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final topY = size.height * 0.25;
    final bottomY = size.height * 0.75;
    final midY = size.height * 0.50;
    final midX = size.width * 0.50;

    final path = Path()
      ..moveTo(0, topY)
      ..lineTo(midX, topY)
      ..lineTo(midX, bottomY)
      ..lineTo(0, bottomY)
      ..moveTo(midX, midY)
      ..lineTo(size.width, midY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizontalConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final midY = size.height * 0.50;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBracketDuelBox extends StatelessWidget {
  final List<MatchGame> tieMatches;
  final Map<String, Team> teamsById;

  const _MiniBracketDuelBox({
    required this.tieMatches,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<MatchGame>.from(tieMatches)
      ..sort((a, b) => a.leg.compareTo(b.leg));
    final first = sorted.first;
    final second = sorted.length > 1 ? sorted[1] : null;
    final isTwoLeg = second != null;

    final teamAId = first.homeTeamId;
    final teamBId = first.awayTeamId;
    final teamA = teamsById[teamAId];
    final teamB = teamsById[teamBId];

    String scoreA = '-';
    String scoreB = '-';
    String? penA;
    String? penB;
    String? winnerId;

    if (!isTwoLeg) {
      if (first.isFinished) {
        scoreA = '${first.homeScore ?? 0}';
        scoreB = '${first.awayScore ?? 0}';
        winnerId = first.winnerTeamId;
        if (first.hasPenaltyShootout) {
          penA = 'P${first.homePenaltyScore ?? 0}';
          penB = 'P${first.awayPenaltyScore ?? 0}';
        }
      }
    } else {
      if (first.isFinished || second.isFinished) {
        final aggA = (first.homeScore ?? 0) + (second.awayScore ?? 0);
        final aggB = (first.awayScore ?? 0) + (second.homeScore ?? 0);
        scoreA = '$aggA';
        scoreB = '$aggB';
        if (first.isFinished && second.isFinished) {
          if (aggA > aggB) {
            winnerId = teamAId;
          } else if (aggB > aggA) {
            winnerId = teamBId;
          } else if (second.hasPenaltyShootout) {
            final pA = second.homeTeamId == teamAId
                ? (second.homePenaltyScore ?? 0)
                : (second.awayPenaltyScore ?? 0);
            final pB = second.homeTeamId == teamBId
                ? (second.homePenaltyScore ?? 0)
                : (second.awayPenaltyScore ?? 0);
            winnerId = pA >= pB ? teamAId : teamBId;
            penA = 'P$pA';
            penB = 'P$pB';
          }
        }
      }
    }

    final allFinished = sorted.every((m) => m.isFinished);

    return Container(
      width: 154,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniBracketTeamLine(
            team: teamA,
            fallback: 'Tim A',
            score: scoreA,
            penaltyLabel: penA,
            isWinner: allFinished && winnerId == teamAId,
            isLoser: allFinished && winnerId != null && winnerId != teamAId,
          ),
          const Divider(height: 3, thickness: 0.5, color: AppTheme.borderHairline),
          _MiniBracketTeamLine(
            team: teamB,
            fallback: 'Tim B',
            score: scoreB,
            penaltyLabel: penB,
            isWinner: allFinished && winnerId == teamBId,
            isLoser: allFinished && winnerId != null && winnerId != teamBId,
          ),
        ],
      ),
    );
  }
}

class _MiniBracketTeamLine extends StatelessWidget {
  final Team? team;
  final String fallback;
  final String score;
  final String? penaltyLabel;
  final bool isWinner;
  final bool isLoser;

  const _MiniBracketTeamLine({
    required this.team,
    required this.fallback,
    required this.score,
    required this.penaltyLabel,
    required this.isWinner,
    required this.isLoser,
  });

  @override
  Widget build(BuildContext context) {
    final name = team?.name ?? fallback;
    return SizedBox(
      height: 13,
      child: Row(
        children: [
          TeamAvatar(
            name: name,
            logoPath: team?.logoPath,
            colorValue: team?.colorValue ?? 0xFF1D4ED8,
            size: 12,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyPrimary.copyWith(
                fontSize: 10,
                height: 1.1,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                color: isLoser ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
          ),
          if (penaltyLabel != null) ...[
            const SizedBox(width: 3),
            Text(
              penaltyLabel!,
              style: AppTheme.tabularNumberBold.copyWith(
                fontSize: 8.5,
                height: 1.1,
                color: AppTheme.secondaryAccent,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            score,
            style: AppTheme.tabularNumberBold.copyWith(
              fontSize: 10.5,
              height: 1.1,
              color: isWinner ? AppTheme.primaryBrand : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTournamentNotice extends StatelessWidget {
  final String message;

  const _EmptyTournamentNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Text(message, style: AppTheme.body),
    );
  }
}
