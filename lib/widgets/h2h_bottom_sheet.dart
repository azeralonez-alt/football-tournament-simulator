import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_game.dart';
import '../models/team.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import 'ovr_badge.dart';
import 'team_avatar.dart';

/// Menampilkan Modal Bottom Sheet perbandingan Head-to-Head (H2H) antara
/// [teamAId] (biasanya tim kandang) dan [teamBId] (tim tandang).
Future<void> showHeadToHeadBottomSheet(
  BuildContext context, {
  required String teamAId,
  required String teamBId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => HeadToHeadBottomSheet(
      teamAId: teamAId,
      teamBId: teamBId,
    ),
  );
}

/// Bottom sheet ringkasan statistik & riwayat pertemuan resmi antara dua klub.
class HeadToHeadBottomSheet extends StatelessWidget {
  final String teamAId;
  final String teamBId;

  const HeadToHeadBottomSheet({
    super.key,
    required this.teamAId,
    required this.teamBId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final teamA = provider.getTeamById(teamAId);
    final teamB = provider.getTeamById(teamBId);
    final stats = provider.getHeadToHeadStats(teamAId, teamBId);
    final teamAName = teamA?.name ?? 'Tim Home';
    final teamBName = teamB?.name ?? 'Tim Away';

    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            10,
            AppTheme.screenPadding,
            AppTheme.screenPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.compare_arrows_rounded,
                    size: 20,
                    color: AppTheme.secondaryAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Head-to-Head (H2H)',
                      style: AppTheme.appBarTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TeamsComparisonHeader(
                teamA: teamA,
                teamB: teamB,
                teamAName: teamAName,
                teamBName: teamBName,
              ),
              const SizedBox(height: 14),
              _H2HSummarySection(
                stats: stats,
                teamAName: teamAName,
                teamBName: teamBName,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Riwayat Pertemuan',
                      style: AppTheme.sectionHeader,
                    ),
                  ),
                  if (stats.totalMeetings > 0)
                    Text(
                      'Gol: ${stats.teamAGoals} - ${stats.teamBGoals}',
                      style: AppTheme.badge.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (stats.totalMeetings == 0)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history_toggle_off_rounded,
                        size: 30,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kedua tim belum pernah bertemu di kompetisi resmi.',
                        textAlign: TextAlign.center,
                        style: AppTheme.body,
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: stats.pastMatches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      return _PastMeetingCard(
                        match: stats.pastMatches[index],
                        teamAId: teamAId,
                        teamBId: teamBId,
                        teamAName: teamAName,
                        teamBName: teamBName,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamsComparisonHeader extends StatelessWidget {
  final Team? teamA;
  final Team? teamB;
  final String teamAName;
  final String teamBName;

  const _TeamsComparisonHeader({
    required this.teamA,
    required this.teamB,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                TeamAvatar(
                  name: teamAName,
                  logoPath: teamA?.logoPath,
                  colorValue: teamA?.colorValue ?? 0xFF00A859,
                  size: 46,
                ),
                const SizedBox(height: 6),
                Text(
                  teamAName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
                ),
                if (teamA != null) ...[
                  const SizedBox(height: 4),
                  OvrBadge(ovr: teamA!.ovr, showLabel: true, compact: true),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.borderHairline),
              ),
              child: Text(
                'VS',
                style: AppTheme.badge.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                TeamAvatar(
                  name: teamBName,
                  logoPath: teamB?.logoPath,
                  colorValue: teamB?.colorValue ?? 0xFF1D4ED8,
                  size: 46,
                ),
                const SizedBox(height: 6),
                Text(
                  teamBName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
                ),
                if (teamB != null) ...[
                  const SizedBox(height: 4),
                  OvrBadge(ovr: teamB!.ovr, showLabel: true, compact: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _H2HSummarySection extends StatelessWidget {
  final HeadToHeadStats stats;
  final String teamAName;
  final String teamBName;

  const _H2HSummarySection({
    required this.stats,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.ovrMidBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color: AppTheme.secondaryAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'Total Pertemuan: ${stats.totalMeetings} Laga',
              style: AppTheme.badge.copyWith(
                color: AppTheme.secondaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                title: 'Menang $teamAName',
                count: stats.teamAWins,
                subLabel: '${stats.teamAGoals} Gol',
                accent: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatBox(
                title: 'Seri',
                count: stats.draws,
                subLabel: 'Imbang',
                accent: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatBox(
                title: 'Menang $teamBName',
                count: stats.teamBWins,
                subLabel: '${stats.teamBGoals} Gol',
                accent: AppTheme.secondaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: stats.totalMeetings == 0
                ? Container(color: AppTheme.surfaceSubtle)
                : Row(
                    children: [
                      if (stats.teamAWins > 0)
                        Expanded(
                          flex: stats.teamAWins,
                          child: Container(color: Colors.green),
                        ),
                      if (stats.draws > 0)
                        Expanded(
                          flex: stats.draws,
                          child: Container(color: Colors.grey.shade400),
                        ),
                      if (stats.teamBWins > 0)
                        Expanded(
                          flex: stats.teamBWins,
                          child: Container(color: AppTheme.secondaryAccent),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final int count;
  final String subLabel;
  final Color accent;

  const _StatBox({
    required this.title,
    required this.count,
    required this.subLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = accent == Colors.grey
        ? Colors.grey.shade700
        : accent == Colors.green
            ? Colors.green.shade700
            : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: AppTheme.matchScore.copyWith(
              fontSize: 20,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.badge.copyWith(
              fontSize: 10.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: AppTheme.badge.copyWith(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PastMeetingCard extends StatelessWidget {
  final MatchGame match;
  final String teamAId;
  final String teamBId;
  final String teamAName;
  final String teamBName;

  const _PastMeetingCard({
    required this.match,
    required this.teamAId,
    required this.teamBId,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context) {
    final homeName = match.homeTeamId == teamAId ? teamAName : teamBName;
    final awayName = match.awayTeamId == teamAId ? teamAName : teamBName;
    final winnerId = match.winnerTeamId;
    final homeWon = winnerId == match.homeTeamId;
    final awayWon = winnerId == match.awayTeamId;

    final competition = match.tournamentName.isNotEmpty
        ? match.tournamentName
        : 'Kompetisi';
    final headerParts = [
      'Musim ${match.seasonNumber}',
      competition,
      match.stageName,
      if (match.groupName != null && match.groupName!.isNotEmpty)
        match.groupName!,
      if (match.hasPenaltyShootout)
        'Pen ${match.homePenaltyScore}-${match.awayPenaltyScore}',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headerParts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.badge.copyWith(
              fontSize: 10.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeName,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyPrimary.copyWith(
                    fontWeight: homeWon ? FontWeight.w700 : FontWeight.w500,
                    color: awayWon
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '${match.homeScore ?? 0} - ${match.awayScore ?? 0}',
                  style: AppTheme.tabularNumberBold.copyWith(fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  awayName,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyPrimary.copyWith(
                    fontWeight: awayWon ? FontWeight.w700 : FontWeight.w500,
                    color: homeWon
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
