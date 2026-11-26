import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_game.dart';
import '../models/season_archive.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/backup_settings_sheet.dart';
import '../widgets/ovr_badge.dart';
import '../widgets/team_avatar.dart';
import 'team_detail_screen.dart';

/// Tab 4: Halaman Arsip Sejarah Musim, Hall of Fame Sepanjang Masa,
/// serta Pengaturan Export/Import Save Data (JSON).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedSegment = 0; // 0 = Arsip Musim, 1 = Hall of Fame, 2 = Pengaturan
  int? _selectedSeasonNumber;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            12,
            AppTheme.screenPadding,
            12,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderHairline, width: 1),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TopSegmentTab(
                    label: 'Arsip Musim',
                    selected: _selectedSegment == 0,
                    onTap: () => setState(() => _selectedSegment = 0),
                  ),
                ),
                Expanded(
                  child: _TopSegmentTab(
                    label: 'Hall of Fame',
                    selected: _selectedSegment == 1,
                    onTap: () => setState(() => _selectedSegment = 1),
                  ),
                ),
                Expanded(
                  child: _TopSegmentTab(
                    label: 'Pengaturan',
                    selected: _selectedSegment == 2,
                    onTap: () => setState(() => _selectedSegment = 2),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (_selectedSegment) {
            0 => _SeasonArchiveView(
                archives: provider.archives,
                currentSeason: provider.currentSeason,
                teamsById: {for (final t in provider.teams) t.id: t},
                selectedSeasonNumber: _selectedSeasonNumber,
                onSelectSeason: (season) =>
                    setState(() => _selectedSeasonNumber = season),
              ),
            1 => _HallOfFameView(teams: provider.teams),
            _ => SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppTheme.borderHairline),
                  ),
                  child: const BackupSettingsPanel(insideBottomSheet: false),
                ),
              ),
          },
        ),
      ],
    );
  }
}

