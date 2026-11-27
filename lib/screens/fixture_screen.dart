import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_game.dart';
import '../models/team.dart';
import '../models/tournament.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/h2h_bottom_sheet.dart';
import '../widgets/ovr_badge.dart';
import '../widgets/team_avatar.dart';
import 'team_detail_screen.dart';

/// Tab 2: Halaman Fixture & Simulasi Pekan (Kalender Terpadu Pekan 1–48).
class FixtureScreen extends StatefulWidget {
  const FixtureScreen({super.key});

  @override
  State<FixtureScreen> createState() => _FixtureScreenState();
}

class _FixtureScreenState extends State<FixtureScreen> {
  int? _viewingGameweek;
  String _categoryFilter = 'all'; // 'all', 'local', 'cup', 'continental'
  String? _selectedTournamentId;
  final Set<String> _collapsedTournaments = {};
  bool _isSimulating = false;
  bool _isEndingSeason = false;
  bool _hideMidSeasonBanner = false;

  int _resolveViewingWeek(GameStateProvider provider) {
    return (_viewingGameweek ?? provider.currentGameweek)
        .clamp(1, GameStateProvider.maxGameweek);
  }

  Future<void> _handleSimulateWeek(GameStateProvider provider) async {
    if (_isSimulating) return;
    final simulatedWeek = provider.currentGameweek;
    setState(() => _isSimulating = true);
    try {
      await provider.simulateCurrentWeek();
      if (mounted) {
        setState(() {
          _viewingGameweek = simulatedWeek;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSimulating = false);
      }
    }
  }

  int _tournamentGroupPriority(Tournament? tournament) {
    if (tournament == null) return 99;
    switch (tournament.type) {
      case TournamentType.localLeague:
        return 0;
      case TournamentType.domesticCup:
        return 1;
      case TournamentType.continentalLeague:
      case TournamentType.continentalGroup:
        return 2;
    }
  }

  List<
      ({
        String tournamentId,
        String tournamentName,
        Tournament? tournament,
        List<MatchGame> matches,
      })> _groupMatchesByTournament(
    List<MatchGame> matches,
    Map<String, Tournament> tournamentsById,
  ) {
    final grouped = <String, List<MatchGame>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.tournamentId, () => []).add(m);
    }

    final result = grouped.entries.map((entry) {
      final t = tournamentsById[entry.key];
      final list = List<MatchGame>.from(entry.value)
        ..sort((a, b) {
          final grpCmp = (a.groupName ?? '').compareTo(b.groupName ?? '');
          if (grpCmp != 0) return grpCmp;
          final slotCmp = (a.bracketSlot ?? 0).compareTo(b.bracketSlot ?? 0);
          if (slotCmp != 0) return slotCmp;
          return a.leg.compareTo(b.leg);
        });

      final name = (t?.name.isNotEmpty == true)
          ? t!.name
          : (list.first.tournamentName.isNotEmpty
              ? list.first.tournamentName
              : 'Kompetisi');

      return (
        tournamentId: entry.key,
        tournamentName: name,
        tournament: t,
        matches: list,
      );
    }).toList();

    result.sort((a, b) {
      final pA = _tournamentGroupPriority(a.tournament);
      final pB = _tournamentGroupPriority(b.tournament);
      if (pA != pB) return pA.compareTo(pB);

      final idxA = a.tournament?.leagueIndex ?? a.tournament?.tier ?? 99;
      final idxB = b.tournament?.leagueIndex ?? b.tournament?.tier ?? 99;
      if (idxA != idxB) return idxA.compareTo(idxB);

      return a.tournamentName.compareTo(b.tournamentName);
    });

