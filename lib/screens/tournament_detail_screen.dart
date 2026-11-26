import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_game.dart';
import '../models/news_event.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/h2h_bottom_sheet.dart';
import '../widgets/match_card.dart';
import '../widgets/ovr_badge.dart';
import '../widgets/rename_tournament_dialog.dart';
import '../widgets/standing_table.dart';
import '../widgets/team_avatar.dart';
import 'team_detail_screen.dart';

/// Halaman detail satu turnamen dengan 4 tab:
/// 1. Klasemen / Bagan Knockout
/// 2. Jadwal & Hasil
/// 3. Statistik Tim (& Pot/Grup hasil drawing)
/// 4. News Feed (Transfer Window, Cedera, Chaotic Match, Juara)
class TournamentDetailScreen extends StatelessWidget {
  final String tournamentId;

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final tournament = provider.getTournamentById(tournamentId);

    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Info Turnamen')),
        body: const Center(
          child: Text('Turnamen tidak ditemukan.'),
        ),
      );
    }

    if (!tournament.isActive) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tournament.name),
          actions: [
            IconButton(
              tooltip: 'Ubah Nama Turnamen',
              icon: const Icon(Icons.edit),
              onPressed: () => showRenameTournamentDialog(
                context,
                tournamentId: tournament.id,
                currentName: tournament.name,
              ),
            ),
          ],
        ),
        body: _InactiveContinentalView(tournament: tournament),
      );
    }

    final firstTabLabel =
        tournament.type == TournamentType.domesticCup ? 'Bagan' : 'Klasemen';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tournament.name, style: AppTheme.appBarTitle),
              Text(
                'Musim ${tournament.seasonNumber} • ${tournament.currentStage}',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Ubah Nama Liga / Turnamen',
              icon: const Icon(Icons.edit),
              onPressed: () => showRenameTournamentDialog(
                context,
                tournamentId: tournament.id,
                currentName: tournament.name,
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: firstTabLabel),
              const Tab(text: 'Jadwal'),
              const Tab(text: 'Statistik'),
              const Tab(text: 'News Feed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StandingsOrBracketTab(tournament: tournament),
            _ScheduleAndResultsTab(tournament: tournament),
            _StatisticsTab(tournament: tournament),
            _NewsFeedTab(tournament: tournament),
          ],
        ),
      ),
    );
  }
}

class _InactiveContinentalView extends StatelessWidget {
  final Tournament tournament;

  const _InactiveContinentalView({required this.tournament});

