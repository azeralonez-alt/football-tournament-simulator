import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/active_injury.dart';
import '../models/match_game.dart';
import '../models/news_event.dart';
import '../models/standing_row.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_team_dialog.dart';
import '../widgets/ovr_badge.dart';
import '../widgets/team_avatar.dart';
import 'tournament_detail_screen.dart';

/// Halaman Detail Klub: Profil & OVR, Posisi Klasemen Lokal & Kontinental,
/// Kabinet Trofi, Riwayat Performa Tiap Musim, dan Log Berita Klub.
class TeamDetailScreen extends StatelessWidget {
  final String teamId;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
  });

  String _localQualificationZone(int rank) {
    if (rank >= 1 && rank <= 4) return 'Champions League';
    if (rank >= 5 && rank <= 8) return 'Winner League';
    if (rank >= 9 && rank <= 12) return 'Federation League';
    if (rank >= 13 && rank <= 17) return 'Mid Range League';
    if (rank >= 18 && rank <= 20) return 'Challenger League';
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final team = provider.getTeamById(teamId);

    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Tim')),
        body: const Center(child: Text('Tim tidak ditemukan.')),
      );
    }

    // Cari Liga Lokal aktif milik tim ini
    Tournament? localLeague;
    StandingRow? localStanding;
    for (final t in provider.tournaments) {
      if (t.type == TournamentType.localLeague && t.teamIds.contains(team.id)) {
        localLeague = t;
        final rows = provider.getStandings(t.id);
        for (final r in rows) {
          if (r.teamId == team.id) {
            localStanding = r;
            break;
          }
        }
        break;
      }
    }

    // Cari Turnamen Kontinental aktif milik tim ini
    Tournament? continentalTournament;
    StandingRow? continentalStanding;
    for (final t in provider.tournaments) {
      if (t.isContinental && t.isActive) {
        final inTeamIds = t.teamIds.contains(team.id);
        final inMatches = provider
            .getMatchesForTournament(t.id)
            .any((m) => m.homeTeamId == team.id || m.awayTeamId == team.id);
        if (inTeamIds || inMatches) {
          continentalTournament = t;
          final rows = provider.getStandings(t.id);
          for (final r in rows) {
            if (r.teamId == team.id) {
              continentalStanding = r;
              break;
            }
          }
        }
      }
    }

    // Cari Cup Domestik aktif
    Tournament? domesticCup;
    for (final t in provider.tournaments) {
      if (t.type == TournamentType.domesticCup && t.teamIds.contains(team.id)) {
        domesticCup = t;
        break;
      }
    }

    final teamsById = {for (final t in provider.teams) t.id: t};
    final recentMatches = provider.getTeamRecentMatches(team.id, limit: 5);
    final activeInjuries = provider.getActiveInjuriesForTeam(team.id);
    final clubNews = provider.newsEvents
        .where((e) => e.teamId == team.id)
        .take(15)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          IconButton(
            tooltip: 'Edit Tim',
            icon: const Icon(Icons.edit),
            onPressed: () => showEditTeamDialog(context, team),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeaderCard(
              team: team,
              leagueLabel: provider.getLeagueName(team.leagueId),
            ),
            const SizedBox(height: 14),
            _RecentMatchesCard(
              teamId: team.id,
              recentMatches: recentMatches,
              teamsById: teamsById,
            ),
            if (activeInjuries.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ActiveInjuriesCard(injuries: activeInjuries),
            ],
            const SizedBox(height: 14),
            _CurrentSeasonStatusCard(
              team: team,
              currentSeason: provider.currentSeason,
              localLeague: localLeague,
              localStanding: localStanding,
              zoneName: localStanding != null
                  ? _localQualificationZone(localStanding.position)
                  : '-',
              continentalTournament: continentalTournament,
              continentalStanding: continentalStanding,
              domesticCup: domesticCup,
              onOpenTournament: (tournamentId) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TournamentDetailScreen(tournamentId: tournamentId),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _TrophyCabinetCard(team: team),
            const SizedBox(height: 14),
            _TeamMatchHistoryCard(
              teamId: team.id,
              currentSeason: provider.currentSeason,
              teamsById: teamsById,
            ),
            const SizedBox(height: 14),
            _SeasonHistoryCard(history: team.seasonHistory),
            if (clubNews.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ClubNewsCard(events: clubNews),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final Team team;
  final String leagueLabel;

  const _ProfileHeaderCard({
    required this.team,
    required this.leagueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final seasonDelta = team.seasonOvrDelta;
    final seasonDeltaText = seasonDelta > 0
        ? '+$seasonDelta'
        : seasonDelta == 0
            ? '0'
            : '$seasonDelta';
    final seasonDeltaColor = seasonDelta > 0
        ? AppTheme.ovrUp
        : (seasonDelta < 0 ? AppTheme.ovrDown : AppTheme.textSecondary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              TeamAvatar(
                name: team.name,
                logoPath: team.logoPath,
                colorValue: team.colorValue,
                size: 64,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: AppTheme.appBarTitle.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text(
                            leagueLabel,
                            style: AppTheme.badge.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OvrBadge(
                          ovr: team.ovr,
                          ovrChange: team.lastOvrChange,
                          showLabel: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.borderHairline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricColumn(
                  label: 'OVR Awal Musim',
                  value: '${team.seasonOvrStart}',
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  label: 'OVR Saat Ini',
                  value: '${team.ovr}',
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  label: 'Tren Musim Ini',
                  value: seasonDeltaText,
                  valueColor: seasonDeltaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.badge.copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.tabularNumberBold.copyWith(
            fontSize: 16,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CurrentSeasonStatusCard extends StatelessWidget {
  final Team team;
  final int currentSeason;
  final Tournament? localLeague;
  final StandingRow? localStanding;
  final String zoneName;
  final Tournament? continentalTournament;
  final StandingRow? continentalStanding;
  final Tournament? domesticCup;
  final ValueChanged<String> onOpenTournament;

  const _CurrentSeasonStatusCard({
    required this.team,
    required this.currentSeason,
    required this.localLeague,
    required this.localStanding,
    required this.zoneName,
    required this.continentalTournament,
    required this.continentalStanding,
    required this.domesticCup,
    required this.onOpenTournament,
  });

  @override
  Widget build(BuildContext context) {
    final zoneColor = localStanding != null
        ? AppTheme.localLeagueZoneColor(localStanding!.position)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posisi Musim $currentSeason', style: AppTheme.sectionHeader),
          const SizedBox(height: 12),
          if (localLeague != null && localStanding != null)
            _StatusRowItem(
              icon: Icons.leaderboard_rounded,
              iconColor: zoneColor ?? AppTheme.primaryBrand,
              title: localLeague!.name,
              subtitle:
                  'Main ${localStanding!.played} • ${localStanding!.points} Poin • SG ${localStanding!.goalDifference >= 0 ? '+${localStanding!.goalDifference}' : localStanding!.goalDifference} • Zona $zoneName',
              trailingText: '#${localStanding!.position}',
              trailingColor: zoneColor ?? AppTheme.primaryBrand,
              onTap: () => onOpenTournament(localLeague!.id),
            ),
          const Divider(height: 18, color: AppTheme.borderHairline),
          if (continentalTournament != null)
            _StatusRowItem(
              icon: Icons.public_rounded,
              iconColor: AppTheme.secondaryAccent,
              title: continentalTournament!.name,
              subtitle: continentalStanding != null
                  ? '${continentalStanding!.groupName != null ? '${continentalStanding!.groupName} • ' : ''}Main ${continentalStanding!.played} • ${continentalStanding!.points} Poin • ${continentalTournament!.currentStage}'
                  : 'Tahap: ${continentalTournament!.currentStage}',
              trailingText: continentalStanding != null
                  ? '#${continentalStanding!.position}'
                  : continentalTournament!.championTeamId == team.id
                      ? 'Juara'
                      : '-',
              trailingColor: AppTheme.secondaryAccent,
              onTap: () => onOpenTournament(continentalTournament!.id),
            )
          else
            _StatusRowItem(
              icon: Icons.public_off_rounded,
              iconColor: AppTheme.textMuted,
              title: 'Turnamen Kontinental',
              subtitle: currentSeason == 1
                  ? 'Belum bergulir pada Musim 1 (mulai Musim 2).'
                  : 'Tidak terdaftar pada turnamen kontinental aktif.',
              trailingText: '-',
              trailingColor: AppTheme.textMuted,
            ),
          const Divider(height: 18, color: AppTheme.borderHairline),
          if (domesticCup != null)
            _StatusRowItem(
              icon: Icons.emoji_events_outlined,
              iconColor: AppTheme.zoneChallenger,
              title: domesticCup!.name,
              subtitle: domesticCup!.championTeamId == team.id
                  ? 'Juara ${domesticCup!.name}!'
                  : 'Babak Turnamen: ${domesticCup!.currentStage}',
              trailingText: domesticCup!.championTeamId == team.id
                  ? 'Juara'
                  : 'Peserta',
              trailingColor: AppTheme.zoneChallenger,
              onTap: () => onOpenTournament(domesticCup!.id),
            )
          else
            const _StatusRowItem(
              icon: Icons.emoji_events_outlined,
              iconColor: AppTheme.textMuted,
              title: 'Cup Domestik',
              subtitle: 'Tidak masuk 16 besar peserta Cup musim ini.',
              trailingText: '-',
              trailingColor: AppTheme.textMuted,
            ),
        ],
      ),
    );
  }
}

class _StatusRowItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailingText;
  final Color trailingColor;
  final VoidCallback? onTap;

  const _StatusRowItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingText,
    required this.trailingColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.cardTitle.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: trailingColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              trailingText,
              style: AppTheme.tabularNumberBold.copyWith(
                color: trailingColor,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrophyCabinetCard extends StatelessWidget {
  final Team team;

  const _TrophyCabinetCard({required this.team});

  static const List<({String key, String label, Color color})> _trophyMeta = [
    (key: 'champions_league', label: 'Champions', color: AppTheme.zoneChampions),
    (key: 'winner_league', label: 'Winner', color: AppTheme.zoneWinner),
    (
      key: 'federation_league',
      label: 'Federation',
      color: AppTheme.zoneFederation,
    ),
    (key: 'mid_range_league', label: 'Mid Range', color: AppTheme.zoneMidRange),
    (
      key: 'challenger_league',
      label: 'Challenger',
      color: AppTheme.zoneChallenger,
    ),
    (key: 'local_league', label: 'Liga Lokal', color: AppTheme.primaryBrand),
    (key: 'domestic_cup', label: 'Cup Domestik', color: AppTheme.chaoticText),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text('Kabinet Trofi', style: AppTheme.sectionHeader),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.chaoticBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '${team.totalTrophies} Total Gelar',
                  style: AppTheme.badge.copyWith(color: AppTheme.chaoticText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _trophyMeta)
                _TrophyPill(
                  label: item.label,
                  count: team.trophies[item.key] ?? 0,
                  accent: item.color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrophyPill extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;

  const _TrophyPill({
    required this.label,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final hasWon = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasWon ? accent.withValues(alpha: 0.1) : AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasWon ? accent.withValues(alpha: 0.3) : AppTheme.borderHairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 16,
            color: hasWon ? accent : AppTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              fontSize: 12,
              color: hasWon ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTheme.tabularNumberBold.copyWith(
              fontSize: 13,
              color: hasWon ? accent : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonHistoryCard extends StatelessWidget {
  final List<TeamSeasonHistory> history;

  const _SeasonHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final reversed = history.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Riwayat Performa Tiap Musim', style: AppTheme.sectionHeader),
          const SizedBox(height: 10),
          if (reversed.isEmpty)
            Text(
              'Belum ada riwayat musim yang selesai. Riwayat akan tercatat otomatis setelah Musim 1 berakhir.',
              style: AppTheme.body,
            )
          else
            Column(
              children: [
                for (var i = 0; i < reversed.length; i++) ...[
                  _HistorySeasonRow(item: reversed[i]),
                  if (i < reversed.length - 1)
                    const Divider(height: 16, color: AppTheme.borderHairline),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HistorySeasonRow extends StatelessWidget {
  final TeamSeasonHistory item;

  const _HistorySeasonRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'M${item.seasonNumber}',
            style: AppTheme.tabularNumberBold.copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.leagueName} • Peringkat #${item.leagueRank}',
                style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              if (item.continentalTournamentName != null)
                Text(
                  '${item.continentalTournamentName}: ${item.continentalAchievement ?? '-'}',
                  style: AppTheme.body.copyWith(
                    fontSize: 12,
                    color: AppTheme.secondaryAccent,
                  ),
                ),
              Text(
                'Gol/Laga: ${item.avgGoalsFor.toStringAsFixed(2)} • Kebobolan/Laga: ${item.avgGoalsAgainst.toStringAsFixed(2)} • OVR ${item.ovrStart} → ${item.ovrEnd}',
                style: AppTheme.body.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

({String shortLabel, String fullLabel, Color color}) _resolveMatchOutcome(
  MatchGame match,
  String teamId,
) {
  final winnerId = match.winnerTeamId;
  if (winnerId == teamId) {
    return (shortLabel: 'M', fullLabel: 'Menang', color: Colors.green);
  }
  if (winnerId == null) {
    return (shortLabel: 'S', fullLabel: 'Seri', color: Colors.grey);
  }
  return (shortLabel: 'K', fullLabel: 'Kalah', color: Colors.orange);
}

class _RecentMatchesCard extends StatelessWidget {
  final String teamId;
  final List<MatchGame> recentMatches;
  final Map<String, Team> teamsById;

  const _RecentMatchesCard({
    required this.teamId,
    required this.recentMatches,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text('5 Match Terakhir', style: AppTheme.sectionHeader),
              ),
              if (recentMatches.isNotEmpty)
                Text(
                  'Terlama → Terbaru',
                  style: AppTheme.badge.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentMatches.isEmpty)
            Text(
              'Belum ada pertandingan dimainkan',
              style: AppTheme.body,
            )
          else
            Row(
              children: [
                for (var i = 0; i < recentMatches.length; i++) ...[
                  Expanded(
                    child: _RecentMatchBadgeItem(
                      teamId: teamId,
                      match: recentMatches[i],
                      teamsById: teamsById,
                    ),
                  ),
                  if (i < recentMatches.length - 1) const SizedBox(width: 8),
                ],
                for (var i = recentMatches.length; i < 5; i++) ...[
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentMatchBadgeItem extends StatelessWidget {
  final String teamId;
  final MatchGame match;
  final Map<String, Team> teamsById;

  const _RecentMatchBadgeItem({
    required this.teamId,
    required this.match,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    final outcome = _resolveMatchOutcome(match, teamId);
    final isHome = match.homeTeamId == teamId;
    final myScore = isHome ? (match.homeScore ?? 0) : (match.awayScore ?? 0);
    final oppScore = isHome ? (match.awayScore ?? 0) : (match.homeScore ?? 0);
    final opponentId = isHome ? match.awayTeamId : match.homeTeamId;
    final opponent = teamsById[opponentId];
    final oppInitials = opponent?.initials ?? 'LAW';

    return Tooltip(
      message:
          '${match.tournamentName} (${match.stageName})\n${teamsById[match.homeTeamId]?.name ?? 'Home'} ${match.homeScore ?? 0}-${match.awayScore ?? 0} ${teamsById[match.awayTeamId]?.name ?? 'Away'}',
      child: InkWell(
        onTap: opponent == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamDetailScreen(teamId: opponent.id),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: outcome.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  outcome.shortLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$myScore-$oppScore',
                style: AppTheme.tabularNumberBold.copyWith(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'vs $oppInitials',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.badge.copyWith(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMatchHistoryCard extends StatefulWidget {
  final String teamId;
  final int currentSeason;
  final Map<String, Team> teamsById;

  const _TeamMatchHistoryCard({
    required this.teamId,
    required this.currentSeason,
    required this.teamsById,
  });

  @override
  State<_TeamMatchHistoryCard> createState() => _TeamMatchHistoryCardState();
}

class _TeamMatchHistoryCardState extends State<_TeamMatchHistoryCard> {
  late int _selectedSeason;
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.currentSeason.clamp(1, 999);
  }

  @override
  void didUpdateWidget(covariant _TeamMatchHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedSeason > widget.currentSeason) {
      _selectedSeason = widget.currentSeason.clamp(1, 999);
    } else if (oldWidget.currentSeason != widget.currentSeason &&
        _selectedSeason == oldWidget.currentSeason) {
      _selectedSeason = widget.currentSeason;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final seasons = List<int>.generate(
      widget.currentSeason < 1 ? 1 : widget.currentSeason,
      (i) => i + 1,
    );
    final rawMatches = provider.getTeamMatchesBySeason(
      widget.teamId,
      _selectedSeason,
    );
    final matches = _newestFirst ? rawMatches.reversed.toList() : rawMatches;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Riwayat Pertandingan',
                  style: AppTheme.sectionHeader,
                ),
              ),
              Text(
                '${matches.length} Laga',
                style: AppTheme.badge.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: seasons.contains(_selectedSeason)
                          ? _selectedSeason
                          : seasons.last,
                      isExpanded: true,
                      isDense: true,
                      style: AppTheme.bodyPrimary,
                      items: [
                        for (final s in seasons.reversed)
                          DropdownMenuItem<int>(
                            value: s,
                            child: Text(
                              s == widget.currentSeason
                                  ? 'Musim $s (Aktif)'
                                  : 'Musim $s',
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSeason = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.swap_vert_rounded, size: 17),
                label: Text(_newestFirst ? 'Terbaru' : 'Terlama'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada pertandingan dimainkan pada Musim $_selectedSeason.',
                style: AppTheme.body,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < matches.length; i++) ...[
                  _MatchHistoryRowItem(
                    teamId: widget.teamId,
                    match: matches[i],
                    teamsById: widget.teamsById,
                  ),
                  if (i < matches.length - 1)
                    const Divider(height: 14, color: AppTheme.borderHairline),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _MatchHistoryRowItem extends StatelessWidget {
  final String teamId;
  final MatchGame match;
  final Map<String, Team> teamsById;

  const _MatchHistoryRowItem({
    required this.teamId,
    required this.match,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    final outcome = _resolveMatchOutcome(match, teamId);
    final homeName = teamsById[match.homeTeamId]?.name ?? 'Tim Home';
    final awayName = teamsById[match.awayTeamId]?.name ?? 'Tim Away';
    final isHome = match.homeTeamId == teamId;
    final isAway = match.awayTeamId == teamId;

    final competitionTitle = match.tournamentName.isNotEmpty
        ? match.tournamentName
        : 'Kompetisi';
    final stageSuffix = [
      match.stageName,
      if (match.groupName != null && match.groupName!.isNotEmpty)
        match.groupName!,
      if (match.hasPenaltyShootout)
        'Pen ${match.homePenaltyScore}-${match.awayPenaltyScore}',
    ].join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$competitionTitle • $stageSuffix',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.badge.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: AppTheme.bodyPrimary.copyWith(fontSize: 13),
                  children: [
                    TextSpan(
                      text: homeName,
                      style: TextStyle(
                        fontWeight:
                            isHome ? FontWeight.w700 : FontWeight.w500,
                        color: isHome
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: '  ${match.homeScore ?? 0} - ${match.awayScore ?? 0}  ',
                      style: AppTheme.tabularNumberBold.copyWith(
                        fontSize: 13.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: awayName,
                      style: TextStyle(
                        fontWeight:
                            isAway ? FontWeight.w700 : FontWeight.w500,
                        color: isAway
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: outcome.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: outcome.color.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            outcome.fullLabel,
            style: AppTheme.badge.copyWith(
              color: outcome.color == Colors.grey
                  ? Colors.grey.shade700
                  : outcome.color == Colors.orange
                      ? Colors.orange.shade800
                      : Colors.green.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveInjuriesCard extends StatelessWidget {
  final List<ActiveInjury> injuries;

  const _ActiveInjuriesCard({required this.injuries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.ovrDown.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  size: 16,
                  color: AppTheme.ovrDown,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status Medis & Cedera Aktif',
                  style: AppTheme.sectionHeader,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  '${injuries.length} Pemain',
                  style: AppTheme.badge.copyWith(
                    color: AppTheme.ovrDown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < injuries.length; i++) ...[
            _ActiveInjuryItem(injury: injuries[i]),
            if (i < injuries.length - 1)
              const Divider(height: 16, color: AppTheme.borderHairline),
          ],
        ],
      ),
    );
  }
}

class _ActiveInjuryItem extends StatelessWidget {
  final ActiveInjury injury;

  const _ActiveInjuryItem({required this.injury});

  @override
  Widget build(BuildContext context) {
    final remaining = injury.remainingEstimatedWeeks;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      injury.playerRole,
                      style: AppTheme.badge.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Musim ${injury.startSeason} • Pekan ${injury.startWeek}',
                    style: AppTheme.badge.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                injury.injuryName,
                style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                'Estimasi kembali: $remaining pekan lagi',
                style: AppTheme.body.copyWith(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: AppTheme.ovrDown.withValues(alpha: 0.25)),
          ),
          child: Text(
            '-${injury.ovrPenalty} OVR',
            style: AppTheme.tabularNumberBold.copyWith(
              color: AppTheme.ovrDown,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClubNewsCard extends StatelessWidget {
  final List<NewsEvent> events;

  const _ClubNewsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Catatan Klub Musim Ini', style: AppTheme.sectionHeader),
          const SizedBox(height: 10),
          for (var i = 0; i < events.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  events[i].type == NewsEventType.injury
                      ? ((events[i].ovrDelta ?? 0) > 0
                          ? Icons.healing_rounded
                          : Icons.medical_services_rounded)
                      : events[i].type == NewsEventType.tournamentResult
                          ? Icons.emoji_events_rounded
                          : Icons.swap_horiz_rounded,
                  size: 16,
                  color: events[i].type == NewsEventType.injury
                      ? ((events[i].ovrDelta ?? 0) > 0
                          ? AppTheme.ovrUp
                          : AppTheme.ovrDown)
                      : AppTheme.primaryBrand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events[i].title,
                        style: AppTheme.bodyPrimary.copyWith(fontSize: 12.5),
                      ),
                      Text(
                        events[i].description,
                        style: AppTheme.body.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i < events.length - 1)
              const Divider(height: 14, color: AppTheme.borderHairline),
          ],
        ],
      ),
    );
  }
}
