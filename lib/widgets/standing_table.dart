import 'package:flutter/material.dart';

import '../models/standing_row.dart';
import '../models/team.dart';
import '../theme/app_theme.dart';
import 'team_avatar.dart';

/// Tipe zona kualifikasi untuk mewarnai strip kiri 4px pada tabel klasemen.
enum StandingZoneType {
  localLeague,
  continentalLeaguePhase,
  continentalGroupMidRange,
  continentalGroupChallenger,
  none,
}

/// Tabel klasemen bergaya FotMob Light Mode dengan strip warna zona kualifikasi
/// selebar 4px di sisi kiri setiap baris dan angka tabular yang sejajar lurus.
class StandingTable extends StatelessWidget {
  final List<StandingRow> rows;
  final Map<String, Team> teamsById;
  final StandingZoneType zoneType;
  final bool showLegend;
  final ValueChanged<String>? onTeamTap;

  const StandingTable({
    super.key,
    required this.rows,
    required this.teamsById,
    this.zoneType = StandingZoneType.localLeague,
    this.showLegend = true,
    this.onTeamTap,
  });

  Color? _zoneColorForRank(int rank) {
    switch (zoneType) {
      case StandingZoneType.localLeague:
        return AppTheme.localLeagueZoneColor(rank);
      case StandingZoneType.continentalLeaguePhase:
        return AppTheme.continentalLeaguePhaseZoneColor(rank);
      case StandingZoneType.continentalGroupMidRange:
        if (rank >= 1 && rank <= 2) return AppTheme.zoneChampions;
        if (rank == 3) return AppTheme.zoneChallenger;
        if (rank >= 4) return AppTheme.zoneEliminated;
        return null;
      case StandingZoneType.continentalGroupChallenger:
        if (rank == 1) return AppTheme.zoneChampions;
        if (rank >= 2) return AppTheme.zoneEliminated;
        return null;
      case StandingZoneType.none:
        return null;
    }
  }

  List<({Color color, String label})> _legendItems() {
    switch (zoneType) {
      case StandingZoneType.localLeague:
        return const [
          (color: AppTheme.zoneChampions, label: '1–4 Champions League'),
          (color: AppTheme.zoneWinner, label: '5–8 Winner League'),
          (color: AppTheme.zoneFederation, label: '9–12 Federation League'),
          (color: AppTheme.zoneMidRange, label: '13–17 Mid Range League'),
          (color: AppTheme.zoneChallenger, label: '18–20 Challenger League'),
        ];
      case StandingZoneType.continentalLeaguePhase:
        return const [
          (color: AppTheme.zoneChampions, label: '1–8 Lolos 16 Besar'),
          (color: AppTheme.zoneWinner, label: '9–24 Play-off 2 Leg'),
          (color: AppTheme.zoneEliminated, label: '25–32 Gugur'),
        ];
      case StandingZoneType.continentalGroupMidRange:
        return const [
          (color: AppTheme.zoneChampions, label: '1–2 Lolos 16 Besar'),
          (color: AppTheme.zoneChallenger, label: '3 Turun ke Challenger'),
          (color: AppTheme.zoneEliminated, label: '4–5 Gugur'),
        ];
      case StandingZoneType.continentalGroupChallenger:
        return const [
          (color: AppTheme.zoneChampions, label: '1 Lolos 16 Besar'),
          (color: AppTheme.zoneEliminated, label: '2–3 Gugur'),
        ];
      case StandingZoneType.none:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final legend = showLegend ? _legendItems() : const <({Color color, String label})>[];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderHairline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width -
                    (AppTheme.screenPadding * 2) -
                    2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada data klasemen.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ...List.generate(
                      rows.length,
                      (index) => _buildDataRow(
                        rows[index],
                        index + 1,
                        isLast: index == rows.length - 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (legend.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.borderHairline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: legend
                    .map(
                      (item) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            item.label,
                            style: AppTheme.badge.copyWith(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: AppTheme.surfaceSubtle,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: AppTheme.zoneIndicatorWidth),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('#', style: AppTheme.tableHeader, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 156,
            child: Text('Tim', style: AppTheme.tableHeader),
          ),
          _headerCell('Main', width: 36),
          _headerCell('M', width: 28),
          _headerCell('S', width: 28),
          _headerCell('K', width: 28),
          _headerCell('GF', width: 32),
          _headerCell('GA', width: 32),
          _headerCell('SG', width: 36),
          _headerCell('Poin', width: 40, bold: true),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required double width, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTheme.tableHeader.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDataRow(
    StandingRow row,
    int fallbackRank, {
    required bool isLast,
  }) {
    final rank = row.position > 0 ? row.position : fallbackRank;
    final team = teamsById[row.teamId];
    final teamName = team?.name ?? 'Tim';
    final zoneColor = _zoneColorForRank(rank);
    final gd = row.goalDifference;
    final gdText = gd > 0 ? '+$gd' : '$gd';

    return InkWell(
      onTap: onTeamTap != null ? () => onTeamTap!(row.teamId) : null,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppTheme.borderHairline, width: 1),
                ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: AppTheme.zoneIndicatorWidth,
                color: zoneColor ?? Colors.transparent,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: AppTheme.tabularNumberBold.copyWith(
                    fontSize: 12,
                    color: zoneColor ?? AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 156,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      TeamAvatar(
                        name: teamName,
                        logoPath: team?.logoPath,
                        colorValue: team?.colorValue ?? 0xFF1D4ED8,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyPrimary.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _numberCell('${row.played}', width: 36),
              _numberCell('${row.won}', width: 28),
              _numberCell('${row.drawn}', width: 28),
              _numberCell('${row.lost}', width: 28),
              _numberCell('${row.goalsFor}', width: 32),
              _numberCell('${row.goalsAgainst}', width: 32),
              _numberCell(
                gdText,
                width: 36,
                color: gd > 0
                    ? AppTheme.ovrUp
                    : (gd < 0 ? AppTheme.ovrDown : AppTheme.textSecondary),
              ),
              _numberCell(
                '${row.points}',
                width: 40,
                bold: true,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberCell(
    String value, {
    required double width,
    bool bold = false,
    Color? color,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: (bold ? AppTheme.tabularNumberBold : AppTheme.tabularNumber)
            .copyWith(
          fontSize: 12.5,
          color: color ?? AppTheme.textSecondary,
        ),
      ),
    );
  }
}