  String _qualificationText(int? tier) {
    switch (tier) {
      case 1:
        return 'Diikuti oleh 32 tim peringkat 1–4 dari seluruh Liga A–H. Menggunakan format League Phase (8 matchday) dilanjutkan Play-off dan Fase Gugur 2 Leg.';
      case 2:
        return 'Diikuti oleh 32 tim peringkat 5–8 dari seluruh Liga A–H. Menggunakan format League Phase (8 matchday) dilanjutkan Play-off dan Fase Gugur 2 Leg.';
      case 3:
        return 'Diikuti oleh 32 tim peringkat 9–12 dari seluruh Liga A–H. Menggunakan format League Phase (8 matchday) dilanjutkan Play-off dan Fase Gugur 2 Leg.';
      case 4:
        return 'Diikuti oleh 40 tim peringkat 13–17 dari seluruh Liga A–H (8 Grup berisi 5 tim). Rank 1–2 lolos ke 16 Besar, sedangkan Rank 3 turun ke 16 Besar Challenger League.';
      case 5:
        return 'Diikuti oleh 24 tim peringkat 18–20 dari seluruh Liga A–H (8 Grup berisi 3 tim). Juara grup lolos ke 16 Besar bergabung dengan Rank 3 grup Mid Range League.';
      default:
        return 'Turnamen Kontinental akan otomatis bergulir mulai Musim 2.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding * 1.5),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderHairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppTheme.eventInfoBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppTheme.secondaryAccent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Bergulir',
                style: AppTheme.appBarTitle.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Menunggu Hasil Klasemen Akhir Musim ${tournament.seasonNumber}',
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(color: AppTheme.secondaryAccent),
              ),
              const SizedBox(height: 12),
              Text(
                _qualificationText(tournament.tier),
                textAlign: TextAlign.center,
                style: AppTheme.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 1: Klasemen & Bagan Knockout
// =============================================================================

class _StandingsOrBracketTab extends StatefulWidget {
  final Tournament tournament;

  const _StandingsOrBracketTab({required this.tournament});

  @override
  State<_StandingsOrBracketTab> createState() => _StandingsOrBracketTabState();
}

class _StandingsOrBracketTabState extends State<_StandingsOrBracketTab> {
  int _continentalSubView = 0; // 0 = Klasemen/Grup, 1 = Bagan Knockout

  void _openTeam(BuildContext context, String teamId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamDetailScreen(teamId: teamId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final teamsById = {for (final t in provider.teams) t.id: t};
    final matches = provider.getMatchesForTournament(widget.tournament.id);
    final champion = widget.tournament.championTeamId != null
        ? teamsById[widget.tournament.championTeamId!]
        : null;
    final runnerUp = widget.tournament.runnerUpTeamId != null
        ? teamsById[widget.tournament.runnerUpTeamId!]
        : null;

    if (widget.tournament.type == TournamentType.domesticCup) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (champion != null) ...[
              _ChampionBanner(
                champion: champion,
                runnerUp: runnerUp,
                tournamentName: widget.tournament.name,
                onTapTeam: (id) => _openTeam(context, id),
              ),
              const SizedBox(height: 14),
            ],
            _KnockoutBracketView(
              tournament: widget.tournament,
              matches: matches,
              teamsById: teamsById,
              isTwoLeg: false,
              onTeamTap: (id) => _openTeam(context, id),
            ),
          ],
        ),
      );
    }

    if (widget.tournament.type == TournamentType.localLeague) {
      final rows = provider.getStandings(widget.tournament.id);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (champion != null) ...[
              _ChampionBanner(
                champion: champion,
                runnerUp: runnerUp,
                tournamentName: widget.tournament.name,
                onTapTeam: (id) => _openTeam(context, id),
              ),
              const SizedBox(height: 14),
            ],
            StandingTable(
              rows: rows,
              teamsById: teamsById,
              zoneType: StandingZoneType.localLeague,
              onTeamTap: (id) => _openTeam(context, id),
            ),
          ],
        ),
      );
    }

    // Continental League Phase atau Group Phase
    final hasKnockout = matches.any((m) => m.isKnockout);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (champion != null) ...[
            _ChampionBanner(
              champion: champion,
              runnerUp: runnerUp,
              tournamentName: widget.tournament.name,
              onTapTeam: (id) => _openTeam(context, id),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentButton(
                    label: widget.tournament.type ==
                            TournamentType.continentalLeague
                        ? 'Klasemen League Phase'
                        : 'Klasemen Grup',
                    selected: _continentalSubView == 0,
                    onTap: () => setState(() => _continentalSubView = 0),
                  ),
                ),
                Expanded(
                  child: _SegmentButton(
                    label: hasKnockout
                        ? 'Bagan Knockout'
                        : 'Bagan (Menunggu)',
                    selected: _continentalSubView == 1,
                    onTap: () => setState(() => _continentalSubView = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_continentalSubView == 0)
            _buildContinentalStandings(provider, teamsById)
          else
            _KnockoutBracketView(
              tournament: widget.tournament,
              matches: matches,
              teamsById: teamsById,
              isTwoLeg: true,
              onTeamTap: (id) => _openTeam(context, id),
            ),
        ],
      ),
    );
  }

  Widget _buildContinentalStandings(
    GameStateProvider provider,
    Map<String, Team> teamsById,
  ) {
    if (widget.tournament.type == TournamentType.continentalLeague) {
      final rows = provider.getStandings(widget.tournament.id);
      return StandingTable(
        rows: rows,
        teamsById: teamsById,
        zoneType: StandingZoneType.continentalLeaguePhase,
        onTeamTap: (id) => _openTeam(context, id),
      );
    }

    final groupKeys = widget.tournament.potsOrGroups.keys.toList()..sort();
    final isMidRange = widget.tournament.id.startsWith('mid_range_');
    final zoneType = isMidRange
        ? StandingZoneType.continentalGroupMidRange
        : StandingZoneType.continentalGroupChallenger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groupKeys.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(groupKeys[i], style: AppTheme.sectionHeader),
          ),
          StandingTable(
            rows: provider.getStandings(
              widget.tournament.id,
              groupName: groupKeys[i],
            ),
            teamsById: teamsById,
            zoneType: zoneType,
            showLegend: i == groupKeys.length - 1,
            onTeamTap: (id) => _openTeam(context, id),
          ),
          if (i < groupKeys.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.caption.copyWith(
            color: selected ? AppTheme.primaryBrand : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  final Team champion;
  final Team? runnerUp;
  final String tournamentName;
  final ValueChanged<String> onTapTeam;

  const _ChampionBanner({
    required this.champion,
    required this.runnerUp,
    required this.tournamentName,
    required this.onTapTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.ovrEliteBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBrand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => onTapTeam(champion.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Juara $tournamentName',
                    style: AppTheme.badge.copyWith(
                      color: AppTheme.ovrEliteText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      TeamAvatar(
                        name: champion.name,
                        logoPath: champion.logoPath,
                        colorValue: champion.colorValue,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          champion.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.cardTitle.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (runnerUp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Runner-up: ${runnerUp!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnockoutBracketView extends StatelessWidget {
  final Tournament tournament;
  final List<MatchGame> matches;
  final Map<String, Team> teamsById;
  final bool isTwoLeg;
  final ValueChanged<String> onTeamTap;

  const _KnockoutBracketView({
    required this.tournament,
    required this.matches,
    required this.teamsById,
    required this.isTwoLeg,
    required this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    final knockoutMatches = matches.where((m) => m.isKnockout).toList();
    if (knockoutMatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.borderHairline),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 36,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'Bagan Fase Gugur Belum Dimulai',
              style: AppTheme.cardTitle,
            ),
            const SizedBox(height: 4),
            Text(
              'Pasangan babak gugur akan muncul otomatis setelah fase sebelumnya selesai.',
              textAlign: TextAlign.center,
              style: AppTheme.body,
            ),
          ],
        ),
      );
    }

    final stageOrder = <String>[
      if (tournament.type == TournamentType.continentalLeague) 'Play-off',
      '16 Besar',
      'Perempat Final',
      'Semifinal',
      'Final',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stageOrder.length; i++) ...[
            _BracketStageColumn(
              stageTitle: stageOrder[i],
              matches: knockoutMatches
                  .where((m) => m.stageName.startsWith(stageOrder[i]))
                  .toList(),
              teamsById: teamsById,
              onTeamTap: onTeamTap,
            ),
            if (i < stageOrder.length - 1) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _BracketStageColumn extends StatelessWidget {
  final String stageTitle;
  final List<MatchGame> matches;
  final Map<String, Team> teamsById;
  final ValueChanged<String> onTeamTap;

  const _BracketStageColumn({
    required this.stageTitle,
    required this.matches,
    required this.teamsById,
    required this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kelompokkan berdasarkan tieId (untuk 2 leg) atau match.id (untuk 1 leg).
    final byTie = <String, List<MatchGame>>{};
    for (final m in matches) {
      final key = m.tieId ?? m.id;
      byTie.putIfAbsent(key, () => []).add(m);
    }
    final ties = byTie.values.toList()
      ..sort(
        (a, b) => (a.first.bracketSlot ?? 0).compareTo(b.first.bracketSlot ?? 0),
      );

    return SizedBox(
      width: 248,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
            child: Text(
              stageTitle,
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          if (ties.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: AppTheme.borderHairline),
              ),
              child: Text(
                'Menunggu babak sebelumnya',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < ties.length; i++) ...[
              _BracketTieCard(
                tieMatches: ties[i],
                teamsById: teamsById,
                onTeamTap: onTeamTap,
              ),
              if (i < ties.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _BracketTieCard extends StatelessWidget {
  final List<MatchGame> tieMatches;
  final Map<String, Team> teamsById;
  final ValueChanged<String> onTeamTap;

  const _BracketTieCard({
    required this.tieMatches,
    required this.teamsById,
    required this.onTeamTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<MatchGame>.from(tieMatches)
      ..sort((a, b) => a.leg.compareTo(b.leg));
    final first = sorted.first;
    final second = sorted.length > 1 ? sorted[1] : null;

    final teamAId = first.homeTeamId;
    final teamBId = first.awayTeamId;
    final teamA = teamsById[teamAId];
    final teamB = teamsById[teamBId];

    // Hitung skor agregat jika 2 leg
    final isTwoLeg = second != null;
    final allFinished = sorted.every((m) => m.isFinished);

    int? aggA;
    int? aggB;
    String? winnerId;
    String? penLabel;

    if (!isTwoLeg) {
      if (first.isFinished) {
        aggA = first.homeScore ?? 0;
        aggB = first.awayScore ?? 0;
        winnerId = first.winnerTeamId;
        if (first.hasPenaltyShootout) {
          penLabel =
              'Pen ${first.homePenaltyScore}-${first.awayPenaltyScore}';
        }
      }
    } else {
      if (first.isFinished && second.isFinished) {
        aggA = (first.homeScore ?? 0) + (second.awayScore ?? 0);
        aggB = (first.awayScore ?? 0) + (second.homeScore ?? 0);
        if (aggA > aggB) {
          winnerId = teamAId;
        } else if (aggB > aggA) {
          winnerId = teamBId;
        } else if (second.hasPenaltyShootout) {
          final pH = second.homePenaltyScore ?? 0; // teamB di leg 2
          final pA = second.awayPenaltyScore ?? 0; // teamA di leg 2
          winnerId = pH > pA ? second.homeTeamId : second.awayTeamId;
          penLabel = 'Pen $pA-$pH';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BracketTeamRow(
            team: teamA,
            fallbackName: 'Tim A',
            scoreText: aggA != null ? '$aggA' : '-',
            isWinner: allFinished && winnerId == teamAId,
            isLoser: allFinished && winnerId != null && winnerId != teamAId,
            onTap: () => onTeamTap(teamAId),
          ),
          const Divider(height: 12, color: AppTheme.borderHairline),
          _BracketTeamRow(
            team: teamB,
            fallbackName: 'Tim B',
            scoreText: aggB != null ? '$aggB' : '-',
            isWinner: allFinished && winnerId == teamBId,
            isLoser: allFinished && winnerId != null && winnerId != teamBId,
            onTap: () => onTeamTap(teamBId),
          ),
          if (isTwoLeg || penLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (isTwoLeg)
                  'L1: ${first.isFinished ? '${first.homeScore}-${first.awayScore}' : 'vs'} • L2: ${second.isFinished ? '${second.awayScore}-${second.homeScore}' : 'vs'}',
                ?penLabel,
              ].join(' • '),
              textAlign: TextAlign.center,
              style: AppTheme.badge.copyWith(
                fontSize: 10,
                color: penLabel != null
                    ? AppTheme.secondaryAccent
                    : AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BracketTeamRow extends StatelessWidget {
  final Team? team;
  final String fallbackName;
  final String scoreText;
  final bool isWinner;
  final bool isLoser;
  final VoidCallback onTap;

  const _BracketTeamRow({
    required this.team,
    required this.fallbackName,
    required this.scoreText,
    required this.isWinner,
    required this.isLoser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = team?.name ?? fallbackName;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          TeamAvatar(
            name: name,
            logoPath: team?.logoPath,
            colorValue: team?.colorValue ?? 0xFF1D4ED8,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyPrimary.copyWith(
                fontSize: 12.5,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                color: isLoser ? AppTheme.textMuted : AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            scoreText,
            style: AppTheme.tabularNumberBold.copyWith(
              fontSize: 13,
              color: isWinner ? AppTheme.primaryBrand : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 2: Jadwal & Hasil
// =============================================================================

class _ScheduleAndResultsTab extends StatefulWidget {
  final Tournament tournament;

  const _ScheduleAndResultsTab({required this.tournament});

  @override
  State<_ScheduleAndResultsTab> createState() => _ScheduleAndResultsTabState();
}

class _ScheduleAndResultsTabState extends State<_ScheduleAndResultsTab> {
  String _statusFilter = 'all'; // 'all', 'upcoming', 'finished'

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final teamsById = {for (final t in provider.teams) t.id: t};
    var matches = List<MatchGame>.from(
      provider.getMatchesForTournament(widget.tournament.id),
    );

    if (_statusFilter == 'upcoming') {
      matches = matches.where((m) => !m.isFinished).toList();
    } else if (_statusFilter == 'finished') {
      matches = matches.where((m) => m.isFinished).toList();
    }

    matches.sort((a, b) {
      final gwCmp = a.gameweek.compareTo(b.gameweek);
      if (gwCmp != 0) return gwCmp;
      return a.stageName.compareTo(b.stageName);
    });

    // Kelompokkan berdasarkan stageName agar rapi
    final grouped = <String, List<MatchGame>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.stageName, () => []).add(m);
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
            vertical: 10,
          ),
          color: AppTheme.surfaceCard,
          child: Row(
            children: [
              _FilterChipItem(
                label: 'Semua',
                selected: _statusFilter == 'all',
                onTap: () => setState(() => _statusFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChipItem(
                label: 'Belum Main',
                selected: _statusFilter == 'upcoming',
                onTap: () => setState(() => _statusFilter = 'upcoming'),
              ),
              const SizedBox(width: 8),
              _FilterChipItem(
                label: 'Selesai',
                selected: _statusFilter == 'finished',
                onTap: () => setState(() => _statusFilter = 'finished'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderHairline),
        Expanded(
          child: matches.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada pertandingan pada filter ini.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final stage = grouped.keys.elementAt(index);
                    final stageMatches = grouped[stage]!;
                    final gw = stageMatches.first.gameweek;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  stage,
                                  style: AppTheme.sectionHeader,
                                ),
                              ),
                              Text(
                                'Pekan $gw',
                                style: AppTheme.badge.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (var i = 0; i < stageMatches.length; i++) ...[
                            MatchCard(
                              match: stageMatches[i],
                              homeTeam: teamsById[stageMatches[i].homeTeamId],
                              awayTeam: teamsById[stageMatches[i].awayTeamId],
                              showTournamentBadge: false,
                              probabilities: stageMatches[i].isFinished
                                  ? null
                                  : provider
                                      .getMatchProbabilities(stageMatches[i]),
                              onSimulate: stageMatches[i].isFinished
                                  ? null
                                  : () => provider
                                      .simulateSingleMatch(stageMatches[i].id),
                              onHeadToHead: () => showHeadToHeadBottomSheet(
                                context,
                                teamAId: stageMatches[i].homeTeamId,
                                teamBId: stageMatches[i].awayTeamId,
                              ),
                            ),
                            if (i < stageMatches.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryBrand,
      backgroundColor: AppTheme.surfaceSubtle,
      labelStyle: AppTheme.caption.copyWith(
        color: selected ? Colors.white : AppTheme.textSecondary,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

// =============================================================================
// TAB 3: Statistik Tim & Pot/Grup Drawing
// =============================================================================

class _StatisticsTab extends StatelessWidget {
  final Tournament tournament;

  const _StatisticsTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final teamsById = {for (final t in provider.teams) t.id: t};
    final matches = provider.getMatchesForTournament(tournament.id);
    final finished = matches.where((m) => m.isFinished).toList();

    // Hitung statistik gol langsung dari pertandingan turnamen (berfungsi untuk Liga, Grup, dan Cup!)
    final gfMap = <String, int>{for (final id in tournament.teamIds) id: 0};
    final gaMap = <String, int>{for (final id in tournament.teamIds) id: 0};
    final playedMap = <String, int>{for (final id in tournament.teamIds) id: 0};

    MatchGame? biggestMatch;
    for (final m in finished) {
      final hg = m.homeScore ?? 0;
      final ag = m.awayScore ?? 0;
      gfMap[m.homeTeamId] = (gfMap[m.homeTeamId] ?? 0) + hg;
      gaMap[m.homeTeamId] = (gaMap[m.homeTeamId] ?? 0) + ag;
      playedMap[m.homeTeamId] = (playedMap[m.homeTeamId] ?? 0) + 1;

      gfMap[m.awayTeamId] = (gfMap[m.awayTeamId] ?? 0) + ag;
      gaMap[m.awayTeamId] = (gaMap[m.awayTeamId] ?? 0) + hg;
      playedMap[m.awayTeamId] = (playedMap[m.awayTeamId] ?? 0) + 1;

      if (biggestMatch == null || m.totalGoals > biggestMatch.totalGoals) {
        biggestMatch = m;
      }
    }

    String? topScorerId;
    String? bestDefId;
    for (final id in tournament.teamIds) {
      if ((playedMap[id] ?? 0) == 0) continue;
      if (topScorerId == null || (gfMap[id] ?? 0) > (gfMap[topScorerId] ?? 0)) {
        topScorerId = id;
      }
      if (bestDefId == null || (gaMap[id] ?? 0) < (gaMap[bestDefId] ?? 0)) {
        bestDefId = id;
      }
    }

    final participantTeams = tournament.teamIds
        .map((id) => teamsById[id])
        .whereType<Team>()
        .toList()
      ..sort((a, b) => b.ovr.compareTo(a.ovr));

    final avgOvr = participantTeams.isEmpty
        ? 0
        : (participantTeams.fold<int>(0, (s, t) => s + t.ovr) /
                participantTeams.length)
            .round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatHighlightCard(
                  title: 'Tim Tersubur',
                  icon: Icons.sports_soccer_rounded,
                  accent: AppTheme.primaryBrand,
                  team: topScorerId != null ? teamsById[topScorerId] : null,
                  metric: topScorerId != null
                      ? '${gfMap[topScorerId]} Gol'
                      : 'Belum ada laga',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatHighlightCard(
                  title: 'Pertahanan Terbaik',
                  icon: Icons.shield_rounded,
                  accent: AppTheme.secondaryAccent,
                  team: bestDefId != null ? teamsById[bestDefId] : null,
                  metric: bestDefId != null
                      ? '${gaMap[bestDefId]} Kebobolan'
                      : 'Belum ada laga',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.borderHairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniInfoColumn(
                    label: 'Peserta',
                    value: '${participantTeams.length} Tim',
                  ),
                ),
                Expanded(
                  child: _MiniInfoColumn(
                    label: 'Rata-rata OVR',
                    value: '$avgOvr',
                  ),
                ),
                Expanded(
                  child: _MiniInfoColumn(
                    label: 'Laga Selesai',
                    value: '${finished.length}/${matches.length}',
                  ),
                ),
              ],
            ),
          ),
          if (biggestMatch != null) ...[
            const SizedBox(height: 10),
            _BiggestMatchBox(
              match: biggestMatch,
              home: teamsById[biggestMatch.homeTeamId],
              away: teamsById[biggestMatch.awayTeamId],
            ),
          ],
          if (tournament.potsOrGroups.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Hasil Drawing (Pot / Grup)', style: AppTheme.sectionHeader),
            const SizedBox(height: 10),
            for (final entry in tournament.potsOrGroups.entries) ...[
              _DrawingPotCard(
                title: entry.key,
                teamIds: entry.value,
                teamsById: teamsById,
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 14),
          Text(
            'Daftar Peserta (${participantTeams.length} Tim)',
            style: AppTheme.sectionHeader,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.borderHairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < participantTeams.length; i++) ...[
                  _ParticipantRow(
                    team: participantTeams[i],
                    rank: i + 1,
                    goalsFor: gfMap[participantTeams[i].id] ?? 0,
                    goalsAgainst: gaMap[participantTeams[i].id] ?? 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TeamDetailScreen(teamId: participantTeams[i].id),
                        ),
                      );
                    },
                  ),
                  if (i < participantTeams.length - 1)
                    const Divider(height: 1, color: AppTheme.borderHairline),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatHighlightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Team? team;
  final String metric;

  const _StatHighlightCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.team,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.badge.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (team != null)
            Row(
              children: [
                TeamAvatar(
                  name: team!.name,
                  logoPath: team!.logoPath,
                  colorValue: team!.colorValue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    team!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.cardTitle.copyWith(fontSize: 13),
                  ),
                ),
              ],
            )
          else
            Text('-', style: AppTheme.cardTitle),
          const SizedBox(height: 6),
          Text(
            metric,
            style: AppTheme.tabularNumberBold.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTheme.badge),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.tabularNumberBold.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}

class _BiggestMatchBox extends StatelessWidget {
  final MatchGame match;
  final Team? home;
  final Team? away;

  const _BiggestMatchBox({
    required this.match,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.chaoticBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppTheme.chaoticText,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skor Terbesar • ${match.stageName}',
                  style: AppTheme.badge.copyWith(color: AppTheme.chaoticText),
                ),
                const SizedBox(height: 2),
                Text(
                  '${home?.name ?? "Home"} ${match.homeScore ?? 0} - ${match.awayScore ?? 0} ${away?.name ?? "Away"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPotCard extends StatelessWidget {
  final String title;
  final List<String> teamIds;
  final Map<String, Team> teamsById;

  const _DrawingPotCard({
    required this.title,
    required this.teamIds,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.cardTitle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in teamIds)
                if (teamsById[id] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TeamAvatar(
                          name: teamsById[id]!.name,
                          logoPath: teamsById[id]!.logoPath,
                          colorValue: teamsById[id]!.colorValue,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          teamsById[id]!.name,
                          style: AppTheme.badge.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final Team team;
  final int rank;
  final int goalsFor;
  final int goalsAgainst;
  final VoidCallback onTap;

  const _ParticipantRow({
    required this.team,
    required this.rank,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: AppTheme.tabularNumberBold.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            TeamAvatar(
              name: team.name,
              logoPath: team.logoPath,
              colorValue: team.colorValue,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
                  ),
                  Text(
                    'GF $goalsFor • GA $goalsAgainst',
                    style: AppTheme.badge.copyWith(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            OvrBadge(
              ovr: team.ovr,
              ovrChange: team.lastOvrChange,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 4: News Feed (Log Transfer Window, Cedera, Event Turnamen)
// =============================================================================

class _NewsFeedTab extends StatefulWidget {
  final Tournament tournament;

  const _NewsFeedTab({required this.tournament});

  @override
  State<_NewsFeedTab> createState() => _NewsFeedTabState();
}

class _NewsFeedTabState extends State<_NewsFeedTab> {
  String _typeFilter = 'all'; // 'all', 'transfer', 'injury', 'match'

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final teamIdSet = widget.tournament.teamIds.toSet();

    String? baseLeagueId;
    if (widget.tournament.leagueIndex != null &&
        widget.tournament.leagueIndex! < GameStateProvider.leagueIds.length) {
      baseLeagueId = GameStateProvider.leagueIds[widget.tournament.leagueIndex!];
    }

    var events = provider.newsEvents.where((e) {
      final matchesTournament = e.tournamentId == widget.tournament.id ||
          (baseLeagueId != null && e.tournamentId == baseLeagueId);
      final matchesTeam = e.teamId != null && teamIdSet.contains(e.teamId);
      return matchesTournament || matchesTeam || e.type == NewsEventType.general;
    }).toList();

    if (_typeFilter == 'transfer') {
      events =
          events.where((e) => e.type == NewsEventType.transferWindow).toList();
    } else if (_typeFilter == 'injury') {
      events = events.where((e) => e.type == NewsEventType.injury).toList();
    } else if (_typeFilter == 'match') {
      events = events
          .where(
            (e) =>
                e.type == NewsEventType.chaoticMatch ||
                e.type == NewsEventType.tournamentResult,
          )
          .toList();
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
            vertical: 10,
          ),
          color: AppTheme.surfaceCard,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipItem(
                  label: 'Semua',
                  selected: _typeFilter == 'all',
                  onTap: () => setState(() => _typeFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Transfer Window',
                  selected: _typeFilter == 'transfer',
                  onTap: () => setState(() => _typeFilter = 'transfer'),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Cedera',
                  selected: _typeFilter == 'injury',
                  onTap: () => setState(() => _typeFilter = 'injury'),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Laga & Juara',
                  selected: _typeFilter == 'match',
                  onTap: () => setState(() => _typeFilter = 'match'),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderHairline),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Belum ada berita Transfer Window, Cedera, atau event khusus untuk turnamen ini.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _NewsEventCard(event: events[index]);
                  },
                ),
        ),
      ],
    );
  }
}

class _NewsEventCard extends StatelessWidget {
  final NewsEvent event;

  const _NewsEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color, Color bg, String label}) meta =
        switch (event.type) {
      NewsEventType.transferWindow => (
          icon: Icons.swap_horiz_rounded,
          color: (event.ovrDelta ?? 0) >= 0
              ? AppTheme.ovrUp
              : AppTheme.ovrDown,
          bg: (event.ovrDelta ?? 0) >= 0
              ? AppTheme.ovrEliteBg
              : const Color(0xFFFEF2F2),
          label: 'Transfer',
        ),
      NewsEventType.injury => (event.ovrDelta ?? 0) > 0
          ? (
              icon: Icons.healing_rounded,
              color: AppTheme.ovrUp,
              bg: AppTheme.ovrEliteBg,
              label: 'Pemulihan',
            )
          : (
              icon: Icons.medical_services_rounded,
              color: AppTheme.ovrDown,
              bg: const Color(0xFFFEF2F2),
              label: 'Cedera',
            ),
      NewsEventType.chaoticMatch => (
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.chaoticText,
          bg: AppTheme.chaoticBg,
          label: 'Chaotic',
        ),
      NewsEventType.tournamentResult => (
          icon: Icons.emoji_events_rounded,
          color: AppTheme.primaryBrand,
          bg: AppTheme.ovrEliteBg,
          label: 'Trofi',
        ),
      NewsEventType.general => (
          icon: Icons.campaign_rounded,
          color: AppTheme.secondaryAccent,
          bg: AppTheme.ovrMidBg,
          label: 'Info',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: meta.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.icon, color: meta.color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: meta.bg,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        meta.label,
                        style: AppTheme.badge.copyWith(
                          color: meta.color,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      event.gameweek == 0
                          ? 'Musim ${event.seasonNumber} • Pra-Musim'
                          : 'Musim ${event.seasonNumber} • Pekan ${event.gameweek}',
                      style: AppTheme.badge.copyWith(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(event.title, style: AppTheme.cardTitle),
                const SizedBox(height: 3),
                Text(event.description, style: AppTheme.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
