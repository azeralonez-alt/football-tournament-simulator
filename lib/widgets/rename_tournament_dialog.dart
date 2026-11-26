import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';

/// Menampilkan dialog ringkas untuk mengubah nama Liga atau Turnamen.
/// Dapat digunakan baik pada halaman Setup awal maupun saat musim berjalan.
Future<bool?> showRenameTournamentDialog(
  BuildContext context, {
  required String tournamentId,
  required String currentName,
  String title = 'Ubah Nama Liga / Turnamen',
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => RenameTournamentDialog(
      tournamentId: tournamentId,
      currentName: currentName,
      title: title,
    ),
  );
}

/// Dialog form ringkas berisi TextField nama liga/turnamen, Batal, dan Simpan.
class RenameTournamentDialog extends StatefulWidget {
  final String tournamentId;
  final String currentName;
  final String title;

  const RenameTournamentDialog({
    super.key,
    required this.tournamentId,
    required this.currentName,
    this.title = 'Ubah Nama Liga / Turnamen',
  });

  @override
  State<RenameTournamentDialog> createState() => _RenameTournamentDialogState();
}

class _RenameTournamentDialogState extends State<RenameTournamentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newName = _nameController.text.trim();
    setState(() => _isSaving = true);
    try {
      await context.read<GameStateProvider>().renameTournament(
            widget.tournamentId,
            newName,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama berhasil diubah menjadi "$newName".'),
          backgroundColor: AppTheme.primaryBrand,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah nama: $e'),
          backgroundColor: AppTheme.ovrDown,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.edit_rounded,
            size: 20,
            color: AppTheme.primaryBrand,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: AppTheme.appBarTitle.copyWith(fontSize: 16.5),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Nama Liga / Turnamen',
              hintText: 'Masukkan nama baru...',
              prefixIcon: Icon(Icons.emoji_events_outlined, size: 18),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama tidak boleh kosong';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