class _TopSegmentTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopSegmentTab({
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
            fontSize: 12,
            color: selected ? AppTheme.primaryBrand : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SeasonArchiveView extends StatelessWidget {
  final List<SeasonArchive> archives;
  final int currentSeason;
  final Map<String, Team> teamsById;
  final int? selectedSeasonNumber;
  final ValueChanged<int> onSelectSeason;

  const _SeasonArchiveView({
    required this.archives,
    required this.currentSeason,
    required this.teamsById,
    required this.selectedSeasonNumber,
    required this.onSelectSeason,
  });

  @override
  Widget build(BuildContext context) {
    if (archives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding * 1.5),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.borderHairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history_edu_outlined,
                  size: 42,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum Ada Arsip Musim',
                  style: AppTheme.sectionHeader,
                ),
                const SizedBox(height: 6),
                Text(
                  'Selesaikan seluruh jadwal Musim $currentSeason hingga Pekan 48 untuk mencatat daftar juara, tim tersubur, pertahanan terbaik, dan skor terbesar.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sortedArchives = List<SeasonArchive>.from(archives)
      ..sort((a, b) => b.seasonNumber.compareTo(a.seasonNumber));

    final activeArchive = sortedArchives.firstWhere(
      (a) => a.seasonNumber == selectedSeasonNumber,
      orElse: () => sortedArchives.first,
    );

    final champions = activeArchive.championsList;
    final continentalChamps = champions
        .where(
          (c) =>
              c.tournamentType == TournamentType.continentalLeague ||
              c.tournamentType == TournamentType.continentalGroup,
        )
        .toList();
    final leagueChamps = champions
        .where((c) => c.tournamentType == TournamentType.localLeague)
        .toList()
      ..sort((a, b) => a.tournamentName.compareTo(b.tournamentName));
    final cupChamps = champions
        .where((c) => c.tournamentType == TournamentType.domesticCup)
        .toList()
      ..sort((a, b) => a.tournamentName.compareTo(b.tournamentName));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final arch in sortedArchives) ...[
                  ChoiceChip(
                    label: Text('Musim ${arch.seasonNumber}'),
                    selected: arch.seasonNumber == activeArchive.seasonNumber,
                    onSelected: (_) => onSelectSeason(arch.seasonNumber),
                    selectedColor: AppTheme.primaryBrand,
                    backgroundColor: AppTheme.surfaceCard,
                    showCheckmark: false,
                    labelStyle: AppTheme.caption.copyWith(
                      color: arch.seasonNumber == activeArchive.seasonNumber
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Rekor Musim ${activeArchive.seasonNumber}',
            style: AppTheme.sectionHeader,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RecordMiniCard(
                  title: 'Tim Tersubur',
                  icon: Icons.sports_soccer_rounded,
                  accent: AppTheme.primaryBrand,
                  primaryText:
                      activeArchive.topScoringTeam?.teamName ?? '-',
                  secondaryText: activeArchive.topScoringTeam != null
                      ? '${activeArchive.topScoringTeam!.label} (${activeArchive.topScoringTeam!.tournamentName ?? ''})'
                      : '-',
                  team: activeArchive.topScoringTeam != null
                      ? teamsById[activeArchive.topScoringTeam!.teamId]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecordMiniCard(
                  title: 'Pertahanan Terbaik',
                  icon: Icons.shield_rounded,
                  accent: AppTheme.secondaryAccent,
                  primaryText:
                      activeArchive.bestDefenseTeam?.teamName ?? '-',
                  secondaryText: activeArchive.bestDefenseTeam != null
                      ? '${activeArchive.bestDefenseTeam!.label} (${activeArchive.bestDefenseTeam!.tournamentName ?? ''})'
                      : '-',
                  team: activeArchive.bestDefenseTeam != null
                      ? teamsById[activeArchive.bestDefenseTeam!.teamId]
                      : null,
                ),
              ),
            ],
          ),
          if (activeArchive.biggestScoreMatch != null) ...[
            const SizedBox(height: 10),
            _BiggestScoreArchiveCard(
              match: activeArchive.biggestScoreMatch!,
              teamsById: teamsById,
            ),
          ],
          if (continentalChamps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Juara Turnamen Kontinental', style: AppTheme.sectionHeader),
            const SizedBox(height: 10),
            _ChampionsListBox(entries: continentalChamps, teamsById: teamsById),
          ],
          if (leagueChamps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Juara Liga Lokal (A–H)', style: AppTheme.sectionHeader),
            const SizedBox(height: 10),
            _ChampionsListBox(entries: leagueChamps, teamsById: teamsById),
          ],
          if (cupChamps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Juara Cup Domestik (A–H)', style: AppTheme.sectionHeader),
            const SizedBox(height: 10),
            _ChampionsListBox(entries: cupChamps, teamsById: teamsById),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RecordMiniCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String primaryText;
  final String secondaryText;
  final Team? team;

  const _RecordMiniCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.team,
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
                  style: AppTheme.badge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (team != null) ...[
                TeamAvatar(
                  name: team!.name,
                  logoPath: team!.logoPath,
                  colorValue: team!.colorValue,
                  size: 22,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  primaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.cardTitle.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            secondaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.badge.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _BiggestScoreArchiveCard extends StatelessWidget {
  final MatchGame match;
  final Map<String, Team> teamsById;

  const _BiggestScoreArchiveCard({
    required this.match,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    final homeName = teamsById[match.homeTeamId]?.name ?? 'Tim Home';
    final awayName = teamsById[match.awayTeamId]?.name ?? 'Tim Away';

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
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skor Terbesar • ${match.tournamentName} (${match.stageName})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.badge.copyWith(color: AppTheme.chaoticText),
                ),
                const SizedBox(height: 3),
                Text(
                  '$homeName ${match.homeScore ?? 0} - ${match.awayScore ?? 0} $awayName',
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

class _ChampionsListBox extends StatelessWidget {
  final List<TournamentChampionEntry> entries;
  final Map<String, Team> teamsById;

  const _ChampionsListBox({
    required this.entries,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _ChampionEntryRow(
              entry: entries[i],
              championTeam: teamsById[entries[i].championTeamId],
              runnerUpTeam: teamsById[entries[i].runnerUpTeamId],
            ),
            if (i < entries.length - 1)
              const Divider(height: 1, color: AppTheme.borderHairline),
          ],
        ],
      ),
    );
  }
}

class _ChampionEntryRow extends StatelessWidget {
  final TournamentChampionEntry entry;
  final Team? championTeam;
  final Team? runnerUpTeam;

  const _ChampionEntryRow({
    required this.entry,
    required this.championTeam,
    required this.runnerUpTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.tournamentName,
                  style: AppTheme.badge.copyWith(
                    color: AppTheme.secondaryAccent,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TeamDetailScreen(teamId: entry.championTeamId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 15,
                        color: AppTheme.zoneChallenger,
                      ),
                      const SizedBox(width: 6),
                      TeamAvatar(
                        name: entry.championTeamName,
                        logoPath: championTeam?.logoPath,
                        colorValue: championTeam?.colorValue ?? 0xFF1D4ED8,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.championTeamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.cardTitle.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TeamDetailScreen(teamId: entry.runnerUpTeamId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const SizedBox(width: 21),
                      TeamAvatar(
                        name: entry.runnerUpTeamName,
                        logoPath: runnerUpTeam?.logoPath,
                        colorValue: runnerUpTeam?.colorValue ?? 0xFF6B7280,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Runner-up: ${entry.runnerUpTeamName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HallOfFameView extends StatelessWidget {
  final List<Team> teams;

  const _HallOfFameView({required this.teams});

  @override
  Widget build(BuildContext context) {
    final winners = teams.where((t) => t.totalTrophies > 0).toList()
      ..sort((a, b) {
        final totalCmp = b.totalTrophies.compareTo(a.totalTrophies);
        if (totalCmp != 0) return totalCmp;
        final uclCmp = (b.trophies['champions_league'] ?? 0)
            .compareTo(a.trophies['champions_league'] ?? 0);
        if (uclCmp != 0) return uclCmp;
        final leagueCmp = (b.trophies['local_league'] ?? 0)
            .compareTo(a.trophies['local_league'] ?? 0);
        if (leagueCmp != 0) return leagueCmp;
        return b.ovr.compareTo(a.ovr);
      });

    if (winners.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding * 1.5),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.borderHairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 42,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 12),
                Text('Hall of Fame Masih Kosong', style: AppTheme.sectionHeader),
                const SizedBox(height: 6),
                Text(
                  'Klub yang menjuarai Liga Lokal, Cup Domestik, maupun Turnamen Kontinental akan tercatat di papan kehormatan ini.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: winners.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final team = winners[index];
        final leagueName =
            context.read<GameStateProvider>().getLeagueName(team.leagueId);

        return Material(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TeamDetailScreen(teamId: team.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                border: Border.all(color: AppTheme.borderHairline),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${index + 1}',
                      style: AppTheme.tabularNumberBold.copyWith(
                        color: index == 0
                            ? AppTheme.zoneChallenger
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  TeamAvatar(
                    name: team.name,
                    logoPath: team.logoPath,
                    colorValue: team.colorValue,
                    size: 36,
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
                          style: AppTheme.cardTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$leagueName • ${_formatTrophySummary(team.trophies)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OvrBadge(ovr: team.ovr, compact: true),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.chaoticBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: AppTheme.chaoticText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${team.totalTrophies}',
                          style: AppTheme.tabularNumberBold.copyWith(
                            color: AppTheme.chaoticText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTrophySummary(Map<String, int> trophies) {
    const labels = {
      'champions_league': 'UCL',
      'winner_league': 'WIN',
      'federation_league': 'FED',
      'mid_range_league': 'MID',
      'challenger_league': 'CHL',
      'local_league': 'Liga',
      'domestic_cup': 'Cup',
    };
    final parts = <String>[];
    for (final entry in labels.entries) {
      final count = trophies[entry.key] ?? 0;
      if (count > 0) {
        parts.add('${entry.value}×$count');
      }
    }
    return parts.join(' • ');
  }
}
