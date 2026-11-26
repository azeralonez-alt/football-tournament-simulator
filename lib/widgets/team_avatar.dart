import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Avatar logo klub berbentuk lingkaran/perisai dengan inisial 3 huruf.
///
/// Jika [logoPath] berisi URL (`http`/`https`) atau string gambar Base64
/// (baik raw Base64 maupun data URI `data:image/...;base64,...`), gambar akan
/// ditampilkan; jika kosong atau gagal dimuat, otomatis menampilkan inisial
/// klub dengan warna latar [colorValue].
class TeamAvatar extends StatelessWidget {
  static final Map<String, Uint8List> _base64Cache = {};

  final String name;
  final String? initialsOverride;
  final String? logoPath;
  final int colorValue;
  final double size;
  final VoidCallback? onTap;

  const TeamAvatar({
    super.key,
    required this.name,
    this.initialsOverride,
    this.logoPath,
    this.colorValue = 0xFF1D4ED8,
    this.size = 36,
    this.onTap,
  });

  String get _initials {
    if (initialsOverride != null && initialsOverride!.trim().isNotEmpty) {
      final cleaned = initialsOverride!.trim().toUpperCase();
      return cleaned.length > 3 ? cleaned.substring(0, 3) : cleaned;
    }
    final clean = name.trim();
    if (clean.isEmpty) return 'FC';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return (parts[0][0] + parts[1][0] + parts[2][0]).toUpperCase();
    }
    if (parts.length == 2) {
      final first = parts[0][0];
      final second = parts[1].length >= 2
          ? parts[1].substring(0, 2)
          : parts[1][0];
      return (first + second).toUpperCase();
    }
    return clean.length >= 3
        ? clean.substring(0, 3).toUpperCase()
        : clean.toUpperCase();
  }

  static Uint8List? _decodeBase64Logo(String raw) {
    var payload = raw.trim();
    if (payload.isEmpty) return null;

    if (payload.startsWith('data:')) {
      final markerIdx = payload.indexOf('base64,');
      if (markerIdx == -1) return null;
      payload = payload.substring(markerIdx + 7);
    }

    payload = payload.replaceAll(RegExp(r'\s+'), '');
    if (payload.isEmpty) return null;

    final cached = _base64Cache[payload];
    if (cached != null) return cached;

    try {
      final bytes = base64Decode(payload);
      if (bytes.isEmpty) return null;
      if (_base64Cache.length >= 250) {
        _base64Cache.clear();
      }
      _base64Cache[payload] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = colorValue == 0 ? AppTheme.secondaryAccent : Color(colorValue);
    final fontSize = (size * 0.34).clamp(8.5, 20.0);

    Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: size >= 32 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: _buildInner(bgColor, fontSize),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildInner(Color bgColor, double fontSize) {
    final trimmedLogo = logoPath?.trim();
    if (trimmedLogo == null || trimmedLogo.isEmpty) {
      return _buildInitialsText(fontSize);
    }

    if (trimmedLogo.startsWith('http://') ||
        trimmedLogo.startsWith('https://')) {
      return Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.network(
          trimmedLogo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: bgColor,
            alignment: Alignment.center,
            child: _buildInitialsText(fontSize),
          ),
        ),
      );
    }

    final decodedBytes = _decodeBase64Logo(trimmedLogo);
    if (decodedBytes != null) {
      return Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.memory(
          decodedBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: bgColor,
            alignment: Alignment.center,
            child: _buildInitialsText(fontSize),
          ),
        ),
      );
    }

    return _buildInitialsText(fontSize);
  }

  Widget _buildInitialsText(double fontSize) {
    return Text(
      _initials,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.0,
      ),
    );
  }
}
