import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Badge pill dengan warna dinamis berdasarkan nilai OVR (1–100) sesuai UI_GUIDE.
///
/// * 85–100 (Elite): Hijau Emerald
/// * 75–84 (Menengah): Biru
/// * 1–74 (Bawah): Slate
///
/// Dapat menampilkan perubahan OVR terakhir ([ovrChange], misal `+3` atau `-2`).
class OvrBadge extends StatelessWidget {
  final int ovr;
  final int? ovrChange;
  final bool showLabel;
  final bool compact;

  const OvrBadge({
    super.key,
    required this.ovr,
    this.ovrChange,
    this.showLabel = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final clampedOvr = ovr.clamp(1, 100);
    final colors = AppTheme.ovrColors(clampedOvr);
    final change = ovrChange ?? 0;

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: colors.foreground.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel) ...[
            Text(
              'OVR ',
              style: AppTheme.badge.copyWith(
                color: colors.foreground.withValues(alpha: 0.8),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          Text(
            '$clampedOvr',
            style: AppTheme.badge.copyWith(
              color: colors.foreground,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              fontFeatures: AppTheme.tabularFeatures,
            ),
          ),
        ],
      ),
    );

    if (change == 0) return badge;

    final isUp = change > 0;
    final changeColor = isUp ? AppTheme.ovrUp : AppTheme.ovrDown;
    final arrow = isUp ? '▲' : '▼';
    final formattedDelta = isUp ? '+$change' : '$change';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 6),
        Text(
          '$arrow$formattedDelta',
          style: AppTheme.badge.copyWith(
            color: changeColor,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            fontFeatures: AppTheme.tabularFeatures,
          ),
        ),
      ],
    );
  }
}