    return result;
  }

  Future<void> _handleEndSeason(GameStateProvider provider) async {
    if (_isEndingSeason) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Akhiri Musim ${provider.currentSeason}?'),
        content: Text(
          'Seluruh juara & rekor Musim ${provider.currentSeason} akan diarsipkan ke History, Transfer Window akhir musim akan dijalankan, dan Musim ${provider.currentSeason + 1} (termasuk 5 Turnamen Kontinental) akan dimulai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lanjut Musim Berikutnya'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isEndingSeason = true);
    try {
      await provider.endSeasonAndStartNext();
      if (mounted) {
        setState(() {
          _viewingGameweek = provider.currentGameweek;
          _selectedTournamentId = null;
          _hideMidSeasonBanner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Musim ${provider.currentSeason} resmi dimulai! Cek perubahan OVR & jadwal terbaru.',
            ),
            backgroundColor: AppTheme.primaryBrand,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEndingSeason = false);
      }
    }
  }

  void _openGameweekPicker(
    BuildContext context,
    GameStateProvider provider,
    int viewingWeek,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.45,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih Pekan (1–${GameStateProvider.maxGameweek})',
                          style: AppTheme.appBarTitle,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pekan aktif saat ini: Pekan ${provider.currentGameweek}',
                    style: AppTheme.body,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      itemCount: GameStateProvider.maxGameweek,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (_, idx) {
                        final gw = idx + 1;
                        final gwMatches = provider.getMatchesForGameweek(gw);
                        final isSelected = gw == viewingWeek;
                        final isCurrent = gw == provider.currentGameweek;
                        final isDone = gwMatches.isNotEmpty &&
                            gwMatches.every((m) => m.isFinished);
                        final isEmptyWeek = gwMatches.isEmpty;

                        Color bg = AppTheme.surfaceSubtle;
                        Color fg = AppTheme.textPrimary;
                        Border? border;

                        if (isSelected) {
                          bg = AppTheme.primaryBrand;
                          fg = Colors.white;
                        } else if (isDone) {
                          bg = AppTheme.ovrEliteBg;
                          fg = AppTheme.ovrEliteText;
                        } else if (isEmptyWeek) {
                          bg = AppTheme.backgroundCanvas;
                          fg = AppTheme.textMuted;
                        }

                        if (isCurrent && !isSelected) {
                          border = Border.all(
                            color: AppTheme.primaryBrand,
                            width: 1.5,
                          );
                        }

                        return InkWell(
                          onTap: () {
                            setState(() => _viewingGameweek = gw);
                            Navigator.of(sheetContext).pop();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: border,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$gw',
                                  style: AppTheme.tabularNumberBold.copyWith(
                                    color: fg,
                                    fontSize: 13,
                                  ),
                                ),
                                if (gw == 19 || gw == 48)
                                  Text(
                                    gw == 19 ? 'TW' : 'FIN',
                                    style: AppTheme.badge.copyWith(
                                      fontSize: 8.5,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.secondaryAccent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openMatchDetailSheet(
    BuildContext context,
    GameStateProvider provider,
    MatchGame match,
    Team? home,
    Team? away,
  ) {
    final probs = provider.getMatchProbabilities(match);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${match.tournamentName} • ${match.stageName}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                  ),
                  Text(
                    'Pekan ${match.gameweek}',
                    style: AppTheme.badge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: home == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TeamDetailScreen(teamId: home.id),
                                ),
                              );
                            },
                      child: Column(
                        children: [
                          TeamAvatar(
                            name: home?.name ?? 'Home',
                            logoPath: home?.logoPath,
                            colorValue: home?.colorValue ?? 0xFF1D4ED8,
                            size: 46,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            home?.name ?? 'Tim Home',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.cardTitle,
                          ),
                          const SizedBox(height: 4),
                          if (home != null)
                            OvrBadge(ovr: home.ovr, compact: true),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        Text(
                          match.isFinished
                              ? '${match.homeScore ?? 0} - ${match.awayScore ?? 0}'
                              : 'VS',
                          style: AppTheme.matchScore.copyWith(fontSize: 22),
                        ),
                        if (match.hasPenaltyShootout) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pen ${match.homePenaltyScore}-${match.awayPenaltyScore}',
                            style: AppTheme.badge.copyWith(
                              color: AppTheme.secondaryAccent,
                            ),
                          ),
                        ],
                        if (match.isNeutralVenue) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tempat Netral',
                            style: AppTheme.badge.copyWith(fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: away == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TeamDetailScreen(teamId: away.id),
                                ),
                              );
                            },
                      child: Column(
                        children: [
                          TeamAvatar(
                            name: away?.name ?? 'Away',
                            logoPath: away?.logoPath,
                            colorValue: away?.colorValue ?? 0xFF00A859,
                            size: 46,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            away?.name ?? 'Tim Away',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.cardTitle,
                          ),
                          const SizedBox(height: 4),
                          if (away != null)
                            OvrBadge(ovr: away.ovr, compact: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                child: Column(
                  children: [
                    Text(
                      'Model Davidson (Peluang Pra-Laga)',
                      style: AppTheme.badge,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'Home ${probs.homeWinPercent}%',
                          style: AppTheme.tabularNumberBold.copyWith(
                            color: AppTheme.primaryBrand,
                          ),
                        ),
                        Text(
                          'Seri ${probs.drawPercent}%',
                          style: AppTheme.tabularNumberBold.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          'Away ${probs.awayWinPercent}%',
                          style: AppTheme.tabularNumberBold.copyWith(
                            color: AppTheme.secondaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!match.isFinished)
                ElevatedButton.icon(
                  onPressed: () {
                    final matchWeek = match.gameweek;
                    Navigator.of(sheetContext).pop();
                    if (_viewingGameweek == null) {
                      setState(() => _viewingGameweek = matchWeek);
                    }
                    provider.simulateSingleMatch(match.id);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Simulate Pertandingan Ini'),
                )
              else
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Tutup'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final viewingWeek = _resolveViewingWeek(provider);
    final teamsById = {for (final t in provider.teams) t.id: t};
    final tournamentsById = {for (final t in provider.tournaments) t.id: t};

    final activeTournaments = provider.tournaments
        .where((t) => t.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final weekMatches = provider.getMatchesForGameweek(viewingWeek);
    final filteredMatches = weekMatches.where((m) {
      if (_selectedTournamentId != null &&
          m.tournamentId != _selectedTournamentId) {
        return false;
      }
      final t = tournamentsById[m.tournamentId];
      if (t == null) return true;
      switch (_categoryFilter) {
        case 'local':
          return t.type == TournamentType.localLeague;
        case 'cup':
          return t.type == TournamentType.domesticCup;
        case 'continental':
          return t.isContinental;
        default:
          return true;
      }
    }).toList();

    final currentWeekMatches =
        provider.getMatchesForGameweek(provider.currentGameweek);
    final hasPendingInActiveWeek =
        currentWeekMatches.any((m) => !m.isFinished);

    final showMidSeasonBanner = !_hideMidSeasonBanner &&
        provider.midSeasonTransferDone &&
        (viewingWeek == 19 || viewingWeek == 20);

    final groupedMatches = _groupMatchesByTournament(
      filteredMatches,
      tournamentsById,
    );

    return Column(
      children: [
        _buildTopControlPanel(
          context: context,
          provider: provider,
          viewingWeek: viewingWeek,
          weekMatches: weekMatches,
          activeTournaments: activeTournaments,
          hasPendingInActiveWeek: hasPendingInActiveWeek,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              if (provider.isCurrentSeasonCompleted) ...[
                _EndSeasonBannerCard(
                  seasonNumber: provider.currentSeason,
                  isLoading: _isEndingSeason,
                  onPressed: () => _handleEndSeason(provider),
                ),
                const SizedBox(height: 12),
              ],
              if (showMidSeasonBanner) ...[
                _MidSeasonTransferBanner(
                  onDismiss: () => setState(() => _hideMidSeasonBanner = true),
                ),
                const SizedBox(height: 12),
              ],
              if (groupedMatches.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppTheme.borderHairline),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy_rounded,
                        size: 36,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tidak Ada Pertandingan',
                        style: AppTheme.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekMatches.isEmpty
                            ? 'Pekan $viewingWeek adalah jeda kalender atau menunggu hasil babak gugur sebelumnya.'
                            : 'Tidak ada pertandingan yang cocok dengan filter kompetisi.',
                        textAlign: TextAlign.center,
                        style: AppTheme.body,
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < groupedMatches.length; i++) ...[
                  _TournamentMatchesGroupCard(
                    tournament: groupedMatches[i].tournament,
                    tournamentName: groupedMatches[i].tournamentName,
                    matches: groupedMatches[i].matches,
                    teamsById: teamsById,
                    isCollapsed: _collapsedTournaments.contains(
                      groupedMatches[i].tournamentId,
                    ),
                    onToggleCollapse: () {
                      final tId = groupedMatches[i].tournamentId;
                      setState(() {
                        if (_collapsedTournaments.contains(tId)) {
                          _collapsedTournaments.remove(tId);
                        } else {
                          _collapsedTournaments.add(tId);
                        }
                      });
                    },
                    onTapMatch: (match) => _openMatchDetailSheet(
                      context,
                      provider,
                      match,
                      teamsById[match.homeTeamId],
                      teamsById[match.awayTeamId],
                    ),
                    onTapH2H: (match) => showHeadToHeadBottomSheet(
                      context,
                      teamAId: match.homeTeamId,
                      teamBId: match.awayTeamId,
                    ),
                  ),
                  if (i < groupedMatches.length - 1) const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopControlPanel({
    required BuildContext context,
    required GameStateProvider provider,
    required int viewingWeek,
    required List<MatchGame> weekMatches,
    required List<Tournament> activeTournaments,
    required bool hasPendingInActiveWeek,
  }) {
    final finishedCount = weekMatches.where((m) => m.isFinished).length;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: viewingWeek > 1
                    ? () => setState(() => _viewingGameweek = viewingWeek - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      _openGameweekPicker(context, provider, viewingWeek),
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pekan $viewingWeek / ${GameStateProvider.maxGameweek}',
                          style: AppTheme.sectionHeader.copyWith(
                            fontFeatures: AppTheme.tabularFeatures,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: viewingWeek < GameStateProvider.maxGameweek
                    ? () => setState(() => _viewingGameweek = viewingWeek + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pekan Aktif: Pekan ${provider.currentGameweek} • $finishedCount/${weekMatches.length} laga selesai',
                style: AppTheme.badge.copyWith(color: AppTheme.textSecondary),
              ),
              if (viewingWeek != provider.currentGameweek)
                GestureDetector(
                  onTap: () => setState(
                    () => _viewingGameweek = provider.currentGameweek,
                  ),
                  child: Text(
                    'Ke Pekan ${provider.currentGameweek}',
                    style: AppTheme.badge.copyWith(
                      color: AppTheme.secondaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: _buildPrimaryActionButton(
              provider: provider,
              viewingWeek: viewingWeek,
              hasPendingInActiveWeek: hasPendingInActiveWeek,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: 'Semua',
                  selected: _categoryFilter == 'all',
                  onTap: () => setState(() {
                    _categoryFilter = 'all';
                    _selectedTournamentId = null;
                  }),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'Liga Lokal',
                  selected: _categoryFilter == 'local',
                  onTap: () => setState(() {
                    _categoryFilter = 'local';
                    _selectedTournamentId = null;
                  }),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'Cup Domestik',
                  selected: _categoryFilter == 'cup',
                  onTap: () => setState(() {
                    _categoryFilter = 'cup';
                    _selectedTournamentId = null;
                  }),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'Kontinental',
                  selected: _categoryFilter == 'continental',
                  onTap: () => setState(() {
                    _categoryFilter = 'continental';
                    _selectedTournamentId = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedTournamentId,
                isExpanded: true,
                isDense: true,
                style: AppTheme.bodyPrimary,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Semua Turnamen'),
                  ),
                  for (final t in activeTournaments)
                    DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(
                        t.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (val) => setState(() => _selectedTournamentId = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton({
    required GameStateProvider provider,
    required int viewingWeek,
    required bool hasPendingInActiveWeek,
  }) {
    final activeWeek = provider.currentGameweek;

    // Kondisi A: Pekan terakhir dan seluruh pertandingan musim ini telah selesai.
    if (provider.isCurrentSeasonCompleted && viewingWeek >= activeWeek) {
      return ElevatedButton.icon(
        onPressed: _isEndingSeason ? null : () => _handleEndSeason(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.zoneChallenger,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.flag_rounded, size: 18),
        label: Text(
          _isEndingSeason
              ? 'Menyiapkan Musim Baru...'
              : 'Akhiri Musim & Lanjut Musim Berikutnya',
        ),
      );
    }

    // Kondisi B: Pekan yang sedang dilihat sudah selesai (lebih kecil dari pekan aktif).
    if (viewingWeek < activeWeek) {
      final nextWeek = (viewingWeek + 1).clamp(1, GameStateProvider.maxGameweek);
      final isNextActive = nextWeek == activeWeek;
      return ElevatedButton.icon(
        onPressed: _isSimulating
            ? null
            : () => setState(() => _viewingGameweek = nextWeek),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(
          isNextActive
              ? 'Lanjut ke Pekan $nextWeek (Pekan Aktif)'
              : 'Lanjut ke Pekan $nextWeek',
        ),
      );
    }

    // Kondisi D (pengaman): Jika user melihat pekan mendatang (> pekan aktif).
    if (viewingWeek > activeWeek) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _viewingGameweek = activeWeek),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text('Kembali ke Pekan Aktif (Pekan $activeWeek)'),
      );
    }

    // Kondisi C: Berada di pekan aktif yang siap disimulasikan.
    return ElevatedButton.icon(
      onPressed: (_isSimulating || !hasPendingInActiveWeek)
          ? null
          : () => _handleSimulateWeek(provider),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBrand,
        foregroundColor: Colors.white,
      ),
      icon: _isSimulating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.bolt_rounded, size: 18),
      label: Text(
        _isSimulating
            ? 'Mensimulasikan...'
            : 'Simulate Pekan Ini (Pekan $viewingWeek)',
      ),
    );
  }
}

class _TournamentMatchesGroupCard extends StatelessWidget {
  final Tournament? tournament;
  final String tournamentName;
  final List<MatchGame> matches;
  final Map<String, Team> teamsById;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<MatchGame> onTapMatch;
  final ValueChanged<MatchGame> onTapH2H;

  const _TournamentMatchesGroupCard({
    required this.tournament,
    required this.tournamentName,
    required this.matches,
    required this.teamsById,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onTapMatch,
    required this.onTapH2H,
  });

  ({IconData icon, Color color}) _headerIcon() {
    if (tournament == null || tournament!.type == TournamentType.localLeague) {
      return (icon: Icons.shield_outlined, color: AppTheme.primaryBrand);
    }
    if (tournament!.type == TournamentType.domesticCup) {
      return (
        icon: Icons.emoji_events_outlined,
        color: AppTheme.zoneChallenger,
      );
    }
    return (
      icon: Icons.emoji_events_outlined,
      color: AppTheme.secondaryAccent,
    );
  }

  String _stageSummary() {
    if (matches.isEmpty) return '';
    final stages = matches.map((m) => m.stageName).toSet();
    final String baseStage;
    if (stages.length == 1) {
      baseStage = stages.first;
    } else if (matches.every((m) => m.groupName != null)) {
      baseStage = 'Fase Grup';
    } else {
      baseStage = 'Pekan ${matches.first.gameweek}';
    }
    final isNeutral = matches.any((m) => m.isNeutralVenue);
    return isNeutral ? '$baseStage • Netral' : baseStage;
  }

  @override
  Widget build(BuildContext context) {
    final iconMeta = _headerIcon();
    final stageInfo = _stageSummary();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderHairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppTheme.surfaceSubtle,
            child: InkWell(
              onTap: onToggleCollapse,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(iconMeta.icon, size: 18, color: iconMeta.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              tournamentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.cardTitle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (stageInfo.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceCard,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusPill),
                                border: Border.all(
                                  color: AppTheme.borderHairline,
                                ),
                              ),
                              child: Text(
                                stageInfo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.badge.copyWith(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${matches.length} Laga',
                      style: AppTheme.badge.copyWith(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const Divider(
              height: 1,
              thickness: 0.6,
              color: AppTheme.borderHairline,
            ),
            for (var i = 0; i < matches.length; i++) ...[
              _CompactTournamentMatchRow(
                match: matches[i],
                homeTeam: teamsById[matches[i].homeTeamId],
                awayTeam: teamsById[matches[i].awayTeamId],
                onTap: () => onTapMatch(matches[i]),
                onTapH2H: () => onTapH2H(matches[i]),
              ),
              if (i < matches.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.6,
                  color: AppTheme.borderHairline,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompactTournamentMatchRow extends StatelessWidget {
  final MatchGame match;
  final Team? homeTeam;
  final Team? awayTeam;
  final VoidCallback onTap;
  final VoidCallback onTapH2H;

  const _CompactTournamentMatchRow({
    required this.match,
    required this.homeTeam,
    required this.awayTeam,
    required this.onTap,
    required this.onTapH2H,
  });

  @override
  Widget build(BuildContext context) {
    final homeName = homeTeam?.name ?? 'Tim Home';
    final awayName = awayTeam?.name ?? 'Tim Away';
    final homeWon =
        match.isFinished && match.winnerTeamId == match.homeTeamId;
    final awayWon =
        match.isFinished && match.winnerTeamId == match.awayTeamId;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: match.isFinished
                    ? AppTheme.surfaceSubtle
                    : AppTheme.ovrEliteBg,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                match.isFinished ? 'FT' : 'VS',
                style: AppTheme.badge.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: match.isFinished
                      ? AppTheme.textSecondary
                      : AppTheme.ovrEliteText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          homeName,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.cardTitle.copyWith(
                            fontSize: 13,
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
                    size: 24,
                  ),
                  SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          match.isFinished
                              ? '${match.homeScore ?? 0} - ${match.awayScore ?? 0}'
                              : '- : -',
                          textAlign: TextAlign.center,
                          style: match.isFinished
                              ? AppTheme.matchScore.copyWith(fontSize: 14.5)
                              : AppTheme.tabularNumberBold.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                        ),
                        if (match.hasPenaltyShootout) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.ovrMidBg,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                            ),
                            child: Text(
                              'Pen ${match.homePenaltyScore}-${match.awayPenaltyScore}',
                              style: AppTheme.badge.copyWith(
                                fontSize: 9,
                                color: AppTheme.secondaryAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TeamAvatar(
                    name: awayName,
                    logoPath: awayTeam?.logoPath,
                    colorValue: awayTeam?.colorValue ?? 0xFF00A859,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          awayName,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.cardTitle.copyWith(
                            fontSize: 13,
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
            const SizedBox(width: 8),
            Material(
              color: AppTheme.ovrMidBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: InkWell(
                onTap: onTapH2H,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
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
                        size: 12,
                        color: AppTheme.secondaryAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'H2H',
                        style: AppTheme.badge.copyWith(
                          color: AppTheme.secondaryAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
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
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: AppTheme.caption.copyWith(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontSize: 12,
      ),
    );
  }
}

class _MidSeasonTransferBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _MidSeasonTransferBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.eventInfoBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.eventInfoBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.swap_horizontal_circle_rounded,
            color: AppTheme.secondaryAccent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer Window Tengah Musim Selesai!',
                  style: AppTheme.cardTitle.copyWith(
                    color: AppTheme.secondaryAccent,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'OVR seluruh klub telah diperbarui pasca Pekan 19. Cek perubahan OVR di Daftar Tim atau News Feed.',
                  style: AppTheme.body.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _EndSeasonBannerCard extends StatelessWidget {
  final int seasonNumber;
  final bool isLoading;
  final VoidCallback onPressed;

  const _EndSeasonBannerCard({
    required this.seasonNumber,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.ovrEliteBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppTheme.primaryBrand,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Musim $seasonNumber Telah Selesai!',
                  style: AppTheme.sectionHeader.copyWith(
                    color: AppTheme.ovrEliteText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Seluruh pertandingan hingga Pekan 48 telah rampung. Arsipkan rekor musim ini, jalankan Transfer Window akhir musim, dan mulai musim baru.',
            style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              isLoading
                  ? 'Memproses Musim Baru...'
                  : 'Akhiri Musim & Lanjut Musim Berikutnya',
            ),
          ),
        ],
      ),
    );
  }
}
