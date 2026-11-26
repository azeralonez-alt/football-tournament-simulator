import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/team.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_team_dialog.dart';
import '../widgets/ovr_badge.dart';
import '../widgets/team_avatar.dart';
import 'team_detail_screen.dart';

/// Tab 3: Direktori seluruh 160 tim dengan pencarian, filter liga, dan pengurutan.
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLeagueId = 'all';
  String _sortBy = 'ovr_desc'; // 'ovr_desc', 'ovr_asc', 'name_asc', 'trophies_desc'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Team> _filterAndSort(List<Team> allTeams) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = allTeams.where((t) {
      if (_selectedLeagueId != 'all' && t.leagueId != _selectedLeagueId) {
        return false;
      }
      if (q.isNotEmpty && !t.name.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'ovr_asc':
          final cmp = a.ovr.compareTo(b.ovr);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        case 'name_asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'trophies_desc':
          final cmp = b.totalTrophies.compareTo(a.totalTrophies);
          return cmp != 0 ? cmp : b.ovr.compareTo(a.ovr);
        case 'ovr_desc':
        default:
          final cmp = b.ovr.compareTo(a.ovr);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final teams = _filterAndSort(provider.teams);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari nama klub...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
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
                        child: DropdownButton<String>(
                          value: _selectedLeagueId,
                          isExpanded: true,
                          isDense: true,
                          style: AppTheme.bodyPrimary,
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('Semua Liga'),
                            ),
                            for (final id in GameStateProvider.leagueIds)
                              DropdownMenuItem(
                                value: id,
                                child: Text(provider.getLeagueName(id)),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedLeagueId = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isExpanded: true,
                          isDense: true,
                          style: AppTheme.bodyPrimary,
                          items: const [
                            DropdownMenuItem(
                              value: 'ovr_desc',
                              child: Text('OVR Tertinggi'),
                            ),
                            DropdownMenuItem(
                              value: 'ovr_asc',
                              child: Text('OVR Terendah'),
                            ),
                            DropdownMenuItem(
                              value: 'name_asc',
                              child: Text('Nama A–Z'),
                            ),
                            DropdownMenuItem(
                              value: 'trophies_desc',
                              child: Text('Trofi Terbanyak'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Menampilkan ${teams.length} dari ${provider.teams.length} tim',
                style: AppTheme.badge.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: teams.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Tidak ada tim yang cocok dengan pencarian atau filter.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
                  itemCount: teams.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return _TeamDirectoryCard(
                      team: team,
                      leagueLabel: provider.getLeagueName(team.leagueId),
                      onEdit: () => showEditTeamDialog(context, team),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TeamDetailScreen(teamId: team.id),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TeamDirectoryCard extends StatelessWidget {
  final Team team;
  final String leagueLabel;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _TeamDirectoryCard({
    required this.team,
    required this.leagueLabel,
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderHairline, width: 1),
          ),
          child: Row(
            children: [
              TeamAvatar(
                name: team.name,
                logoPath: team.logoPath,
                colorValue: team.colorValue,
                size: 38,
              ),
              const SizedBox(width: 12),
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
                    Row(
                      children: [
                        Text(
                          leagueLabel,
                          style: AppTheme.body.copyWith(fontSize: 12),
                        ),
                        if (team.totalTrophies > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 13,
                            color: AppTheme.zoneChallenger,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${team.totalTrophies}',
                            style: AppTheme.badge.copyWith(
                              color: AppTheme.zoneChallenger,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OvrBadge(
                ovr: team.ovr,
                ovrChange: team.lastOvrChange,
                showLabel: true,
                compact: true,
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Edit Tim',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                onPressed: onEdit,
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
