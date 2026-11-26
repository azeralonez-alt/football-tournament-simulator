import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/team.dart';
import '../models/tournament.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/team_avatar.dart';
import 'tournament_detail_screen.dart';

/// Tab 1: Halaman daftar seluruh turnamen (5 Kontinental, 8 Liga Lokal A–H, 8 Cup Domestik A–H).
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
            Column(
              children: [
                for (var i = 0; i < continental.length; i++) ...[
                  _ContinentalTournamentCard(
                    tournament: continental[i],
                    teamsById: teamsById,
                    onTap: () => _openDetail(context, continental[i]),
                  ),
                  if (i < continental.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'Liga Lokal (Liga A–H)',
            badge: '${localLeagues.length} Liga • 20 Tim',
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: localLeagues.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.95,
            ),
            itemBuilder: (context, index) {
              final league = localLeagues[index];
              return _GridTournamentCard(
                tournament: league,
                teamsById: teamsById,
                isCup: false,
                onTap: () => _openDetail(context, league),
              );
            },
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'Cup Domestik (Cup A–H)',
            badge: '${domesticCups.length} Piala • 16 Tim',
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: domesticCups.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.95,
            ),
            itemBuilder: (context, index) {
              final cup = domesticCups[index];
              return _GridTournamentCard(
                tournament: cup,
                teamsById: teamsById,
                isCup: true,
                onTap: () => _openDetail(context, cup),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
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

class _ContinentalTournamentCard extends StatelessWidget {
  final Tournament tournament;
  final Map<String, Team> teamsById;
  final VoidCallback onTap;

  const _ContinentalTournamentCard({
    required this.tournament,
    required this.teamsById,
    required this.onTap,
  });

  Color _tierColor(int? tier) {
    switch (tier) {
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

  String _qualificationSummary(int? tier) {
    switch (tier) {
      case 1:
        return 'Rank 1–4 Liga A–H • 32 Tim • League Phase';
      case 2:
        return 'Rank 5–8 Liga A–H • 32 Tim • League Phase';
      case 3:
        return 'Rank 9–12 Liga A–H • 32 Tim • League Phase';
      case 4:
        return 'Rank 13–17 Liga A–H • 40 Tim • 8 Grup';
      case 5:
        return 'Rank 18–20 Liga A–H • 24 Tim • 8 Grup';
      default:
        return '${tournament.teamIds.length} Tim';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _tierColor(tournament.tier);
    final champion = tournament.championTeamId != null
        ? teamsById[tournament.championTeamId!]
        : null;

    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderHairline, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.public_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tournament.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.cardTitle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                champion != null
                                    ? 'Juara: ${champion.name}'
                                    : _qualificationSummary(tournament.tier),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body.copyWith(
                                  fontSize: 12,
                                  color: champion != null
                                      ? AppTheme.ovrEliteText
                                      : AppTheme.textSecondary,
                                  fontWeight: champion != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tournament.isActive
                                ? AppTheme.ovrEliteBg
                                : AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                          ),
                          child: Text(
                            tournament.currentStage,
                            style: AppTheme.badge.copyWith(
                              color: tournament.isActive
                                  ? AppTheme.ovrEliteText
                                  : AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridTournamentCard extends StatelessWidget {
  final Tournament tournament;
  final Map<String, Team> teamsById;
  final bool isCup;
  final VoidCallback onTap;

  const _GridTournamentCard({
    required this.tournament,
    required this.teamsById,
    required this.isCup,
    required this.onTap,
  });

  String get _leagueLetter {
    final idx = tournament.leagueIndex;
    if (idx == null || idx < 0 || idx >= 8) return '?';
    return String.fromCharCode(65 + idx);
  }

  @override
  Widget build(BuildContext context) {
    final champion = tournament.championTeamId != null
        ? teamsById[tournament.championTeamId!]
        : null;
    final accent = isCup ? AppTheme.zoneChallenger : AppTheme.primaryBrand;

    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderHairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: isCup
                        ? Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: accent,
                          )
                        : Text(
                            _leagueLetter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tournament.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              if (champion != null)
                Row(
                  children: [
                    TeamAvatar(
                      name: champion.name,
                      logoPath: champion.logoPath,
                      colorValue: champion.colorValue,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        champion.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.badge.copyWith(
                          color: AppTheme.ovrEliteText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tournament.currentStage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.badge.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
            ],
          ),
        ),
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
