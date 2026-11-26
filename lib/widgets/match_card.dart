import 'package:flutter/material.dart';

import '../models/match_game.dart';
import '../models/team.dart';
import '../services/match_simulator.dart';
import '../theme/app_theme.dart';
import 'team_avatar.dart';

/// Kartu pertandingan bergaya FotMob Light Mode lengkap dengan badge kompetisi,
/// skor, indikator adu penalti, badge Chaotic Match, peluang pra-laga Davidson,
/// dan tombol Simulate.
class MatchCard extends StatelessWidget {
  final MatchGame match;
  final Team? homeTeam;
  final Team? awayTeam;
  final MatchProbabilities? probabilities;
  final VoidCallback? onSimulate;
  final VoidCallback? onTap;
  final VoidCallback? onHeadToHead;
  final bool showTournamentBadge;

  const MatchCard({
    super.key,
    required this.match,
    required this.homeTeam,
    required this.awayTeam,
    this.probabilities,
    this.onSimulate,
    this.onTap,
    this.onHeadToHead,
    this.showTournamentBadge = true,
  });

  String get _competitionLabel {
    final buffer = StringBuffer();
    if (showTournamentBadge && match.tournamentName.isNotEmpty) {
      buffer.write(match.tournamentName);
      buffer.write(' • ');
    }
    buffer.write(match.stageName);
    if (match.groupName != null && match.groupName!.isNotEmpty) {
      buffer.write(' • ${match.groupName}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final homeName = homeTeam?.name ?? 'Tim Home';
    final awayName = awayTeam?.name ?? 'Tim Away';

    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderHairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(),
              const SizedBox(height: 12),
              _buildTeamsAndScoreRow(homeName, awayName),
              if (!match.isFinished &&
                  (probabilities != null || onSimulate != null)) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.borderHairline),
                const SizedBox(height: 10),
                _buildPreMatchFooter(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    _competitionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.badge.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (match.isNeutralVenue) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.ovrMidBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Netral',
                    style: AppTheme.badge.copyWith(
                      color: AppTheme.secondaryAccent,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onHeadToHead != null) ...[
          const SizedBox(width: 8),
          Material(
            color: AppTheme.ovrMidBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: InkWell(
              onTap: onHeadToHead,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: AppTheme.secondaryAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.compare_arrows,
                      size: 12.5,
                      color: AppTheme.secondaryAccent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'H2H',
                      style: AppTheme.badge.copyWith(
                        color: AppTheme.secondaryAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (match.isChaoticMatch) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.chaoticBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: AppTheme.chaoticText,
                ),
                const SizedBox(width: 3),
                Text(
                  'CHAOTIC',
                  style: AppTheme.badge.copyWith(
                    color: AppTheme.chaoticText,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ] else if (match.isFinished) ...[
          const SizedBox(width: 8),
          Text(
            'FT',
            style: AppTheme.badge.copyWith(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTeamsAndScoreRow(String homeName, String awayName) {
    final homeWon =
        match.isFinished && match.winnerTeamId == match.homeTeamId;
    final awayWon =
        match.isFinished && match.winnerTeamId == match.awayTeamId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      homeName,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.cardTitle.copyWith(
                        fontWeight:
                            homeWon ? FontWeight.w700 : FontWeight.w600,
                        color: match.isFinished && !homeWon && awayWon
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (homeTeam != null)
                      Text(
                        'OVR ${homeTeam!.ovr}',
                        style: AppTheme.badge.copyWith(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TeamAvatar(
                name: homeName,
                logoPath: homeTeam?.logoPath,
                colorValue: homeTeam?.colorValue ?? 0xFF1D4ED8,
                size: 26,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 84,
          child: _buildScoreCenter(),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TeamAvatar(
                name: awayName,
                logoPath: awayTeam?.logoPath,
                colorValue: awayTeam?.colorValue ?? 0xFF00A859,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      awayName,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.cardTitle.copyWith(
                        fontWeight:
                            awayWon ? FontWeight.w700 : FontWeight.w600,
                        color: match.isFinished && !awayWon && homeWon
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (awayTeam != null)
                      Text(
                        'OVR ${awayTeam!.ovr}',
                        style: AppTheme.badge.copyWith(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCenter() {
    if (!match.isFinished) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            'VS',
            style: AppTheme.badge.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${match.homeScore ?? 0} - ${match.awayScore ?? 0}',
          textAlign: TextAlign.center,
          style: AppTheme.matchScore,
        ),
        if (match.hasPenaltyShootout) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.ovrMidBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              'Pen ${match.homePenaltyScore}-${match.awayPenaltyScore}',
              style: AppTheme.badge.copyWith(
                fontSize: 10,
                color: AppTheme.secondaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreMatchFooter() {
    final probs = probabilities;
    return Row(
      children: [
        if (probs != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'H ${probs.homeWinPercent}%',
                      style: AppTheme.badge.copyWith(
                        fontSize: 10,
                        color: AppTheme.primaryBrand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'S ${probs.drawPercent}%',
                      style: AppTheme.badge.copyWith(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'A ${probs.awayWinPercent}%',
                      style: AppTheme.badge.copyWith(
                        fontSize: 10,
                        color: AppTheme.secondaryAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 4,
                    child: Row(
                      children: [
                        Expanded(
                          flex: probs.homeWinPercent.clamp(1, 98),
                          child: Container(color: AppTheme.primaryBrand),
                        ),
                        Expanded(
                          flex: probs.drawPercent.clamp(1, 98),
                          child: Container(color: AppTheme.textMuted),
                        ),
                        Expanded(
                          flex: probs.awayWinPercent.clamp(1, 98),
                          child: Container(color: AppTheme.secondaryAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const Spacer(),
        if (onSimulate != null) ...[
          const SizedBox(width: 12),
          SizedBox(
            height: 30,
            child: ElevatedButton.icon(
              onPressed: onSimulate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 15),
              label: const Text('Simulate'),
            ),
          ),
        ],
      ],
    );
  }
}
