import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/team.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/backup_settings_sheet.dart';
import '../widgets/rename_tournament_dialog.dart';
import '../widgets/team_avatar.dart';

class _RowDraft {
  String id;
  final TextEditingController nameController;
  final TextEditingController ovrController;
  int colorValue;
  String? logoPath;

  _RowDraft({
    required this.id,
    required this.nameController,
    required this.ovrController,
    required this.colorValue,
    this.logoPath,
  });

  String get trimmedName => nameController.text.trim();
  int? get parsedOvr => int.tryParse(ovrController.text.trim());

  bool get isValid =>
      trimmedName.isNotEmpty &&
      parsedOvr != null &&
      parsedOvr! >= 1 &&
      parsedOvr! <= 100;

  bool get hasInvalidOvr {
    final raw = ovrController.text.trim();
    if (raw.isEmpty) return false;
    final val = int.tryParse(raw);
    return val == null || val < 1 || val > 100;
  }

  Team toTeam(String leagueId) {
    final ovr = (parsedOvr ?? 70).clamp(1, 100);
    return Team(
      id: id,
      name: trimmedName,
      leagueId: leagueId,
      ovr: ovr,
      seasonOvrStart: ovr,
      colorValue: colorValue,
      logoPath: logoPath,
    );
  }

  void dispose() {
    nameController.dispose();
    ovrController.dispose();
  }
}

/// Halaman onboarding untuk mengisi 20 tim di masing-masing 8 Liga Lokal (Liga A–H).
class SetupLeaguesScreen extends StatefulWidget {
  const SetupLeaguesScreen({super.key});

  @override
  State<SetupLeaguesScreen> createState() => _SetupLeaguesScreenState();
}

