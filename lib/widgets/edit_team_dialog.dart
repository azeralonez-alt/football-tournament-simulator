import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/team.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_theme.dart';
import '../utils/image_picker_helper.dart';
import 'team_avatar.dart';

/// Menampilkan dialog Edit Data Tim (Nama, OVR 1–100, dan Logo Base64)
/// yang dapat digunakan kapan saja meskipun musim sudah berjalan.
Future<bool?> showEditTeamDialog(BuildContext context, Team team) {
  return showDialog<bool>(
    context: context,
    builder: (_) => EditTeamDialog(team: team),
  );
}

/// Dialog form untuk mengedit nama, OVR, serta mengunggah/menghapus logo tim.
class EditTeamDialog extends StatefulWidget {
  final Team team;

  const EditTeamDialog({
    super.key,
    required this.team,
  });

  @override
  State<EditTeamDialog> createState() => _EditTeamDialogState();
}

class _EditTeamDialogState extends State<EditTeamDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ovrController;

  String? _newLogoBase64;
  bool _removeLogo = false;
  bool _isPickingLogo = false;
  bool _isSaving = false;
  String? _logoError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team.name);
    _ovrController = TextEditingController(text: '${widget.team.ovr}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ovrController.dispose();
    super.dispose();
  }

  String? get _effectiveLogoPath {
    if (_removeLogo) return null;
    if (_newLogoBase64 != null) return _newLogoBase64;
    return widget.team.logoPath;
  }

  bool get _hasActiveLogo {
    final path = _effectiveLogoPath?.trim();
    return path != null && path.isNotEmpty;
  }

  Future<void> _pickLogo() async {
    if (_isPickingLogo || _isSaving) return;
    setState(() {
      _isPickingLogo = true;
      _logoError = null;
    });

    try {
      final result = await pickLogoImageAsBase64();
      if (!mounted) return;
      if (result.hasImage) {
        setState(() {
          _newLogoBase64 = result.base64Data;
          _removeLogo = false;
          _logoError = null;
        });
      } else if (result.errorMessage != null) {
        setState(() {
          _logoError = result.errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingLogo = false);
      }
    }
  }

  void _clearLogo() {
    if (_isSaving) return;
    setState(() {
      _newLogoBase64 = null;
      _removeLogo = true;
      _logoError = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newName = _nameController.text.trim();
    final newOvr = int.parse(_ovrController.text.trim());

    setState(() => _isSaving = true);
    try {
      await context.read<GameStateProvider>().updateTeam(
            widget.team.id,
            newName: newName,
            newOvr: newOvr,
            newLogoBase64: _newLogoBase64,
            removeLogo: _removeLogo,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data "$newName" berhasil diperbarui.'),
          backgroundColor: AppTheme.primaryBrand,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui tim: $e'),
          backgroundColor: AppTheme.ovrDown,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.team.name;

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
              'Edit Data Tim',
              style: AppTheme.appBarTitle.copyWith(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      TeamAvatar(
                        name: previewName,
                        logoPath: _effectiveLogoPath,
                        colorValue: widget.team.colorValue,
                        size: 72,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isPickingLogo || _isSaving
                                ? null
                                : _pickLogo,
                            icon: _isPickingLogo
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 16,
                                  ),
                            label: Text(
                              _hasActiveLogo ? 'Ganti Logo' : 'Pilih Logo',
                            ),
                          ),
                          if (_hasActiveLogo)
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _clearLogo,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.ovrDown,
                                side: BorderSide(
                                  color: AppTheme.ovrDown.withValues(alpha: 0.4),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                              ),
                              label: const Text('Hapus Logo'),
                            ),
                        ],
                      ),
                      if (_logoError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _logoError!,
                          textAlign: TextAlign.center,
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.ovrDown,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nama Tim', style: AppTheme.caption),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan nama tim',
                    prefixIcon: Icon(Icons.shield_outlined, size: 18),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama tim wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text('Overall Rating (OVR 1–100)', style: AppTheme.caption),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _ovrController,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTheme.tabularNumberBold.copyWith(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '1–100',
                    counterText: '',
                    prefixIcon: Icon(Icons.bolt_rounded, size: 18),
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) {
                      return 'OVR wajib diisi';
                    }
                    final parsed = int.tryParse(raw);
                    if (parsed == null || parsed < 1 || parsed > 100) {
                      return 'OVR harus angka antara 1–100';
                    }
                    return null;
                  },
                ),
              ],
            ),
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
