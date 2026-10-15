/// Sensor list shown under a selected crop on the Farm tab.
///
/// Lists kits already on that plot, offers to place a kit that has no plot,
/// and opens [AddSensorPage] for a new sticker code. Widget only.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../data/farm_sensor.dart';
import '../logic/sensor_area_copy.dart';

/// Sensors that belong to the open crop, plus kits still waiting for a plot.
class PlotSensorCard extends StatelessWidget {
  const PlotSensorCard({
    required this.cropName,
    required this.onPlot,
    required this.unplaced,
    required this.onAdd,
    required this.onPlace,
    super.key,
  });

  final String cropName;
  final List<FarmSensor> onPlot;
  final List<FarmSensor> unplaced;
  final VoidCallback onAdd;
  final ValueChanged<FarmSensor> onPlace;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SENSORS ON THIS PLOT',
            style: TextStyle(
              color: AppColors.navIcon,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (onPlot.isEmpty)
            Text(
              'No sensor on $cropName yet.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final sensor in onPlot) ...[
              _SensorRow(sensor: sensor),
              const SizedBox(height: 8),
            ],
          for (final sensor in unplaced) ...[
            Text(
              'Place ${sensor.label} on $cropName?',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => onPlace(sensor),
                child: Text('Place on $cropName'),
              ),
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onAdd,
              child: const Text('Add sensor'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.sensor});

  final FarmSensor sensor;

  @override
  Widget build(BuildContext context) {
    final reading = sensor.latest;
    final flag = reading == null ? null : sensorAreaFlag(reading);
    final low = flag == SensorAreaFlag.low;
    final wet = flag == SensorAreaFlag.veryWet;
    final title = flag == null || flag == SensorAreaFlag.ok
        ? sensor.label
        : sensorAreaHeadline(claimCode: sensor.claimCode, flag: flag);
    final detail = reading == null || flag == null
        ? 'Waiting for a reading'
        : sensorAreaDetail(reading, flag);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: low || wet ? AppColors.errorContainer : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: low || wet ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
