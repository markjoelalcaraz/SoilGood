/// Small display helpers for admin timestamps (ops console only).
///
/// Keeps list/analytics formatting consistent without pulling farmer Analytics
/// Manila helpers into every admin widget.
library;

/// Short local timestamp for flashed_at / claimed_at / last_seen rows.
String formatAdminDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${months[local.month - 1]} ${local.day}, $h:$m';
}

/// Flashed label: date or explicit null wording.
String formatFlashedLabel(DateTime? flashedAt) {
  if (flashedAt == null) return 'Not flashed';
  return formatAdminDateTime(flashedAt);
}