class _SetupLeaguesScreenState extends State<SetupLeaguesScreen>
    with SingleTickerProviderStateMixin {
  static const List<int> _clubPalette = [
    0xFF1D4ED8,
    0xFF00A859,
    0xFFDC2626,
    0xFFEA580C,
    0xFF7C3AED,
    0xFF0D9488,
    0xFFD97706,
    0xFF0F172A,
    0xFFBE185D,
    0xFF0369A1,
  ];

  static const _uuid = Uuid();

  late final TabController _tabController;
  late final List<List<_RowDraft>> _leagueDrafts;
  final Map<int, Timer> _debounceTimers = {};
  bool _isStartingSeason = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: GameStateProvider.leagueIds.length,
      vsync: this,
    );

    final provider = context.read<GameStateProvider>();
    _leagueDrafts = List.generate(GameStateProvider.leagueIds.length, (lIdx) {
      final leagueId = GameStateProvider.leagueIds[lIdx];
      final existingTeams = provider.getTeamsForLeague(leagueId);

      return List.generate(GameStateProvider.teamsPerLeague, (rowIdx) {
        final existing =
            rowIdx < existingTeams.length ? existingTeams[rowIdx] : null;
        return _RowDraft(
          id: existing?.id ?? _uuid.v4(),
          nameController: TextEditingController(text: existing?.name ?? ''),
          ovrController: TextEditingController(
            text: existing != null ? '${existing.ovr}' : '',
          ),
          colorValue: existing?.colorValue ??
              _clubPalette[(lIdx * 3 + rowIdx) % _clubPalette.length],
          logoPath: existing?.logoPath,
        );
      });
    });
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _tabController.dispose();
    for (final leagueRows in _leagueDrafts) {
      for (final row in leagueRows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  String _leagueLabel(int index) {
    final leagueId = GameStateProvider.leagueIds[index];
    return context.read<GameStateProvider>().getLeagueName(leagueId);
  }

  int _validCountForLeague(int leagueIndex) {
    return _leagueDrafts[leagueIndex].where((r) => r.isValid).length;
  }

  int get _totalValidCount {
    var total = 0;
    for (var i = 0; i < _leagueDrafts.length; i++) {
      total += _validCountForLeague(i);
    }
    return total;
  }

  bool get _allLeaguesComplete {
    for (var i = 0; i < _leagueDrafts.length; i++) {
      if (_validCountForLeague(i) < GameStateProvider.teamsPerLeague) {
        return false;
      }
    }
    return true;
  }

  void _onRowChanged(int leagueIndex) {
    setState(() {});
    _debounceTimers[leagueIndex]?.cancel();
    _debounceTimers[leagueIndex] = Timer(
      const Duration(milliseconds: 300),
      () => _syncLeagueToProvider(leagueIndex),
    );
  }

  Future<void> _syncLeagueToProvider(int leagueIndex) async {
    if (!mounted) return;
    final provider = context.read<GameStateProvider>();
    final leagueId = GameStateProvider.leagueIds[leagueIndex];
    final validTeams = _leagueDrafts[leagueIndex]
        .where((r) => r.isValid)
        .map((r) => r.toTeam(leagueId))
        .toList();
    await provider.setLeagueTeams(leagueId, validTeams);
  }

  Future<void> _flushAllLeagues() async {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    final provider = context.read<GameStateProvider>();
    for (var i = 0; i < GameStateProvider.leagueIds.length; i++) {
      final leagueId = GameStateProvider.leagueIds[i];
      final validTeams = _leagueDrafts[i]
          .where((r) => r.isValid)
          .map((r) => r.toTeam(leagueId))
          .toList();
      await provider.setLeagueTeams(leagueId, validTeams);
    }
  }

  Future<void> _startFirstSeason() async {
    if (!_allLeaguesComplete || _isStartingSeason) return;

    setState(() => _isStartingSeason = true);
    try {
      await _flushAllLeagues();
      if (!mounted) return;
      await context.read<GameStateProvider>().startFirstSeason();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulai Musim 1: $e'),
          backgroundColor: AppTheme.ovrDown,
        ),
      );
      setState(() => _isStartingSeason = false);
    }
  }

  void _openPasteBottomSheet(int leagueIndex) {
    final leagueId = GameStateProvider.leagueIds[leagueIndex];
    final leagueName = _leagueLabel(leagueIndex);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PasteTeamsBottomSheet(
        leagueId: leagueId,
        leagueName: leagueName,
        onApply: (teams, errorCount) async {
          _applyParsedTeamsToLeague(leagueIndex, teams);
          await _syncLeagueToProvider(leagueIndex);
          if (!mounted) return;
          final warningNote =
              errorCount > 0 ? ' ($errorCount baris dilewati)' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${teams.length} tim diisi ke $leagueName$warningNote',
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyParsedTeamsToLeague(int leagueIndex, List<Team> parsedTeams) {
    final rows = _leagueDrafts[leagueIndex];
    setState(() {
      for (var i = 0; i < rows.length; i++) {
        if (i < parsedTeams.length) {
          final team = parsedTeams[i];
          rows[i].nameController.text = team.name;
          rows[i].ovrController.text = '${team.ovr}';
          rows[i].colorValue = team.colorValue;
          rows[i].logoPath = team.logoPath;
        } else {
          rows[i].nameController.clear();
          rows[i].ovrController.clear();
          rows[i].logoPath = null;
        }
      }
    });
  }

  void _openAvatarCustomizer(int leagueIndex, int rowIndex) {
    final draft = _leagueDrafts[leagueIndex][rowIndex];
    final previewName = draft.trimmedName.isNotEmpty
        ? draft.trimmedName
        : 'Tim ${rowIndex + 1}';

    showDialog<void>(
      context: context,
      builder: (_) => _AvatarCustomizerDialog(
        slotNumber: rowIndex + 1,
        previewName: previewName,
        initialColor: draft.colorValue,
        initialLogoPath: draft.logoPath,
        palette: _clubPalette,
        onSave: (colorValue, logoPath) {
          setState(() {
            draft.colorValue = colorValue;
            draft.logoPath = logoPath;
          });
          _onRowChanged(leagueIndex);
        },
      ),
    );
  }

  Future<void> _openImportJsonDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<GameStateProvider>();
    final imported = await showImportJsonDialog(context, provider);
    if (!imported) return;

    if (mounted &&
        !(provider.isSeasonStarted && provider.canStartFirstSeason)) {
      _reloadDraftsFromProvider();
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Data berhasil di-import!'),
        backgroundColor: AppTheme.primaryBrand,
      ),
    );
  }

  void _reloadDraftsFromProvider() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    final provider = context.read<GameStateProvider>();
    setState(() {
      for (var lIdx = 0; lIdx < GameStateProvider.leagueIds.length; lIdx++) {
        final leagueId = GameStateProvider.leagueIds[lIdx];
        final existingTeams = provider.getTeamsForLeague(leagueId);
        final rows = _leagueDrafts[lIdx];

        for (var rowIdx = 0; rowIdx < rows.length; rowIdx++) {
          final existing =
              rowIdx < existingTeams.length ? existingTeams[rowIdx] : null;
          rows[rowIdx].id = existing?.id ?? _uuid.v4();
          rows[rowIdx].nameController.text = existing?.name ?? '';
          rows[rowIdx].ovrController.text =
              existing != null ? '${existing.ovr}' : '';
          rows[rowIdx].colorValue = existing?.colorValue ??
              _clubPalette[(lIdx * 3 + rowIdx) % _clubPalette.length];
          rows[rowIdx].logoPath = existing?.logoPath;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();
    final totalValid = _totalValidCount;
    final isAllReady = _allLeaguesComplete;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Setup Peserta Liga',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _openImportJsonDialog,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Import JSON'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.screenPadding),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isAllReady
                      ? AppTheme.ovrEliteBg
                      : AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: isAllReady
                        ? AppTheme.primaryBrand.withValues(alpha: 0.35)
                        : AppTheme.borderHairline,
                  ),
                ),
                child: Text(
                  '$totalValid / 160 Tim Siap',
                  style: AppTheme.badge.copyWith(
                    color: isAllReady
                        ? AppTheme.ovrEliteText
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(GameStateProvider.leagueIds.length, (i) {
            final leagueId = GameStateProvider.leagueIds[i];
            final leagueName = provider.getLeagueName(leagueId);
            final count = _validCountForLeague(i);
            final done = count == GameStateProvider.teamsPerLeague;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(leagueName),
                  const SizedBox(width: 6),
                  if (done)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: AppTheme.primaryBrand,
                    )
                  else
                    Text(
                      '$count/20',
                      style: AppTheme.badge.copyWith(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          GameStateProvider.leagueIds.length,
          (leagueIndex) => _buildLeagueTab(
            leagueIndex,
            provider.getLeagueName(GameStateProvider.leagueIds[leagueIndex]),
          ),
        ),
      ),
      bottomNavigationBar: _buildStickyBottomBar(totalValid, isAllReady),
    );
  }

  Widget _buildLeagueTab(int leagueIndex, String leagueName) {
    final leagueId = GameStateProvider.leagueIds[leagueIndex];
    final validCount = _validCountForLeague(leagueIndex);
    final isComplete = validCount == GameStateProvider.teamsPerLeague;
    final rows = _leagueDrafts[leagueIndex];

    return Column(
      children: [
        Container(
          color: AppTheme.surfaceCard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$leagueName • $validCount/20 Tim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sectionHeader.copyWith(fontSize: 14),
                          ),
                        ),
                        if (isComplete) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppTheme.primaryBrand,
                          ),
                        ],
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: 'Ubah Nama Liga',
                          icon: const Icon(
                            Icons.edit,
                            size: 17,
                            color: AppTheme.textSecondary,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () => showRenameTournamentDialog(
                            context,
                            tournamentId: leagueId,
                            currentName: leagueName,
                            title: 'Ubah Nama Liga',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: validCount / GameStateProvider.teamsPerLeague,
                        minHeight: 5,
                        backgroundColor: AppTheme.surfaceSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete
                              ? AppTheme.primaryBrand
                              : AppTheme.secondaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openPasteBottomSheet(leagueIndex),
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Paste List Teks'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.borderHairline),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            itemCount: rows.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.cardSpacing),
            itemBuilder: (context, rowIndex) {
              return _buildTeamInputRow(leagueIndex, rowIndex, rows[rowIndex]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamInputRow(int leagueIndex, int rowIndex, _RowDraft draft) {
    final invalidOvr = draft.hasInvalidOvr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: draft.isValid
              ? AppTheme.primaryBrand.withValues(alpha: 0.35)
              : AppTheme.borderHairline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${rowIndex + 1}',
              textAlign: TextAlign.center,
              style: AppTheme.tabularNumberBold.copyWith(
                fontSize: 12,
                color: draft.isValid
                    ? AppTheme.primaryBrand
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Ketuk untuk ubah warna/logo opsional',
            child: TeamAvatar(
              name: draft.trimmedName.isNotEmpty
                  ? draft.trimmedName
                  : 'T${rowIndex + 1}',
              logoPath: draft.logoPath,
              colorValue: draft.colorValue,
              size: 36,
              onTap: () => _openAvatarCustomizer(leagueIndex, rowIndex),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: draft.nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _onRowChanged(leagueIndex),
              style: AppTheme.bodyPrimary.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Nama Tim ${rowIndex + 1}',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: TextField(
              controller: draft.ovrController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 3,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _onRowChanged(leagueIndex),
              style: AppTheme.tabularNumberBold.copyWith(
                fontSize: 14,
                color: invalidOvr ? AppTheme.ovrDown : AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'OVR',
                counterText: '',
                enabledBorder: invalidOvr
                    ? OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusInput),
                        borderSide:
                            const BorderSide(color: AppTheme.ovrDown, width: 1.5),
                      )
                    : null,
                focusedBorder: invalidOvr
                    ? OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusInput),
                        borderSide:
                            const BorderSide(color: AppTheme.ovrDown, width: 1.5),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(int totalValid, bool isAllReady) {
    final remaining = GameStateProvider.totalRequiredTeams - totalValid;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(
          top: BorderSide(color: AppTheme.borderHairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        10,
        AppTheme.screenPadding,
        12,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isAllReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Lengkapi $remaining tim lagi di seluruh 8 liga (masing-masing 20 tim, OVR 1–100).',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed:
                    isAllReady && !_isStartingSeason ? _startFirstSeason : null,
                child: _isStartingSeason
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Mulai Musim 1'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasteTeamsBottomSheet extends StatefulWidget {
  final String leagueId;
  final String leagueName;
  final Future<void> Function(List<Team> teams, int errorCount) onApply;

  const _PasteTeamsBottomSheet({
    required this.leagueId,
    required this.leagueName,
    required this.onApply,
  });

  @override
  State<_PasteTeamsBottomSheet> createState() => _PasteTeamsBottomSheetState();
}

class _PasteTeamsBottomSheetState extends State<_PasteTeamsBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  List<String> _errors = [];
  bool _isApplying = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isApplying) return;
    final provider = context.read<GameStateProvider>();
    final result = provider.parseTeamsFromBulkText(
      _textController.text,
      widget.leagueId,
    );

    if (result.teams.isEmpty) {
      setState(() {
        _errors = result.errors.isNotEmpty
            ? result.errors
            : ['Tidak ada baris tim yang valid ditemukan.'];
      });
      return;
    }

    setState(() => _isApplying = true);
    await widget.onApply(result.teams, result.errors.length);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        16,
        AppTheme.screenPadding,
        16 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paste List Teks • ${widget.leagueName}',
                    style: AppTheme.appBarTitle.copyWith(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tempel daftar tim hingga 20 baris dengan format "Nama Tim, OVR" (OVR 1–100).',
              style: AppTheme.body,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
              child: Text(
                'Contoh:\nGaruda FC, 86\nNusantara United, 82\nElang Selatan, 78',
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 9,
              minLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tempel daftar 20 tim di sini...',
                alignLabelWithHint: true,
              ),
            ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  border: Border.all(
                    color: AppTheme.ovrDown.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _errors
                      .take(4)
                      .map(
                        (err) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $err',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.ovrDown,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isApplying ? null : _submit,
                    child: Text('Terapkan ke ${widget.leagueName}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCustomizerDialog extends StatefulWidget {
  final int slotNumber;
  final String previewName;
  final int initialColor;
  final String? initialLogoPath;
  final List<int> palette;
  final void Function(int colorValue, String? logoPath) onSave;

  const _AvatarCustomizerDialog({
    required this.slotNumber,
    required this.previewName,
    required this.initialColor,
    required this.initialLogoPath,
    required this.palette,
    required this.onSave,
  });

  @override
  State<_AvatarCustomizerDialog> createState() =>
      _AvatarCustomizerDialogState();
}

class _AvatarCustomizerDialogState extends State<_AvatarCustomizerDialog> {
  late final TextEditingController _logoController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _logoController = TextEditingController(text: widget.initialLogoPath ?? '');
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = _logoController.text.trim();
    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      title: Text(
        'Tampilan Logo • #${widget.slotNumber}',
        style: AppTheme.sectionHeader,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: TeamAvatar(
                name: widget.previewName,
                logoPath: trimmedUrl.isEmpty ? null : trimmedUrl,
                colorValue: _selectedColor,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text('Warna Perisai Inisial', style: AppTheme.caption),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.palette.map((colorVal) {
                final isSelected = _selectedColor == colorVal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorVal),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.textPrimary : Colors.white,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('URL Gambar Logo (Opsional)', style: AppTheme.caption),
            const SizedBox(height: 6),
            TextField(
              controller: _logoController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'https://... (kosongkan untuk inisial)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final url = _logoController.text.trim();
            widget.onSave(_selectedColor, url.isEmpty ? null : url);
            Navigator.of(context).pop();
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
