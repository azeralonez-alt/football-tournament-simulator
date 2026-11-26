import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../utils/json_file_picker.dart';

/// Menampilkan dialog Import Save Data (JSON) via pilih file `.json`,
/// tempel dari clipboard, atau input teks JSON langsung.
/// Mengembalikan `true` jika import berhasil dipulihkan.
Future<bool> showImportJsonDialog(
  BuildContext context,
  GameStateProvider provider,
) async {
  final controller = TextEditingController();
  String? errorMsg;
  var isImporting = false;

  final restored = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Import Save Data (JSON)'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pilih file .json backup atau tempel isi teks JSON hasil Export di bawah ini untuk memulihkan seluruh musim, tim, dan klasemen.',
                      style: AppTheme.body,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isImporting
                              ? null
                              : () async {
                                  final result = await pickJsonBackupFile();
                                  if (!dialogContext.mounted) return;
                                  if (result.hasContent) {
                                    controller.text = result.content!;
                                    setDialogState(() => errorMsg = null);
                                  } else if (result.errorMessage != null) {
                                    setDialogState(() {
                                      errorMsg = result.errorMessage;
                                    });
                                  }
                                },
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Pilih File .json'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isImporting
                              ? null
                              : () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (!dialogContext.mounted) return;
                                  if (data?.text != null &&
                                      data!.text!.isNotEmpty) {
                                    controller.text = data.text!;
                                    setDialogState(() => errorMsg = null);
                                  }
                                },
                          icon: const Icon(Icons.paste_rounded, size: 16),
                          label: const Text('Tempel Clipboard'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      maxLines: 8,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            '{"app": "football_tournament_simulator", ...}',
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMsg!,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.ovrDown,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isImporting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        setDialogState(() {
                          isImporting = true;
                          errorMsg = null;
                        });
                        try {
                          await provider.importJsonString(controller.text);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isImporting = false;
                              errorMsg = 'Data JSON tidak valid: $e';
                            });
                          }
                        }
                      },
                child: const Text('Muat & Pulihkan'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
  return restored ?? false;
}

/// Menampilkan bottom sheet Pengaturan & Backup Save Data (Export/Import JSON & Reset).
Future<void> showBackupSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppTheme.surfaceCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const Padding(
      padding: EdgeInsets.all(AppTheme.screenPadding),
      child: SafeArea(
        top: false,
        child: BackupSettingsPanel(),
      ),
    ),
  );
}

/// Panel pengaturan Export Save Data (JSON), Import Save Data (JSON), dan Reset Ekosistem.
class BackupSettingsPanel extends StatefulWidget {
  final bool insideBottomSheet;

  const BackupSettingsPanel({
    super.key,
    this.insideBottomSheet = true,
  });

  @override
  State<BackupSettingsPanel> createState() => _BackupSettingsPanelState();
}

class _BackupSettingsPanelState extends State<BackupSettingsPanel> {
  bool _isBusy = false;

  Future<void> _handleExport(
    BuildContext context,
    GameStateProvider provider,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final jsonStr = await provider.exportJsonString();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Export Save Data (JSON)'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.ovrEliteBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'JSON backup (${jsonStr.length} karakter) sudah disalin otomatis ke Clipboard.',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.ovrEliteText,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderHairline),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonStr));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('JSON disalin ulang ke Clipboard.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Lagi'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: AppTheme.ovrDown,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    GameStateProvider provider,
  ) async {
    final restored = await showImportJsonDialog(context, provider);

    if (restored && context.mounted) {
      if (widget.insideBottomSheet) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save data berhasil dipulihkan! (Musim ${provider.currentSeason}, Pekan ${provider.currentGameweek})',
          ),
          backgroundColor: AppTheme.primaryBrand,
        ),
      );
    }
  }

  Future<void> _handleReset(
    BuildContext context,
    GameStateProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Seluruh Ekosistem?'),
        content: const Text(
          'Semua 160 tim, jadwal pertandingan, klasemen, trofi, dan arsip sejarah akan dihapus permanen. Aplikasi akan kembali ke halaman Setup Awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ovrDown),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ya, Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (widget.insideBottomSheet) {
        Navigator.of(context).pop();
      }
      await provider.resetAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameStateProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pengaturan & Backup Data',
                style: AppTheme.appBarTitle,
              ),
            ),
            if (widget.insideBottomSheet)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Musim ${provider.currentSeason} • Pekan ${provider.currentGameweek}/${GameStateProvider.maxGameweek} • ${provider.teams.length} Tim • ${provider.archives.length} Arsip Musim',
          style: AppTheme.body,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isBusy ? null : () => _handleExport(context, provider),
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Export Save Data (JSON)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isBusy ? null : () => _handleImport(context, provider),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Import Save Data (JSON)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isBusy ? null : () => _handleReset(context, provider),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.ovrDown,
            side: BorderSide(
              color: AppTheme.ovrDown.withValues(alpha: 0.4),
            ),
          ),
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Reset Seluruh Data'),
        ),
      ],
    );
  }
}
