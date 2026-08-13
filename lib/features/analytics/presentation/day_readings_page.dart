/// Pushed page (outside the shell) listing one Manila day's soil readings.
///
/// Opened from the Analytics chart tap. Slide-from-right; bottom nav is not
/// visible. This is the history browser — not a fifth tab.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../home/data/soil_reading.dart';
import '../data/soil_history_repository.dart';
import '../logic/manila_time.dart';

/// Timestamped readings for a single Analytics chart day.
class DayReadingsPage extends StatefulWidget {
  const DayReadingsPage({required this.manilaDate, super.key});

  final DateTime manilaDate;

  @override
  State<DayReadingsPage> createState() => _DayReadingsPageState();
}

class _DayReadingsPageState extends State<DayReadingsPage> {
  final _repo = SoilHistoryRepository();
  List<SoilReading> _rows = [];
  Object? _error;
  bool _done = false;

  String get _title {
    final d = widget.manilaDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await withRefreshTimeout(_repo.fetchForDay(widget.manilaDate));
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
        _done = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          _title,
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: AppRefreshScroll(
        onRefresh: _load,
        children: [
          const Text(
            'Readings this day (Asia/Manila). This is history, not the live Home grid.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            SoftCard(
              color: AppColors.errorContainer,
              child: Text(
                'Could not load this day:\n$_error',
                style: const TextStyle(color: Color(0xFF690005), height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_done && _rows.isEmpty)
            const SoftCard(
              color: AppColors.surfaceMuted,
              child: SizedBox(height: 120),
            )
          else if (_rows.isEmpty)
            const SoftCard(
              child: Text(
                'No readings stored for this day.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            )
          else
            ..._rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReadingTile(reading: r),
                )),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading});

  final SoilReading reading;

  @override
  Widget build(BuildContext context) {
    final m = reading.recordedAt.toUtc().add(kManilaOffset);
    final time =
        '${m.hour.toString().padLeft(2, '0')}:${m.minute.toString().padLeft(2, '0')}';
    final moisture = reading.moisturePercent;
    final ph = reading.ph;

    return SoftCard(
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              time,
              style: GoogleFonts.literata(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                if (moisture != null) 'Moisture ${moisture.toStringAsFixed(0)}%',
                if (ph != null) 'pH ${ph.toStringAsFixed(1)}',
                if (reading.nitrogen != null)
                  'N ${reading.nitrogen!.toStringAsFixed(0)}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
